use serde::{Deserialize, Serialize};
use serde_json::Value;
use tokio::io::{AsyncBufRead, AsyncBufReadExt, AsyncReadExt};

pub const MAX_LINE: usize = 1024 * 1024;

#[derive(Debug, PartialEq, Eq)]
pub enum FrameError {
    Io(String),
    TooLarge,
    Unterminated,
}

pub async fn read_frame<R: AsyncBufRead + Unpin>(
    reader: &mut R,
) -> Result<Option<Vec<u8>>, FrameError> {
    let mut frame = Vec::with_capacity(8192);
    let count = reader
        .take((MAX_LINE + 1) as u64)
        .read_until(b'\n', &mut frame)
        .await
        .map_err(|error| FrameError::Io(error.to_string()))?;
    if count == 0 {
        return Ok(None);
    }
    if frame.len() > MAX_LINE {
        return Err(FrameError::TooLarge);
    }
    if frame.last() != Some(&b'\n') {
        return Err(FrameError::Unterminated);
    }
    Ok(Some(frame))
}

#[derive(Debug, Deserialize)]
pub struct Request {
    #[serde(default)]
    pub id: Option<Value>,
    #[serde(default = "default_method")]
    pub method: String,
    #[serde(default = "empty_params")]
    pub params: Value,
}

fn default_method() -> String {
    "status".into()
}

fn empty_params() -> Value {
    Value::Object(serde_json::Map::new())
}

#[derive(Debug, PartialEq)]
pub enum Command {
    Status,
    ReloadAuth,
    Search {
        query: String,
    },
    PlayTrack {
        id: String,
    },
    PlayWave,
    PlayPause,
    Next,
    Previous,
    PlayQueueIndex {
        index: usize,
    },
    Seek {
        position: f64,
    },
    Like,
    Dislike,
    LoadMore,
    SetWaveSettings {
        mood_energy: String,
        diversity: String,
        language: String,
    },
}

impl Request {
    pub fn command(&self) -> Result<Command, String> {
        let empty = serde_json::Map::new();
        let params = match &self.params {
            value if is_falsy(value) => &empty,
            Value::Object(params) => params,
            _ => return Err("Параметры команды должны быть JSON-объектом".to_owned()),
        };
        let command = match self.method.as_str() {
            "status" => Command::Status,
            "reload_auth" => Command::ReloadAuth,
            "search" => Command::Search {
                query: params.get("query").map_or_else(String::new, python_string),
            },
            "play_track" => Command::PlayTrack {
                id: params
                    .get("id")
                    .map(python_string)
                    .ok_or_else(|| "Отсутствует параметр id".to_owned())?,
            },
            "play_wave" => Command::PlayWave,
            "play_pause" => Command::PlayPause,
            "next" => Command::Next,
            "previous" => Command::Previous,
            "play_queue_index" => Command::PlayQueueIndex {
                index: params.get("index").and_then(python_index).ok_or_else(|| {
                    "Параметр index должен преобразовываться в неотрицательное целое число"
                        .to_owned()
                })?,
            },
            "seek" => Command::Seek {
                position: params
                    .get("position")
                    .map_or(Some(0.0), python_float)
                    .ok_or_else(|| "Параметр position должен быть конечным числом".to_owned())?,
            },
            "like" => Command::Like,
            "dislike" => Command::Dislike,
            "load_more" => Command::LoadMore,
            "set_wave_settings" => Command::SetWaveSettings {
                mood_energy: params
                    .get("moodEnergy")
                    .map_or_else(|| "all".into(), python_string),
                diversity: params
                    .get("diversity")
                    .map_or_else(|| "default".into(), python_string),
                language: params
                    .get("language")
                    .map_or_else(|| "any".into(), python_string),
            },
            method => return Err(format!("Неизвестная команда: {method}")),
        };
        Ok(command)
    }
}

fn is_falsy(value: &Value) -> bool {
    match value {
        Value::Null => true,
        Value::Bool(value) => !value,
        Value::Number(value) => value.as_f64() == Some(0.0),
        Value::String(value) => value.is_empty(),
        Value::Array(value) => value.is_empty(),
        Value::Object(value) => value.is_empty(),
    }
}

fn python_string(value: &Value) -> String {
    match value {
        Value::Null => "None".into(),
        Value::Bool(true) => "True".into(),
        Value::Bool(false) => "False".into(),
        Value::String(value) => value.clone(),
        _ => value.to_string(),
    }
}

fn python_index(value: &Value) -> Option<usize> {
    let integer = match value {
        Value::Bool(value) => return Some(usize::from(*value)),
        Value::Number(value) => {
            let number = value.as_f64()?;
            if !number.is_finite() {
                return None;
            }
            number.trunc()
        }
        Value::String(value) => {
            let integer = value.trim().parse::<i128>().ok()?;
            return usize::try_from(integer).ok();
        }
        _ => return None,
    };
    if integer < 0.0 || integer > usize::MAX as f64 {
        None
    } else {
        Some(integer as usize)
    }
}

fn python_float(value: &Value) -> Option<f64> {
    let value = match value {
        Value::Bool(value) => f64::from(u8::from(*value)),
        Value::Number(value) => value.as_f64()?,
        Value::String(value) => value.trim().parse().ok()?,
        _ => return None,
    };
    value.is_finite().then_some(value)
}

#[derive(Debug, Serialize)]
pub struct Response<'a, T: Serialize> {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<&'a Value>,
    pub result: T,
}

#[derive(Debug, Serialize)]
pub struct ErrorResponse<'a> {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<&'a Value>,
    pub error: String,
}

