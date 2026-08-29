use std::sync::RwLock;
use std::time::Duration;

use reqwest::header::{ACCEPT_LANGUAGE, AUTHORIZATION, HeaderMap, HeaderValue, USER_AGENT};
use reqwest::{Method, RequestBuilder, StatusCode};
use serde::Deserialize;
use serde::de::DeserializeOwned;
use serde_json::{Value, json};
use url::Url;

use crate::model::{
    AccountStatus, DownloadInfo, RotorSettings, SearchResponse, StationResult, Track,
};

const BASE_URL: &str = "https://api.music.yandex.net/";
const CLIENT_HEADER: &str = "X-Yandex-Music-Client";
const CLIENT_VALUE: &str = "YandexMusicAndroid/24023621";
const DOWNLOAD_SIGN_SALT: &str = "XGRlBW9FXlekgbPrRHuSiA";

pub type Result<T> = std::result::Result<T, ApiError>;

#[derive(Debug, thiserror::Error)]
pub enum ApiError {
    #[error("invalid API client configuration: {0}")]
    Configuration(String),
    #[error("Yandex Music request failed: {0}")]
    Transport(#[from] reqwest::Error),
    #[error("Yandex Music API returned HTTP {status}: {message}")]
    Http { status: StatusCode, message: String },
    #[error("invalid Yandex Music response: {0}")]
    Response(String),
    #[error("Yandex Music account ID is unavailable; account_status must succeed first")]
    MissingAccount,
}

pub struct YandexApi {
    client: reqwest::Client,
    public_client: reqwest::Client,
    base_url: Url,
    account_uid: RwLock<Option<String>>,
}

impl YandexApi {
    pub fn new(token: &str) -> Result<Self> {
        Self::with_base_url(token, BASE_URL)
    }

    fn with_base_url(token: &str, base_url: &str) -> Result<Self> {
        if token.is_empty() {
            return Err(ApiError::Configuration("OAuth token is empty".into()));
        }

        let client = reqwest::Client::builder()
            .default_headers(reference_headers(token)?)
            .timeout(Duration::from_secs(10))
            .build()?;
        let public_client = reqwest::Client::builder()
            .timeout(Duration::from_secs(10))
            .build()?;

        Ok(Self {
            client,
            public_client,
            base_url: Url::parse(base_url)
                .map_err(|error| ApiError::Configuration(error.to_string()))?,
            account_uid: RwLock::new(None),
        })
    }

    pub async fn account_status(&self) -> Result<AccountStatus> {
        let status: AccountStatus = self.get("account/status", &[]).await?;
        if let Some(uid) = status
            .account
            .as_ref()
            .and_then(|account| account.uid.clone())
        {
            *self.account_uid.write().expect("account UID lock poisoned") = Some(uid);
        }
        Ok(status)
    }

    pub async fn search(&self, text: &str) -> Result<Vec<Track>> {
        let response: SearchResponse = self
            .get(
                "search",
                &[
                    ("text", text.to_owned()),
                    ("nocorrect", "False".into()),
                    ("type", "track".into()),
                    ("page", "0".into()),
                    ("playlist-in-best", "True".into()),
                ],
            )
            .await?;
        Ok(response
            .tracks
            .map_or_else(Vec::new, |tracks| tracks.results))
    }

    pub async fn tracks(&self, track_ids: &[String]) -> Result<Vec<Track>> {
        let mut form: Vec<(&str, &str)> = track_ids
            .iter()
            .map(|id| ("track-ids", id.as_str()))
            .collect();
        form.push(("with-positions", "True"));
        self.post_form("tracks", &form).await
    }

    pub async fn download_info(&self, track_id: &str) -> Result<Vec<DownloadInfo>> {
        self.get(&format!("tracks/{track_id}/download-info"), &[])
            .await
    }

    pub async fn direct_download_url(&self, info: &DownloadInfo) -> Result<String> {
        let response = self
            .download_metadata_request(&info.download_info_url)?
            .send()
            .await?;
        let status = response.status();
        let body = response.bytes().await?;
        if !status.is_success() {
            return Err(ApiError::Http {
                status,
                message: "download-info request failed".into(),
            });
        }
        build_direct_download_url(&body)
    }

    pub async fn like_track(&self, track_id: &str, liked: bool) -> Result<()> {
        self.track_preference("likes", track_id, liked).await
    }

    pub async fn dislike_track(&self, track_id: &str, disliked: bool) -> Result<()> {
        self.track_preference("dislikes", track_id, disliked).await
    }

