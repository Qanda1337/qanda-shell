#![deny(unsafe_code)]

mod collectors;
mod config;
mod dbus;
mod model;
mod protocol;

use std::{
    collections::HashSet,
    io::ErrorKind,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    sync::Arc,
    time::Duration,
};

use collectors::Collector;
use dbus::SystemBus;
use model::{Snapshot, SystemSnapshot};
use notify::{RecommendedWatcher, RecursiveMode, Watcher};
use protocol::{Command, Response, parse_command};
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::{UnixListener, UnixStream},
    sync::{Mutex, mpsc, watch},
};

fn socket_path() -> PathBuf {
    socket_path_for(
        std::env::var_os("XDG_RUNTIME_DIR").filter(|value| !value.is_empty()),
        std::env::var("USER").unwrap_or_else(|_| rustix::process::getuid().as_raw().to_string()),
    )
}

fn socket_path_for(runtime: Option<std::ffi::OsString>, user: String) -> PathBuf {
    if let Some(runtime) = runtime {
        PathBuf::from(runtime).join("qanda-shell-system.sock")
    } else {
        PathBuf::from(format!("/tmp/qanda-shell-system-{user}.sock"))
    }
}

fn accent_file_from_args() -> Result<PathBuf, String> {
    let mut args = std::env::args_os().skip(1);
    let mut accent = None;
    while let Some(argument) = args.next() {
        if argument == "--accent-file" {
            accent = Some(args.next().ok_or("--accent-file requires a path")?.into());
        } else {
            return Err(format!("unknown argument: {}", argument.to_string_lossy()));
        }
    }
    accent.ok_or_else(|| "--accent-file is required".into())
}

#[tokio::main]
async fn main() {
    if let Err(error) = run().await {
        eprintln!("system-backend: {error}");
        std::process::exit(1);
    }
}

async fn run() -> Result<(), String> {
    rustix::process::umask(rustix::fs::Mode::RWXG | rustix::fs::Mode::RWXO);
    let accent_path = accent_file_from_args()?;
    let theme_path = config::theme_path();
    let path = socket_path();
    let listener = bind_socket(&path).await?;
    let _socket_cleanup = SocketCleanup(path.clone());

    let bus = Arc::new(SystemBus::connect().await);
    let collector = Arc::new(Mutex::new(Collector::new()));
    let initial = collect_snapshot(&collector, &bus, &theme_path, &accent_path).await;
    let (snapshot_tx, snapshot_rx) = watch::channel(Arc::new(initial));
    let (refresh_tx, mut refresh_rx) = mpsc::channel::<()>(1);
    let _watcher = create_file_watcher(&theme_path, &accent_path, refresh_tx.clone())?;

    let collection_task = {
        let collector = Arc::clone(&collector);
        let bus = Arc::clone(&bus);
        let theme_path = theme_path.clone();
        let accent_path = accent_path.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(2));
            interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
            interval.tick().await;
            loop {
                tokio::select! {
                    _ = interval.tick() => {}
                    value = refresh_rx.recv() => if value.is_none() { break; },
                }
                let snapshot = collect_snapshot(&collector, &bus, &theme_path, &accent_path).await;
                snapshot_tx.send_replace(Arc::new(snapshot));
            }
        })
    };

    loop {
        tokio::select! {
            accepted = listener.accept() => match accepted {
                Ok((stream, _)) => {
                    tokio::spawn(handle_client(
                        stream,
                        snapshot_rx.clone(),
                        refresh_tx.clone(),
                        Arc::clone(&bus),
                    ));
                }
                Err(error) => eprintln!("system-backend: accept failed: {error}"),
            },
            _ = shutdown_signal() => break,
        }
    }
    collection_task.abort();
    Ok(())
}

async fn collect_snapshot(
    collector: &Mutex<Collector>,
    bus: &SystemBus,
    theme_path: &Path,
    accent_path: &Path,
) -> Snapshot {
    let (performance, activity) = collector.lock().await.collect();
    let dbus = bus.snapshot().await;
    Snapshot {
        event: "snapshot",
        system: SystemSnapshot {
            cpu_usage: performance.cpu,
            memory_usage: performance.memory,
            vpn_connected: dbus.vpn_connected,
            network_type: dbus.network_type,
            wifi_available: dbus.wifi_available,
            wifi_enabled: dbus.wifi_enabled,
            wifi_name: dbus.wifi_name,
            screen_recording: activity.screen_recording,
            camera_in_use: activity.camera_in_use,
            power_profiles_available: dbus.power_profiles_available,
            available_power_profiles: dbus.available_power_profiles,
            power_profile: dbus.power_profile,
            theme_mode: config::read_theme(theme_path),
            accent: config::read_accent(accent_path),
        },
        performance,
    }
}

