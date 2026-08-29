use std::collections::HashMap;

use tokio::sync::RwLock;
use zbus::{
    Connection, Proxy,
    zvariant::{OwnedObjectPath, OwnedValue},
};

const NM_DESTINATION: &str = "org.freedesktop.NetworkManager";
const NM_PATH: &str = "/org/freedesktop/NetworkManager";
const NM_INTERFACE: &str = "org.freedesktop.NetworkManager";
const ACTIVE_INTERFACE: &str = "org.freedesktop.NetworkManager.Connection.Active";
const PPD_DESTINATION: &str = "net.hadess.PowerProfiles";
const PPD_PATH: &str = "/net/hadess/PowerProfiles";
const PPD_INTERFACE: &str = "net.hadess.PowerProfiles";

#[derive(Debug, Default)]
pub struct DbusSnapshot {
    pub vpn_connected: bool,
    pub network_type: String,
    pub wifi_available: bool,
    pub wifi_enabled: bool,
    pub wifi_name: String,
    pub power_profiles_available: bool,
    pub available_power_profiles: Vec<String>,
    pub power_profile: String,
}

pub struct SystemBus {
    connection: RwLock<Option<Connection>>,
}

impl SystemBus {
    pub async fn connect() -> Self {
        Self {
            connection: RwLock::new(Connection::system().await.ok()),
        }
    }

    async fn connection(&self) -> Option<Connection> {
        if let Some(connection) = self.connection.read().await.as_ref() {
            return Some(connection.clone());
        }
        let connection = Connection::system().await.ok()?;
        *self.connection.write().await = Some(connection.clone());
        Some(connection)
    }

    pub async fn snapshot(&self) -> DbusSnapshot {
        let mut result = DbusSnapshot {
            network_type: "disconnected".into(),
            power_profile: "balanced".into(),
            ..DbusSnapshot::default()
        };
        let Some(connection) = self.connection().await else {
            return result;
        };

        if let Ok(proxy) = Proxy::new(&connection, NM_DESTINATION, NM_PATH, NM_INTERFACE).await {
            result.wifi_available = proxy
                .get_property::<bool>("WirelessHardwareEnabled")
                .await
                .unwrap_or(false);
            result.wifi_enabled = proxy
                .get_property::<bool>("WirelessEnabled")
                .await
                .unwrap_or(false);
            let active_paths = proxy
                .get_property::<Vec<OwnedObjectPath>>("ActiveConnections")
                .await
                .unwrap_or_default();
            let primary = proxy
                .get_property::<OwnedObjectPath>("PrimaryConnection")
                .await
                .ok();

            for path in active_paths {
                let Ok(active) =
                    Proxy::new(&connection, NM_DESTINATION, path.as_str(), ACTIVE_INTERFACE).await
                else {
                    continue;
                };
                let kind = active
                    .get_property::<String>("Type")
                    .await
                    .unwrap_or_default();
                let vpn = active.get_property::<bool>("Vpn").await.unwrap_or(false)
                    || matches!(kind.as_str(), "vpn" | "wireguard");
                result.vpn_connected |= vpn;

                if !vpn {
                    let connection_type = match kind.as_str() {
                        "802-11-wireless" => "wifi",
                        "802-3-ethernet" => "ethernet",
                        _ => "disconnected",
                    };
                    if primary.as_ref() == Some(&path) || result.network_type == "disconnected" {
                        result.network_type = connection_type.into();
                    }
                    if connection_type == "wifi"
                        && (result.wifi_name.is_empty() || primary.as_ref() == Some(&path))
                    {
                        result.wifi_name = active
                            .get_property::<String>("Id")
                            .await
                            .unwrap_or_default();
                    }
                }
            }
        }

        if let Ok(proxy) = Proxy::new(&connection, PPD_DESTINATION, PPD_PATH, PPD_INTERFACE).await
            && let Ok(profile) = proxy.get_property::<String>("ActiveProfile").await
        {
            result.power_profiles_available = true;
            result.power_profile = profile;
            let profiles = proxy
                .get_property::<Vec<HashMap<String, OwnedValue>>>("Profiles")
                .await
                .unwrap_or_default();
            result.available_power_profiles = profiles
                .into_iter()
                .filter_map(|mut entry| entry.remove("Profile"))
                .filter_map(|value| String::try_from(value).ok())
                .collect();
        }
        result
    }

    pub async fn set_wifi(&self, enabled: bool) -> Result<(), String> {
        let connection = self
            .connection()
            .await
            .ok_or("system D-Bus is unavailable")?;
        let proxy = Proxy::new(&connection, NM_DESTINATION, NM_PATH, NM_INTERFACE)
            .await
            .map_err(|error| error.to_string())?;
        proxy
            .set_property("WirelessEnabled", enabled)
            .await
            .map_err(|error| error.to_string())
    }

    pub async fn set_power_profile(&self, profile: &str) -> Result<(), String> {
        let connection = self
            .connection()
            .await
            .ok_or("system D-Bus is unavailable")?;
        let proxy = Proxy::new(&connection, PPD_DESTINATION, PPD_PATH, PPD_INTERFACE)
            .await
            .map_err(|error| error.to_string())?;
        proxy
            .set_property("ActiveProfile", profile)
            .await
            .map_err(|error| error.to_string())
    }
}