    async fn track_preference(
        &self,
        preference: &str,
        track_id: &str,
        enabled: bool,
    ) -> Result<()> {
        let uid = self
            .account_uid
            .read()
            .expect("account UID lock poisoned")
            .clone()
            .ok_or(ApiError::MissingAccount)?;
        let action = if enabled { "add-multiple" } else { "remove" };
        let _: Value = self
            .post_form(
                &format!("users/{uid}/{preference}/tracks/{action}"),
                &[("track-ids", track_id)],
            )
            .await?;
        Ok(())
    }

    pub async fn station_info(&self, station: &str) -> Result<Vec<StationResult>> {
        self.get(&format!("rotor/station/{station}/info"), &[])
            .await
    }

    pub async fn station_settings(&self, station: &str, settings: &RotorSettings) -> Result<()> {
        let response: Value = self
            .send_json(self.station_settings_request(station, settings)?)
            .await?;
        if response == Value::String("ok".into()) || response == Value::Bool(true) {
            Ok(())
        } else {
            Err(ApiError::Response(
                "station settings were not acknowledged".into(),
            ))
        }
    }

    pub(crate) async fn rotor_session_new(&self, payload: &Value) -> Result<Value> {
        self.post_json("rotor/session/new", payload).await
    }

    pub(crate) async fn rotor_session_tracks(
        &self,
        session_id: &str,
        payload: &Value,
    ) -> Result<Value> {
        self.post_json(&format!("rotor/session/{session_id}/tracks"), payload)
            .await
    }

    pub(crate) async fn rotor_session_feedback(
        &self,
        session_id: &str,
        payload: &Value,
    ) -> Result<()> {
        let _: Value = self
            .post_json(&format!("rotor/session/{session_id}/feedback"), payload)
            .await?;
        Ok(())
    }

    async fn get<T: DeserializeOwned>(&self, path: &str, query: &[(&str, String)]) -> Result<T> {
        let query: Vec<(&str, &str)> = query
            .iter()
            .map(|(key, value)| (*key, value.as_str()))
            .collect();
        self.send_json(self.request(Method::GET, path)?.query(&query))
            .await
    }

    async fn post_form<T: DeserializeOwned>(
        &self,
        path: &str,
        form: &[(impl AsRef<str>, impl AsRef<str>)],
    ) -> Result<T> {
        let form: Vec<(&str, &str)> = form
            .iter()
            .map(|(key, value)| (key.as_ref(), value.as_ref()))
            .collect();
        self.send_json(self.request(Method::POST, path)?.form(&form))
            .await
    }

    async fn post_json<T: DeserializeOwned>(&self, path: &str, body: &Value) -> Result<T> {
        self.send_json(self.request(Method::POST, path)?.json(body))
            .await
    }

    fn request(&self, method: Method, path: &str) -> Result<RequestBuilder> {
        let url = self
            .base_url
            .join(path)
            .map_err(|error| ApiError::Configuration(error.to_string()))?;
        Ok(self.client.request(method, url))
    }

    fn download_metadata_request(&self, url: &str) -> Result<RequestBuilder> {
        let url = Url::parse(url).map_err(|error| ApiError::Configuration(error.to_string()))?;
        if !matches!(url.scheme(), "http" | "https") {
            return Err(ApiError::Configuration(
                "download-info URL must use HTTP or HTTPS".into(),
            ));
        }
        Ok(self
            .public_client
            .get(url)
            .header(USER_AGENT, "Yandex-Music-API"))
    }

    fn station_settings_request(
        &self,
        station: &str,
        settings: &RotorSettings,
    ) -> Result<RequestBuilder> {
        Ok(self
            .request(Method::POST, &format!("rotor/station/{station}/settings3"))?
            .json(&json!({
                "moodEnergy": settings.mood_energy.as_deref().unwrap_or("all"),
                "diversity": settings.diversity,
                "language": settings.language,
                "type": "rotor"
            })))
    }