async fn handle_client(
    stream: UnixStream,
    mut snapshots: watch::Receiver<Arc<Snapshot>>,
    refresh: mpsc::Sender<()>,
    bus: Arc<SystemBus>,
) {
    let (reader, mut writer) = stream.into_split();
    let mut lines = BufReader::new(reader).lines();
    let initial = snapshots.borrow().clone();
    if write_json_line(&mut writer, &*initial).await.is_err() {
        return;
    }
    loop {
        tokio::select! {
            changed = snapshots.changed() => {
                if changed.is_err() {
                    break;
                }
                let snapshot = snapshots.borrow_and_update().clone();
                if write_json_line(&mut writer, &*snapshot).await.is_err() { break; }
            }
            line = lines.next_line() => {
                let Ok(Some(line)) = line else { break; };
                let response = match parse_command(&line) {
                    Ok(Command::SetWifi { id, enabled }) => {
                        let result = tokio::time::timeout(
                            Duration::from_secs(6), bus.set_wifi(enabled)
                        ).await.unwrap_or_else(|_| Err("D-Bus request timed out".into()));
                        command_response(id, result, &refresh)
                    }
                    Ok(Command::SetPowerProfile { id, profile }) => {
                        let result = tokio::time::timeout(
                            Duration::from_secs(6), bus.set_power_profile(&profile)
                        ).await.unwrap_or_else(|_| Err("D-Bus request timed out".into()));
                        command_response(id, result, &refresh)
                    }
                    Ok(Command::Refresh { id }) => {
                        let _ = refresh.try_send(());
                        Response::ok(id)
                    }
                    Err((id, error)) => Response::error(id, error),
                };
                if write_json_line(&mut writer, &response).await.is_err() {
                    break;
                }
            }
        }
    }
}

fn command_response(id: u64, result: Result<(), String>, refresh: &mpsc::Sender<()>) -> Response {
    match result {
        Ok(()) => {
            let _ = refresh.try_send(());
            Response::ok(id)
        }
        Err(error) => Response::error(id, error),
    }
}

async fn write_json_line<T: serde::Serialize>(
    writer: &mut tokio::net::unix::OwnedWriteHalf,
    value: &T,
) -> std::io::Result<()> {
    let mut encoded = serde_json::to_vec(value).map_err(std::io::Error::other)?;
    encoded.push(b'\n');
    writer.write_all(&encoded).await
}

async fn bind_socket(path: &Path) -> Result<UnixListener, String> {
    let listener = match UnixListener::bind(path) {
        Ok(listener) => Ok(listener),
        Err(error) if error.kind() == ErrorKind::AddrInUse => {
            if UnixStream::connect(path).await.is_ok() {
                return Err(format!(
                    "another daemon is already listening at {}",
                    path.display()
                ));
            }
            std::fs::remove_file(path).map_err(|error| {
                format!("cannot remove stale socket {}: {error}", path.display())
            })?;
            UnixListener::bind(path).map_err(|error| {
                format!(
                    "cannot bind {} after stale cleanup: {error}",
                    path.display()
                )
            })
        }
        Err(error) => Err(format!("cannot bind {}: {error}", path.display())),
    }?;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))
        .map_err(|error| format!("cannot secure socket {}: {error}", path.display()))?;
    Ok(listener)
}

struct SocketCleanup(PathBuf);

impl Drop for SocketCleanup {
    fn drop(&mut self) {
        if let Err(error) = std::fs::remove_file(&self.0)
            && error.kind() != ErrorKind::NotFound
        {
            eprintln!(
                "system-backend: cannot remove socket {}: {error}",
                self.0.display()
            );
        }
    }
}

fn create_file_watcher(
    theme_path: &Path,
    accent_path: &Path,
    refresh: mpsc::Sender<()>,
) -> Result<RecommendedWatcher, String> {
    let targets = [theme_path.to_owned(), accent_path.to_owned()];
    let mut watcher = notify::recommended_watcher(move |event: notify::Result<notify::Event>| {
        let Ok(event) = event else {
            return;
        };
        if !matches!(
            event.kind,
            notify::EventKind::Create(_)
                | notify::EventKind::Modify(_)
                | notify::EventKind::Remove(_)
        ) {
            return;
        }
        if event.paths.iter().any(|path| targets.contains(path)) {
            let _ = refresh.try_send(());
        }
    })
    .map_err(|error| format!("cannot create file watcher: {error}"))?;
    let mut directories = HashSet::new();
    for path in [theme_path, accent_path] {
        let directory = path.parent().unwrap_or(path);
        let watched = directory
            .ancestors()
            .find(|candidate| candidate.exists())
            .unwrap_or(path);
        if !directories.insert(watched.to_owned()) {
            continue;
        }
        watcher
            .watch(watched, RecursiveMode::NonRecursive)
            .map_err(|error| format!("cannot watch {}: {error}", watched.display()))?;
    }
    Ok(watcher)
}

#[cfg(unix)]
async fn shutdown_signal() {
    let mut terminate = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        .expect("SIGTERM handler must be installable");
    tokio::select! {
        _ = tokio::signal::ctrl_c() => {}
        _ = terminate.recv() => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn socket_path_uses_runtime_and_user_fallback() {
        assert_eq!(
            socket_path_for(Some("/run/user/42".into()), "alice".into()),
            PathBuf::from("/run/user/42/qanda-shell-system.sock")
        );
        assert_eq!(
            socket_path_for(None, "alice".into()),
            PathBuf::from("/tmp/qanda-shell-system-alice.sock")
        );
    }
}
