use std::path::{Path, PathBuf};

pub const DEFAULT_ACCENT: &str = "#cbc6bf";

pub fn theme_path() -> PathBuf {
    if let Some(config) = std::env::var_os("XDG_CONFIG_HOME") {
        return PathBuf::from(config).join("theme/mode");
    }
    std::env::var_os("HOME").map_or_else(
        || PathBuf::from("/tmp/qanda-shell-theme-mode"),
        |home| PathBuf::from(home).join(".config/theme/mode"),
    )
}

pub fn read_theme(path: &Path) -> String {
    match std::fs::read_to_string(path).as_deref().map(str::trim) {
        Ok("light") => "light".into(),
        _ => "dark".into(),
    }
}

pub fn read_accent(path: &Path) -> String {
    std::fs::read_to_string(path)
        .ok()
        .map(|value| value.trim().to_owned())
        .filter(|value| valid_accent(value))
        .unwrap_or_else(|| DEFAULT_ACCENT.into())
}

fn valid_accent(value: &str) -> bool {
    value.len() == 7
        && value.starts_with('#')
        && value.as_bytes()[1..].iter().all(u8::is_ascii_hexdigit)
}

#[cfg(test)]
mod tests {
    use std::time::{SystemTime, UNIX_EPOCH};

    use super::*;

    #[test]
    fn validates_theme_and_accent_values() {
        assert!(valid_accent("#aBc123"));
        assert!(!valid_accent("#abcd"));
        assert!(!valid_accent("112233"));

        let missing = Path::new("/path/that/does/not/exist");
        assert_eq!(read_theme(missing), "dark");
        assert_eq!(read_accent(missing), DEFAULT_ACCENT);

        let suffix = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("clock must be after Unix epoch")
            .as_nanos();
        let path = std::env::temp_dir().join(format!("qanda-backend-config-{suffix}"));
        std::fs::write(&path, "light\n").expect("temporary theme must be writable");
        assert_eq!(read_theme(&path), "light");
        std::fs::write(&path, "#12aBcF\n").expect("temporary accent must be writable");
        assert_eq!(read_accent(&path), "#12aBcF");
        std::fs::write(&path, "not-a-color").expect("temporary accent must be writable");
        assert_eq!(read_accent(&path), DEFAULT_ACCENT);
        std::fs::remove_file(path).expect("temporary config must be removable");
    }
}