#[derive(Debug, Serialize)]
pub struct StatusEvent<T: Serialize> {
    pub event: &'static str,
    pub ok: bool,
    pub result: T,
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn request(method: &str, params: Value) -> Request {
        Request {
            id: Some(json!(7)),
            method: method.into(),
            params,
        }
    }

    #[test]
    fn validates_every_parameterized_command() {
        assert_eq!(
            request("search", json!({})).command().unwrap(),
            Command::Search {
                query: String::new()
            }
        );
        assert!(request("play_track", json!({})).command().is_err());
        assert!(
            request("play_queue_index", json!({"index": -1}))
                .command()
                .is_err()
        );
        assert!(
            request("seek", json!({"position": "no"}))
                .command()
                .is_err()
        );
        assert_eq!(
            request("seek", json!({})).command().unwrap(),
            Command::Seek { position: 0.0 }
        );
        assert!(request("status", json!([1])).command().is_err());
        assert_eq!(
            request("status", Value::Null).command().unwrap(),
            Command::Status
        );
        assert_eq!(
            request("set_wave_settings", json!({})).command().unwrap(),
            Command::SetWaveSettings {
                mood_energy: "all".into(),
                diversity: "default".into(),
                language: "any".into()
            }
        );
    }

    #[test]
    fn matches_python_falsy_params_and_scalar_coercions() {
        for params in [
            Value::Null,
            json!(false),
            json!(0),
            json!(""),
            json!([]),
            json!({}),
        ] {
            assert_eq!(
                request("status", params).command().unwrap(),
                Command::Status
            );
        }
        assert_eq!(
            request("play_track", json!({"id": 42})).command().unwrap(),
            Command::PlayTrack { id: "42".into() }
        );
        assert_eq!(
            request("play_track", json!({"id": true}))
                .command()
                .unwrap(),
            Command::PlayTrack { id: "True".into() }
        );
        for (value, expected) in [(json!(2.9), 2), (json!(" 3 "), 3), (json!(true), 1)] {
            assert_eq!(
                request("play_queue_index", json!({"index": value}))
                    .command()
                    .unwrap(),
                Command::PlayQueueIndex { index: expected }
            );
        }
        assert_eq!(
            request("seek", json!({"position": "12.5"}))
                .command()
                .unwrap(),
            Command::Seek { position: 12.5 }
        );
        assert!(
            request("play_queue_index", json!({"index": "1.5"}))
                .command()
                .is_err()
        );
        assert!(
            request("seek", json!({"position": "NaN"}))
                .command()
                .is_err()
        );
    }

    #[tokio::test]
    async fn frame_reader_bounds_allocation_and_requires_newline() {
        use tokio::io::{AsyncWriteExt, BufReader, duplex};

        let (mut writer, reader) = duplex(MAX_LINE + 2);
        let write = tokio::spawn(async move {
            writer.write_all(&vec![b'x'; MAX_LINE + 1]).await.unwrap();
        });
        assert_eq!(
            read_frame(&mut BufReader::new(reader)).await,
            Err(FrameError::TooLarge)
        );
        write.await.unwrap();

        let (mut writer, reader) = duplex(16);
        writer.write_all(b"{}").await.unwrap();
        drop(writer);
        assert_eq!(
            read_frame(&mut BufReader::new(reader)).await,
            Err(FrameError::Unterminated)
        );
    }

    #[tokio::test]
    async fn frame_reader_returns_one_complete_frame_at_a_time() {
        use tokio::io::{AsyncWriteExt, BufReader, duplex};
        let (mut writer, reader) = duplex(32);
        writer.write_all(b"one\ntwo\n").await.unwrap();
        drop(writer);
        let mut reader = BufReader::new(reader);
        assert_eq!(
            read_frame(&mut reader).await.unwrap(),
            Some(b"one\n".to_vec())
        );
        assert_eq!(
            read_frame(&mut reader).await.unwrap(),
            Some(b"two\n".to_vec())
        );
        assert_eq!(read_frame(&mut reader).await.unwrap(), None);
    }

    #[tokio::test]
    async fn in_progress_frame_survives_interleaved_event_work() {
        use tokio::io::{AsyncWriteExt, BufReader, duplex};
        let (mut writer, reader) = duplex(32);
        writer.write_all(b"part").await.unwrap();
        let mut reader = BufReader::new(reader);
        let frame = read_frame(&mut reader);
        tokio::pin!(frame);
        tokio::select! {
            _ = tokio::time::sleep(std::time::Duration::from_millis(5)) => {}
            result = &mut frame => panic!("partial frame completed unexpectedly: {result:?}"),
        }
        writer.write_all(b"ial\n").await.unwrap();
        assert_eq!(frame.await.unwrap(), Some(b"partial\n".to_vec()));
    }

    #[test]
    fn recognizes_all_parameterless_commands_and_rejects_unknown_ones() {
        for method in [
            "status",
            "reload_auth",
            "play_wave",
            "play_pause",
            "next",
            "previous",
            "like",
            "dislike",
            "load_more",
        ] {
            assert!(request(method, json!({})).command().is_ok(), "{method}");
        }
        assert!(request("play", json!({})).command().is_err());
    }

    #[test]
    fn response_ids_and_status_events_have_stable_shapes() {
        let id = json!("abc");
        assert_eq!(
            serde_json::to_value(Response {
                ok: true,
                id: Some(&id),
                result: json!({"x": 1})
            })
            .unwrap(),
            json!({"ok": true, "id": "abc", "result": {"x": 1}})
        );
        assert_eq!(
            serde_json::to_value(StatusEvent {
                event: "status",
                ok: true,
                result: json!({"playback": "stopped"})
            })
            .unwrap(),
            json!({"event": "status", "ok": true, "result": {"playback": "stopped"}})
        );
    }
}