    async fn send_json<T: DeserializeOwned>(&self, request: RequestBuilder) -> Result<T> {
        let response = request.send().await?;
        let status = response.status();
        let body = response.bytes().await?;
        let value: Value =
            serde_json::from_slice(&body).map_err(|error| ApiError::Response(error.to_string()))?;
        if !status.is_success() {
            let message = value
                .get("errorDescription")
                .or_else(|| value.get("error"))
                .and_then(Value::as_str)
                .unwrap_or("unknown API error")
                .to_owned();
            return Err(ApiError::Http { status, message });
        }
        serde_json::from_value(unwrap_result(value)?)
            .map_err(|error| ApiError::Response(error.to_string()))
    }
}

fn reference_headers(token: &str) -> Result<HeaderMap> {
    let mut authorization = HeaderValue::from_str(&format!("OAuth {token}"))
        .map_err(|error| ApiError::Configuration(error.to_string()))?;
    authorization.set_sensitive(true);
    let mut headers = HeaderMap::new();
    headers.insert(AUTHORIZATION, authorization);
    headers.insert(USER_AGENT, HeaderValue::from_static("Yandex-Music-API"));
    headers.insert(CLIENT_HEADER, HeaderValue::from_static(CLIENT_VALUE));
    headers.insert(ACCEPT_LANGUAGE, HeaderValue::from_static("ru"));
    Ok(headers)
}

pub fn unwrap_result(mut value: Value) -> Result<Value> {
    if let Some(error) = value.get("error").and_then(Value::as_str) {
        let description = value
            .get("errorDescription")
            .and_then(Value::as_str)
            .unwrap_or("");
        return Err(ApiError::Response(
            format!("{error} {description}").trim().to_owned(),
        ));
    }
    if value.get("result").is_some_and(|result| !result.is_null()) {
        Ok(value
            .get_mut("result")
            .expect("result checked above")
            .take())
    } else {
        Ok(value)
    }
}

#[derive(Deserialize)]
struct DownloadXml {
    host: String,
    path: String,
    ts: String,
    s: String,
}

fn build_direct_download_url(xml: &[u8]) -> Result<String> {
    let data: DownloadXml =
        quick_xml::de::from_reader(xml).map_err(|error| ApiError::Response(error.to_string()))?;
    let path_without_slash = data.path.strip_prefix('/').unwrap_or(&data.path);
    let sign = format!(
        "{:x}",
        md5::compute(format!(
            "{DOWNLOAD_SIGN_SALT}{path_without_slash}{}",
            data.s
        ))
    );
    Ok(format!(
        "https://{}/get-mp3/{sign}/{}{}",
        data.host, data.ts, data.path
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use reqwest::header::CONTENT_TYPE;
    use serde_json::json;

    #[test]
    fn client_uses_reference_headers() {
        let headers = reference_headers("fixture-token").unwrap();
        assert_eq!(headers[USER_AGENT], "Yandex-Music-API");
        assert_eq!(headers[CLIENT_HEADER], CLIENT_VALUE);
        assert_eq!(headers[ACCEPT_LANGUAGE], "ru");
        assert_eq!(headers[AUTHORIZATION], "OAuth fixture-token");
        assert!(headers[AUTHORIZATION].is_sensitive());
    }

    #[test]
    fn download_metadata_request_is_public_and_rejects_unsafe_schemes() {
        let api = YandexApi::new("fixture-token").unwrap();
        let request = api
            .download_metadata_request("https://metadata.example/download-info")
            .unwrap()
            .build()
            .unwrap();

        assert_eq!(request.method(), Method::GET);
        assert_eq!(
            request.url().as_str(),
            "https://metadata.example/download-info"
        );
        assert_eq!(request.headers()[USER_AGENT], "Yandex-Music-API");
        assert!(!request.headers().contains_key(AUTHORIZATION));
        assert!(!request.headers().contains_key(CLIENT_HEADER));
        assert!(!request.headers().contains_key(ACCEPT_LANGUAGE));
        assert!(api.download_metadata_request("file:///tmp/token").is_err());
    }

    #[test]
    fn wave_settings_request_uses_exact_json_contract() {
        let api = YandexApi::new("fixture-token").unwrap();
        let settings = RotorSettings {
            mood_energy: Some("calm".into()),
            diversity: "discover".into(),
            language: "any".into(),
        };
        let request = api
            .station_settings_request("user:onyourwave", &settings)
            .unwrap()
            .build()
            .unwrap();

        assert_eq!(request.method(), Method::POST);
        assert_eq!(
            request.url().as_str(),
            "https://api.music.yandex.net/rotor/station/user:onyourwave/settings3"
        );
        assert_eq!(request.headers()[CONTENT_TYPE], "application/json");
        let body: Value =
            serde_json::from_slice(request.body().unwrap().as_bytes().unwrap()).unwrap();
        assert_eq!(
            body,
            json!({
                "moodEnergy": "calm",
                "diversity": "discover",
                "language": "any",
                "type": "rotor"
            })
        );
    }

    #[test]
    fn signs_download_xml_like_reference_client() {
        let xml = br#"<download-info><host>host.example</host><path>/audio/file.mp3</path><ts>1234</ts><s>secret</s></download-info>"#;
        let path = "audio/file.mp3";
        let expected_sign = format!(
            "{:x}",
            md5::compute(format!("{DOWNLOAD_SIGN_SALT}{path}secret"))
        );
        assert_eq!(
            build_direct_download_url(xml).unwrap(),
            format!("https://host.example/get-mp3/{expected_sign}/1234/audio/file.mp3")
        );
    }

    #[test]
    fn leaves_root_responses_intact() {
        let value = json!({"radioSessionId": "fixture"});
        assert_eq!(unwrap_result(value.clone()).unwrap(), value);
    }
}
