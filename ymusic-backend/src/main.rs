use std::env;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use qanda_ymusic::mpv::{MpvEvent, MpvProcess};
use qanda_ymusic::player::Player;
use qanda_ymusic::protocol::{
    ErrorResponse, FrameError, Request, Response, StatusEvent, read_frame,
};
use serde::Serialize;
use tokio::io::{AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::watch;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let runtime_dir = env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(format!("/run/user/{}", unsafe { libc::getuid() })));
    let home = env::var_os("HOME")
        .map(PathBuf::from)
        .ok_or("HOME is not set")?;
    let control_socket = runtime_dir.join("qanda-ymusic.sock");
    let mpv_socket = runtime_dir.join("qanda-ymusic-mpv.sock");
    let token_path = home.join(".local/share/qanda-ymusic/token");

    remove_stale(&control_socket).await?;
    let (mpv_process, mpv, mut mpv_events) = MpvProcess::spawn(mpv_socket).await?;
    let player = Player::new(token_path, mpv);
    player.initialize().await;

    let listener = UnixListener::bind(&control_socket)?;
    tokio::fs::set_permissions(&control_socket, std::fs::Permissions::from_mode(0o600)).await?;
    let (shutdown_tx, shutdown_rx) = watch::channel(false);
    let mpris_player = player.clone();
    let mpris_task = tokio::spawn(async move {
        if let Err(error) = qanda_ymusic::mpris::run(mpris_player, shutdown_rx).await {
            eprintln!("MPRIS unavailable: {error}");
        }
    });
    let (fatal_tx, mut fatal_rx) = tokio::sync::oneshot::channel::<String>();
    let event_player = player.clone();
    let event_task = tokio::spawn(async move {
        loop {
            match mpv_events.recv().await {
                Ok(event) => {
                    let fatal = mpv_fatal_message(&event);
                    event_player.observe(event).await;
                    if let Some(error) = fatal {
                        let _ = fatal_tx.send(error);
                        break;
                    }
                }
                Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
            }
        }
    });

    let mut fatal_error = None;
    loop {
        tokio::select! {
            accepted = listener.accept() => {
                match accepted {
                    Ok((stream, _)) => { let player = player.clone(); tokio::spawn(async move { let _ = serve_client(stream, player).await; }); }
                    Err(error) => eprintln!("Control socket accept failed: {error}"),
                }
            }
            _ = shutdown_signal() => break,
            fatal = &mut fatal_rx => {
                fatal_error = Some(fatal.unwrap_or_else(|_| "mpv event monitor stopped".into()));
                break;
            }
        }
    }

    let _ = shutdown_tx.send(true);
    drop(listener);
    remove_stale(&control_socket).await?;
    mpv_process.shutdown().await;
    let _ = event_task.await;
    let _ = mpris_task.await;
    if let Some(error) = fatal_error {
        return Err(std::io::Error::other(error).into());
    }
    Ok(())
}

fn mpv_fatal_message(event: &MpvEvent) -> Option<String> {
    match event {
        MpvEvent::Exited(error) => Some(error.clone()),
        _ => None,
    }
}

async fn serve_client(stream: UnixStream, player: Arc<Player>) -> std::io::Result<()> {
    let (reader, mut writer) = stream.into_split();
    let mut reader = BufReader::new(reader);
    let mut statuses = player.subscribe();
    loop {
        let frame = read_frame(&mut reader);
        tokio::pin!(frame);
        loop {
            tokio::select! {
                result = &mut frame => {
                    let frame = match result {
                        Ok(Some(frame)) => frame,
                        Ok(None) | Err(FrameError::TooLarge | FrameError::Unterminated) => return Ok(()),
                        Err(FrameError::Io(error)) => return Err(std::io::Error::other(error)),
                    };
                    let parsed = serde_json::from_slice::<Request>(&frame);
                    match parsed {
                        Ok(request) => {
                            let id = request.id.clone();
                            match request.command() {
                                Ok(command) => match player.dispatch(command).await {
                                    Ok(result) => write_message(&mut writer, &Response { ok: true, id: id.as_ref(), result }).await?,
                                    Err(error) => {
                                        player.set_error(error.clone()).await;
                                        write_message(&mut writer, &ErrorResponse { ok: false, id: id.as_ref(), error }).await?;
                                    }
                                },
                                Err(error) => {
                                    player.set_error(error.clone()).await;
                                    write_message(&mut writer, &ErrorResponse { ok: false, id: id.as_ref(), error }).await?;
                                }
                            }
                        }
                        Err(error) => {
                            let error = format!("Некорректный JSON: {error}");
                            player.set_error(error.clone()).await;
                            write_message(&mut writer, &ErrorResponse { ok: false, id: None, error }).await?;
                        }
                    }
                    break;
                }
                status = statuses.recv() => match status {
                    Ok(status) => write_message(&mut writer, &StatusEvent { event: "status", ok: true, result: status }).await?,
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => {
                        write_message(&mut writer, &StatusEvent { event: "status", ok: true, result: player.status().await }).await?;
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Closed) => return Ok(()),
                }
            }
        }
    }
}

async fn write_message<T: Serialize>(
    writer: &mut tokio::net::unix::OwnedWriteHalf,
    value: &T,
) -> std::io::Result<()> {
    let mut bytes = serde_json::to_vec(value).map_err(std::io::Error::other)?;
    bytes.push(b'\n');
    writer.write_all(&bytes).await
}

async fn remove_stale(path: &Path) -> std::io::Result<()> {
    match tokio::fs::remove_file(path).await {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error),
    }
}

#[cfg(unix)]
async fn shutdown_signal() {
    let mut terminate = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        .expect("SIGTERM handler");
    tokio::select! { _ = tokio::signal::ctrl_c() => {}, _ = terminate.recv() => {} }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_unexpected_mpv_exit_crosses_fatal_lifecycle_boundary() {
        assert_eq!(mpv_fatal_message(&MpvEvent::Pause(false)), None);
        assert_eq!(
            mpv_fatal_message(&MpvEvent::Exited("mpv died".into())),
            Some("mpv died".into())
        );
    }
}
