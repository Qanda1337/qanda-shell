use std::collections::{HashMap, VecDeque};
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use serde_json::{Value, json};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use tokio::process::{Child, Command};
use tokio::sync::{broadcast, mpsc, oneshot};
use tokio::task::JoinHandle;

#[derive(Clone, Debug, PartialEq)]
pub enum MpvEvent {
    Pause(bool),
    Position(f64),
    Duration(f64),
    Volume(f64),
    EndFile {
        generation: u64,
        reason: String,
        error: Option<String>,
    },
    Exited(String),
}

#[derive(Clone)]
pub struct MpvHandle {
    commands: mpsc::Sender<MpvCommand>,
    cancellations: mpsc::Sender<u64>,
    next_request_id: Arc<AtomicU64>,
    next_load_generation: Arc<AtomicU64>,
    acknowledgement_timeout: Duration,
}

pub(crate) struct MpvCommand {
    request_id: u64,
    value: Value,
    completion: Option<oneshot::Sender<Result<(), String>>>,
    load_generation: Option<u64>,
}

impl MpvCommand {
    #[cfg(test)]
    pub(crate) fn value(&self) -> &Value {
        &self.value
    }

    #[cfg(test)]
    pub(crate) fn request_id(&self) -> u64 {
        self.request_id
    }

    #[cfg(test)]
    pub(crate) fn respond(self, response: &Value) -> Result<(), String> {
        let (request_id, result) = parse_command_response(response)
            .ok_or_else(|| "not an mpv command response".to_owned())?;
        if request_id != self.request_id {
            return Err(format!(
                "response request_id {request_id} does not match {}",
                self.request_id
            ));
        }
        self.complete(result);
        Ok(())
    }

    fn payload(&self) -> Value {
        json!({"command": self.value, "request_id": self.request_id})
    }

    pub(crate) fn complete(mut self, result: Result<(), String>) {
        if let Some(completion) = self.completion.take() {
            let _ = completion.send(result);
        }
    }
}

impl MpvHandle {
    pub async fn send(&self, command: Value) -> Result<(), String> {
        self.send_command(command, None).await
    }

    async fn send_command(
        &self,
        command: Value,
        load_generation: Option<u64>,
    ) -> Result<(), String> {
        let (completion, acknowledged) = oneshot::channel();
        let request_id = self.next_request_id.fetch_add(1, Ordering::Relaxed);
        let deadline = tokio::time::Instant::now() + self.acknowledgement_timeout;
        tokio::time::timeout_at(
            deadline,
            self.commands.send(MpvCommand {
                request_id,
                value: command,
                completion: Some(completion),
                load_generation,
            }),
        )
        .await
        .map_err(|_| "mpv не подтвердил команду вовремя".to_owned())?
        .map_err(|_| "mpv недоступен".to_owned())?;
        let mut cancellation = RequestCancellation::new(request_id, self.cancellations.clone());
        let result = tokio::time::timeout_at(deadline, acknowledged)
            .await
            .map_err(|_| "mpv не подтвердил команду вовремя".to_owned())?
            .map_err(|_| "mpv недоступен".to_owned())?;
        cancellation.disarm();
        result
    }

    pub async fn load(&self, url: &str) -> Result<u64, String> {
        let generation = self.next_load_generation.fetch_add(1, Ordering::Relaxed);
        self.send_command(json!(["loadfile", url, "replace"]), Some(generation))
            .await?;
        Ok(generation)
    }

    #[cfg(test)]
    pub(crate) fn fake(capacity: usize) -> (Self, mpsc::Receiver<MpvCommand>) {
        Self::fake_with_timeout(capacity, Duration::from_secs(3))
    }

    #[cfg(test)]
    pub(crate) fn fake_with_timeout(
        capacity: usize,
        acknowledgement_timeout: Duration,
    ) -> (Self, mpsc::Receiver<MpvCommand>) {
        let (commands, receiver) = mpsc::channel(capacity);
        let (cancellations, _) = mpsc::channel(capacity);
        (
            Self {
                commands,
                cancellations,
                next_request_id: Arc::new(AtomicU64::new(1)),
                next_load_generation: Arc::new(AtomicU64::new(1)),
                acknowledgement_timeout,
            },
            receiver,
        )
    }
}

struct RequestCancellation {
    request_id: Option<u64>,
    cancellations: mpsc::Sender<u64>,
}

impl RequestCancellation {
    fn new(request_id: u64, cancellations: mpsc::Sender<u64>) -> Self {
        Self {
            request_id: Some(request_id),
            cancellations,
        }
    }

    fn disarm(&mut self) {
        self.request_id = None;
    }
}

