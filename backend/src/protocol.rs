use serde::Serialize;
use serde_json::Value;

#[derive(Debug, PartialEq)]
pub enum Command {
    SetWifi { id: u64, enabled: bool },
    SetPowerProfile { id: u64, profile: String },
    Refresh { id: u64 },
}

#[derive(Debug, Serialize)]
pub struct Response {
    pub id: u64,
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

impl Response {
    pub fn ok(id: u64) -> Self {
        Self {
            id,
            ok: true,
            error: None,
        }
    }

    pub fn error(id: u64, error: impl Into<String>) -> Self {
        Self {
            id,
            ok: false,
            error: Some(error.into()),
        }
    }
}

pub fn parse_command(line: &str) -> Result<Command, (u64, String)> {
    let value: Value = serde_json::from_str(line).map_err(|error| (0, error.to_string()))?;
    let id = value
        .get("id")
        .and_then(Value::as_u64)
        .ok_or_else(|| (0, "id must be a non-negative integer".into()))?;
    let method = value
        .get("method")
        .and_then(Value::as_str)
        .ok_or_else(|| (id, "method must be a string".into()))?;

    match method {
        "set_wifi" => {
            let enabled = value
                .pointer("/params/enabled")
                .and_then(Value::as_bool)
                .ok_or_else(|| (id, "params.enabled must be a boolean".into()))?;
            Ok(Command::SetWifi { id, enabled })
        }
        "set_power_profile" => {
            let profile = value
                .pointer("/params/profile")
                .and_then(Value::as_str)
                .ok_or_else(|| (id, "params.profile must be a string".into()))?;
            if !matches!(profile, "power-saver" | "balanced" | "performance") {
                return Err((id, "unsupported power profile".into()));
            }
            Ok(Command::SetPowerProfile {
                id,
                profile: profile.into(),
            })
        }
        "refresh" => Ok(Command::Refresh { id }),
        _ => Err((id, "unknown method".into())),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_commands_and_profile_allowlist() {
        assert_eq!(
            parse_command(r#"{"id":1,"method":"set_wifi","params":{"enabled":true}}"#),
            Ok(Command::SetWifi {
                id: 1,
                enabled: true
            })
        );
        assert_eq!(
            parse_command(r#"{"id":2,"method":"set_power_profile","params":{"profile":"turbo"}}"#),
            Err((2, "unsupported power profile".into()))
        );
        assert_eq!(
            parse_command(r#"{"id":3,"method":"refresh"}"#),
            Ok(Command::Refresh { id: 3 })
        );
    }
}
