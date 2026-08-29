use serde::{Deserialize, Deserializer, Serialize};

fn deserialize_id<'de, D>(deserializer: D) -> Result<String, D::Error>
where
    D: Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        serde_json::Value::String(value) => Ok(value),
        serde_json::Value::Number(value) => Ok(value.to_string()),
        _ => Err(serde::de::Error::custom("ID must be a string or number")),
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct Artist {
    #[serde(deserialize_with = "deserialize_id")]
    pub id: String,
    #[serde(default)]
    pub name: String,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct Album {
    #[serde(deserialize_with = "deserialize_id")]
    pub id: String,
    #[serde(default)]
    pub title: String,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct Track {
    #[serde(deserialize_with = "deserialize_id")]
    pub id: String,
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub artists: Vec<Artist>,
    #[serde(default)]
    pub albums: Vec<Album>,
    #[serde(default)]
    pub cover_uri: Option<String>,
    #[serde(default)]
    pub og_image: Option<String>,
    #[serde(default)]
    pub duration_ms: Option<u64>,
    #[serde(default)]
    pub available: Option<bool>,
}

impl Track {
    #[must_use]
    pub fn track_id(&self) -> String {
        self.albums.first().map_or_else(
            || self.id.clone(),
            |album| format!("{}:{}", self.id, album.id),
        )
    }

    #[must_use]
    pub fn cover_url(&self, size: &str) -> Option<String> {
        self.cover_uri
            .as_deref()
            .or(self.og_image.as_deref())
            .filter(|uri| !uri.is_empty())
            .map(|uri| format!("https://{}", uri.replace("%%", size)))
    }
}

#[derive(Clone, Debug, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TrackData {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub art_url: String,
    pub duration: f64,
    pub liked: bool,
    pub disliked: bool,
}

impl TrackData {
    #[must_use]
    pub fn from_track(track: &Track, liked: bool, disliked: bool) -> Self {
        let artist = track
            .artists
            .iter()
            .filter_map(|artist| (!artist.name.is_empty()).then_some(artist.name.as_str()))
            .collect::<Vec<_>>()
            .join(", ");

        Self {
            id: track.track_id(),
            title: track
                .title
                .clone()
                .filter(|title| !title.is_empty())
                .unwrap_or_else(|| "Без названия".into()),
            artist: if artist.is_empty() {
                "Неизвестный исполнитель".into()
            } else {
                artist
            },
            album: track
                .albums
                .first()
                .map(|album| album.title.as_str())
                .filter(|title| !title.is_empty())
                .unwrap_or("Яндекс Музыка")
                .into(),
            art_url: track.cover_url("400x400").unwrap_or_default(),
            duration: track.duration_ms.unwrap_or(0) as f64 / 1000.0,
            liked,
            disliked,
        }
    }
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Account {
    #[serde(default, deserialize_with = "deserialize_optional_id")]
    pub uid: Option<String>,
    #[serde(default)]
    pub display_name: Option<String>,
    #[serde(default)]
    pub service_available: bool,
}

fn deserialize_optional_id<'de, D>(deserializer: D) -> Result<Option<String>, D::Error>
where
    D: Deserializer<'de>,
{
    let value = Option::<serde_json::Value>::deserialize(deserializer)?;
    value
        .map(|value| match value {
            serde_json::Value::String(value) => Ok(value),
            serde_json::Value::Number(value) => Ok(value.to_string()),
            _ => Err(serde::de::Error::custom("ID must be a string or number")),
        })
        .transpose()
}

#[derive(Clone, Debug, Deserialize)]
pub struct AccountStatus {
    #[serde(default)]
    pub account: Option<Account>,
}

#[derive(Clone, Debug, Deserialize)]
pub(crate) struct SearchResponse {
    pub tracks: Option<SearchTracks>,
}

#[derive(Clone, Debug, Deserialize)]
pub(crate) struct SearchTracks {
    #[serde(default)]
    pub results: Vec<Track>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadInfo {
    pub codec: String,
    #[serde(default)]
    pub bitrate_in_kbps: u32,
    #[serde(default)]
    pub preview: bool,
    pub download_info_url: String,
    #[serde(default)]
    pub direct: bool,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct RotorSettings {
    pub language: String,
    pub diversity: String,
    #[serde(default)]
    pub mood_energy: Option<String>,
}

#[derive(Clone, Debug, Deserialize)]
pub struct StationResult {
    #[serde(default)]
    pub settings2: Option<RotorSettings>,
}