impl Drop for RequestCancellation {
    fn drop(&mut self) {
        if let Some(request_id) = self.request_id {
            let _ = self.cancellations.try_send(request_id);
        }
    }
}

struct PendingCommand {
    completion: oneshot::Sender<Result<(), String>>,
    load_generation: Option<u64>,
}

#[derive(Default)]
struct PendingCommands {
    commands: HashMap<u64, PendingCommand>,
}

impl PendingCommands {
    fn insert(&mut self, mut command: MpvCommand) -> bool {
        if let Some(completion) = command.completion.take() {
            if completion.is_closed() {
                return false;
            }
            self.commands.insert(
                command.request_id,
                PendingCommand {
                    completion,
                    load_generation: command.load_generation,
                },
            );
            return true;
        }
        false
    }

    fn resolve(&mut self, value: &Value) -> Option<(Option<u64>, bool)> {
        let (request_id, result) = parse_command_response(value)?;
        if let Some(command) = self.commands.remove(&request_id) {
            let accepted = result.is_ok();
            let _ = command.completion.send(result);
            return Some((command.load_generation, accepted));
        }
        Some((None, false))
    }

    fn cancel(&mut self, request_id: u64) -> Option<u64> {
        if let Some(command) = self.commands.remove(&request_id) {
            command.load_generation
        } else {
            None
        }
    }

    fn fail_all(&mut self, error: &str) {
        for (_, command) in self.commands.drain() {
            let _ = command.completion.send(Err(error.to_owned()));
        }
    }
}

fn parse_command_response(value: &Value) -> Option<(u64, Result<(), String>)> {
    let request_id = value.get("request_id")?.as_u64()?;
    let error = value.get("error")?.as_str()?;
    let result = if error == "success" {
        Ok(())
    } else {
        Err(format!("mpv отклонил команду: {error}"))
    };
    Some((request_id, result))
}

pub struct MpvProcess {
    shutdown: Option<oneshot::Sender<()>>,
    task: JoinHandle<()>,
}

impl MpvProcess {
    pub async fn spawn(
        socket_path: PathBuf,
    ) -> Result<(Self, MpvHandle, broadcast::Receiver<MpvEvent>), String> {
        remove_socket(&socket_path).await?;
        let mut child = Command::new("mpv")
            .args([
                "--idle=yes",
                "--no-video",
                "--terminal=no",
                "--audio-display=no",
                "--keep-open=no",
            ])
            .arg(format!("--input-ipc-server={}", socket_path.display()))
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .kill_on_drop(true)
            .spawn()
            .map_err(|error| format!("Не удалось запустить mpv: {error}"))?;
        let stream = match connect(&socket_path, &mut child).await {
            Ok(stream) => stream,
            Err(error) => {
                let _ = child.kill().await;
                let _ = child.wait().await;
                let _ = tokio::fs::remove_file(&socket_path).await;
                return Err(error);
            }
        };
        let (reader, mut writer) = stream.into_split();
        let (commands, mut command_rx) = mpsc::channel::<MpvCommand>(64);
        let (cancellations, mut cancellation_rx) = mpsc::channel::<u64>(64);
        let (events, event_rx) = broadcast::channel(64);
        let (shutdown, mut shutdown_rx) = oneshot::channel();
        let task_socket = socket_path.clone();
        let task = tokio::spawn(async move {
            let mut lines = BufReader::new(reader).lines();
            let mut pending = PendingCommands::default();
            let mut pending_loads = VecDeque::new();
            let mut active_generation = None;
            let mut expected_shutdown = false;
            let mut failure = None;
            for (id, name) in ["pause", "time-pos", "duration", "volume"]
                .into_iter()
                .enumerate()
            {
                let command = json!({"command": ["observe_property", id + 1, name]});
                if let Err(error) = write_json(&mut writer, &command).await {
                    failure = Some(format!("ошибка IPC mpv: {error}"));
                    break;
                }
            }
            while failure.is_none() {
                tokio::select! {
                    Some(command) = command_rx.recv() => {
                        let load_generation = command.load_generation;
                        match write_json(&mut writer, &command.payload()).await {
                            Ok(()) => {
                                let inserted = pending.insert(command);
                                if inserted && let Some(generation) = load_generation {
                                    pending_loads.push_back(generation);
                                }
                            }
                            Err(error) => {
                                let message = format!("ошибка IPC mpv: {error}");
                                command.complete(Err(message.clone()));
                                failure = Some(message);
                            }
                        }
                    }
                    Some(request_id) = cancellation_rx.recv() => {
                        if let Some(generation) = pending.cancel(request_id) {
                            pending_loads.retain(|item| *item != generation);
                        }
                    }
                    line = lines.next_line() => match line {
                        Ok(Some(line)) => if let Ok(value) = serde_json::from_str(&line) {
                            if let Some((load_generation, accepted)) = pending.resolve(&value) {
                                if !accepted && let Some(generation) = load_generation {
                                    pending_loads.retain(|item| *item != generation);
                                }
                            } else {
                                if value.get("event").and_then(Value::as_str) == Some("start-file")
                                    && let Some(generation) = pending_loads.pop_front()
                                {
                                    active_generation = Some(generation);
                                }
                                if let Some(event) = parse_event(&value, active_generation) {
                                    let _ = events.send(event);
                                }
                            }
                        },
                        Ok(None) => failure = Some("mpv закрыл IPC-соединение".into()),
                        Err(error) => failure = Some(format!("ошибка чтения IPC mpv: {error}")),
                    },
                    _ = &mut shutdown_rx => {
                        expected_shutdown = true;
                        break;
                    },
                }
            }
            pending.fail_all(failure.as_deref().unwrap_or("mpv завершает работу"));
            let already_exited = child.try_wait().ok().flatten();
            if already_exited.is_none() {
                let _ = child.kill().await;
            }
            let waited = child.wait().await;
            let _ = tokio::fs::remove_file(task_socket).await;
            if !expected_shutdown {
                let detail =
                    failure.unwrap_or_else(|| match already_exited.or_else(|| waited.ok()) {
                        Some(status) => format!("mpv неожиданно завершился: {status}"),
                        None => "mpv неожиданно завершился".into(),
                    });
                let _ = events.send(MpvEvent::Exited(detail));
            }
        });
        Ok((
            Self {
                shutdown: Some(shutdown),
                task,
            },
            MpvHandle {
                commands,
                cancellations,
                next_request_id: Arc::new(AtomicU64::new(1)),
                next_load_generation: Arc::new(AtomicU64::new(1)),
                acknowledgement_timeout: Duration::from_secs(3),
            },
            event_rx,
        ))
    }

