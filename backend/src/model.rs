use serde::Serialize;

#[derive(Clone, Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProcessSnapshot {
    pub pid: u32,
    pub name: String,
    pub cpu_percent: f64,
    pub memory_percent: f64,
    pub rss_bytes: u64,
}

#[derive(Clone, Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DiskSnapshot {
    pub device: String,
    pub total_bytes: u64,
    pub used_bytes: u64,
    pub available_bytes: u64,
    pub used_percent: f64,
}

#[derive(Clone, Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NetworkSnapshot {
    pub interface: String,
    pub rx_bytes_per_second: u64,
    pub tx_bytes_per_second: u64,
    pub rx_bytes_total: u64,
    pub tx_bytes_total: u64,
}

#[derive(Clone, Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PerformanceSnapshot {
    pub cpu: f64,
    pub gpu: f64,
    pub memory: f64,
    pub swap: f64,
    pub cpu_temp: f64,
    pub gpu_temp: f64,
    pub memory_used: u64,
    pub memory_total: u64,
    pub swap_used: u64,
    pub swap_total: u64,
    pub gpu_memory_used: u64,
    pub gpu_memory_total: u64,
    pub disk: DiskSnapshot,
    pub network: NetworkSnapshot,
    pub processes: Vec<ProcessSnapshot>,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SystemSnapshot {
    pub cpu_usage: f64,
    pub memory_usage: f64,
    pub vpn_connected: bool,
    pub network_type: String,
    pub wifi_available: bool,
    pub wifi_enabled: bool,
    pub wifi_name: String,
    pub screen_recording: bool,
    pub camera_in_use: bool,
    pub power_profiles_available: bool,
    pub available_power_profiles: Vec<String>,
    pub power_profile: String,
    pub theme_mode: String,
    pub accent: String,
}

impl Default for SystemSnapshot {
    fn default() -> Self {
        Self {
            cpu_usage: 0.0,
            memory_usage: 0.0,
            vpn_connected: false,
            network_type: "disconnected".into(),
            wifi_available: false,
            wifi_enabled: false,
            wifi_name: String::new(),
            screen_recording: false,
            camera_in_use: false,
            power_profiles_available: false,
            available_power_profiles: Vec::new(),
            power_profile: "balanced".into(),
            theme_mode: "dark".into(),
            accent: "#cbc6bf".into(),
        }
    }
}

#[derive(Clone, Debug, Default, Serialize)]
pub struct Snapshot {
    pub event: &'static str,
    pub system: SystemSnapshot,
    pub performance: PerformanceSnapshot,
}