    pub async fn shutdown(mut self) {
        if let Some(shutdown) = self.shutdown.take() {
            let _ = shutdown.send(());
        }
        let _ = self.task.await;
    }
}

async fn connect(path: &Path, child: &mut Child) -> Result<UnixStream, String> {
    for _ in 0..100 {
        if child
            .try_wait()
            .map_err(|error| error.to_string())?
            .is_some()
        {
            return Err("mpv завершился до создания IPC-сокета".into());
        }
        match UnixStream::connect(path).await {
            Ok(stream) => return Ok(stream),
            Err(_) => tokio::time::sleep(Duration::from_millis(50)).await,
        }
    }
    Err("Истекло время ожидания IPC-сокета mpv".into())
}

async fn remove_socket(path: &Path) -> Result<(), String> {
    match tokio::fs::remove_file(path).await {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(format!("Не удалось удалить старый сокет mpv: {error}")),
    }
}

async fn write_json(
    writer: &mut tokio::net::unix::OwnedWriteHalf,
    value: &Value,
) -> std::io::Result<()> {
    let mut bytes = serde_json::to_vec(value)?;
    bytes.push(b'\n');
    writer.write_all(&bytes).await
}

pub fn parse_event(value: &Value, active_generation: Option<u64>) -> Option<MpvEvent> {
    match value.get("event")?.as_str()? {
        "property-change" => match value.get("name")?.as_str()? {
            "pause" => value.get("data")?.as_bool().map(MpvEvent::Pause),
            "time-pos" => value.get("data")?.as_f64().map(MpvEvent::Position),
            "duration" => value.get("data")?.as_f64().map(MpvEvent::Duration),
            "volume" => value.get("data")?.as_f64().map(MpvEvent::Volume),
            _ => None,
        },
        "end-file" => Some(MpvEvent::EndFile {
            generation: active_generation?,
            reason: value.get("reason")?.as_str()?.to_owned(),
            error: value
                .get("error")
                .and_then(Value::as_str)
                .map(str::to_owned),
        }),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn parses_observations_and_all_end_file_reasons() {
        assert_eq!(
            parse_event(
                &json!({"event":"property-change","name":"time-pos","data":1.5}),
                None
            ),
            Some(MpvEvent::Position(1.5))
        );
        assert_eq!(
            parse_event(&json!({"event":"end-file","reason":"eof"}), Some(7)),
            Some(MpvEvent::EndFile {
                generation: 7,
                reason: "eof".into(),
                error: None,
            })
        );
        assert_eq!(
            parse_event(
                &json!({"event":"end-file","reason":"error","error":"HTTP 403"}),
                Some(8),
            ),
            Some(MpvEvent::EndFile {
                generation: 8,
                reason: "error".into(),
                error: Some("HTTP 403".into()),
            })
        );
        for reason in ["stop", "quit", "redirect", "unknown"] {
            assert!(matches!(
                parse_event(&json!({"event":"end-file","reason":reason}), Some(9)),
                Some(MpvEvent::EndFile { reason: parsed, .. }) if parsed == reason
            ));
        }
    }

    #[tokio::test]
    async fn fake_handle_waits_for_write_acknowledgement() {
        let (handle, mut commands) = MpvHandle::fake(1);
        let send = tokio::spawn(async move { handle.send(json!(["first"])).await });
        tokio::task::yield_now().await;
        assert!(!send.is_finished());
        let command = commands.recv().await.unwrap();
        assert_eq!(command.value(), &json!(["first"]));
        let request_id = command.request_id();
        command
            .respond(&json!({"request_id": request_id, "error": "success"}))
            .unwrap();
        send.await.unwrap().unwrap();
    }

    #[tokio::test]
    async fn fake_handle_reports_write_failure_and_owner_drop() {
        let (handle, mut commands) = MpvHandle::fake(1);
        let failed_handle = handle.clone();
        let failed = tokio::spawn(async move { failed_handle.send(json!(["failed"])).await });
        let command = commands.recv().await.unwrap();
        let request_id = command.request_id();
        command
            .respond(&json!({"request_id": request_id, "error": "invalid parameter"}))
            .unwrap();
        assert_eq!(
            failed.await.unwrap(),
            Err("mpv отклонил команду: invalid parameter".into())
        );

        let closed = tokio::spawn(async move { handle.send(json!(["closed"])).await });
        let pending = commands.recv().await.unwrap();
        drop(commands);
        drop(pending);
        assert_eq!(closed.await.unwrap(), Err("mpv недоступен".into()));
    }

    #[tokio::test]
    async fn pending_router_matches_out_of_order_responses_by_request_id() {
        let (handle, mut commands) = MpvHandle::fake(2);
        let first_handle = handle.clone();
        let first = tokio::spawn(async move { first_handle.send(json!(["first"])).await });
        let second = tokio::spawn(async move { handle.send(json!(["second"])).await });
        let command_a = commands.recv().await.unwrap();
        let command_b = commands.recv().await.unwrap();
        let (first_command, second_command) = if command_a.value() == &json!(["first"]) {
            (command_a, command_b)
        } else {
            (command_b, command_a)
        };
        let first_id = first_command.request_id();
        let second_id = second_command.request_id();
        assert_ne!(first_id, second_id);
        let mut pending = PendingCommands::default();
        assert!(pending.insert(first_command));
        assert!(pending.insert(second_command));
        assert!(
            pending
                .resolve(&json!({"request_id": second_id, "error": "success"}))
                .is_some()
        );
        assert!(
            pending
                .resolve(&json!({"request_id": first_id, "error": "bad command"}))
                .is_some()
        );
        assert_eq!(second.await.unwrap(), Ok(()));
        assert_eq!(
            first.await.unwrap(),
            Err("mpv отклонил команду: bad command".into())
        );
        assert_eq!(
            parse_event(
                &json!({"event":"property-change","name":"volume","data":25.0}),
                None
            ),
            Some(MpvEvent::Volume(25.0))
        );
    }

    #[tokio::test]
    async fn hung_acknowledgement_times_out() {
        let (handle, mut commands) = MpvHandle::fake_with_timeout(1, Duration::from_millis(20));
        let send = tokio::spawn(async move { handle.send(json!(["hung"])).await });
        let _pending = commands.recv().await.unwrap();
        assert_eq!(
            send.await.unwrap(),
            Err("mpv не подтвердил команду вовремя".into())
        );
    }

    #[test]
    fn cancellation_cleans_pending_request_state() {
        let (_handle, mut commands) = MpvHandle::fake(1);
        let mut pending = PendingCommands::default();
        let command = commands.try_recv();
        assert!(command.is_err());

        let (completion, _acknowledged) = oneshot::channel();
        assert!(pending.insert(MpvCommand {
            request_id: 4,
            value: json!(["hung"]),
            completion: Some(completion),
            load_generation: Some(2),
        }));
        assert_eq!(pending.commands.len(), 1);
        assert_eq!(pending.cancel(4), Some(2));
        assert!(pending.commands.is_empty());

        let (completion, acknowledged) = oneshot::channel();
        drop(acknowledged);
        assert!(!pending.insert(MpvCommand {
            request_id: 5,
            value: json!(["cancelled-before-write"]),
            completion: Some(completion),
            load_generation: None,
        }));
        assert!(pending.commands.is_empty());
    }
}
