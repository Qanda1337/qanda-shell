use std::collections::{HashMap, HashSet, VecDeque};
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, Instant};

use serde::Serialize;
use serde_json::{Value, json};
use tokio::sync::{Mutex, RwLock, broadcast};

use crate::api::YandexApi;
use crate::model::{Track, TrackData};
use crate::mpv::{MpvEvent, MpvHandle};
use crate::protocol::Command;
use crate::wave::{WAVE_STATION, WaveItem, WaveSession};

const URL_CACHE_TTL: Duration = Duration::from_secs(30 * 60);
const SEARCH_CACHE_TTL: Duration = Duration::from_secs(120);
const WAVE_BUFFER_TARGET: usize = 8;

#[derive(Clone, Debug, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WaveSettings {
    pub mood_energy: String,
    pub diversity: String,
    pub language: String,
}

impl Default for WaveSettings {
    fn default() -> Self {
        Self {
            mood_energy: "all".into(),
            diversity: "default".into(),
            language: "any".into(),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpcomingTrack {
    #[serde(flatten)]
    pub track: TrackData,
    pub queue_index: usize,
}

#[derive(Clone, Debug, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Status {
    pub authenticated: bool,
    pub auth_error: String,
    pub playback: String,
    pub position: f64,
    pub duration: f64,
    pub volume: f64,
    pub current: Option<TrackData>,
    pub queue_index: isize,
    pub queue_length: usize,
    pub upcoming: Vec<UpcomingTrack>,
    pub error: String,
    pub queue_kind: String,
    pub wave_refreshing: bool,
    pub wave_settings: WaveSettings,
}

#[derive(Clone)]
struct QueueEntry {
    track: Track,
    wave_item: Option<WaveItem>,
}

struct PlayerState {
    authenticated: bool,
    auth_error: String,
    queue: Vec<QueueEntry>,
    queue_kind: String,
    index: Option<usize>,
    current: Option<TrackData>,
    load_generation: Option<u64>,
    playback: String,
    position: f64,
    duration: f64,
    volume: f64,
    error: String,
    wave_refreshing: bool,
    wave_settings: WaveSettings,
}

impl Default for PlayerState {
    fn default() -> Self {
        Self {
            authenticated: false,
            auth_error: "Требуется вход в Яндекс".into(),
            queue: Vec::new(),
            queue_kind: String::new(),
            index: None,
            current: None,
            load_generation: None,
            playback: "stopped".into(),
            position: 0.0,
            duration: 0.0,
            volume: 100.0,
            error: String::new(),
            wave_refreshing: false,
            wave_settings: WaveSettings::default(),
        }
    }
}

impl PlayerState {
    fn status(&self) -> Status {
        let upcoming = if self.queue_kind == "wave" {
            self.queue
                .iter()
                .enumerate()
                .skip(self.index.map_or(0, |index| index + 1))
                .map(|(queue_index, entry)| UpcomingTrack {
                    track: TrackData::from_track(
                        &entry.track,
                        entry.wave_item.as_ref().is_some_and(|item| item.liked),
                        false,
                    ),
                    queue_index,
                })
                .collect()
        } else {
            Vec::new()
        };
        Status {
            authenticated: self.authenticated,
            auth_error: self.auth_error.clone(),
            playback: self.playback.clone(),
            position: self.position,
            duration: if self.duration > 0.0 {
                self.duration
            } else {
                self.current.as_ref().map_or(0.0, |track| track.duration)
            },
            volume: self.volume,
            current: self.current.clone(),
            queue_index: self.index.map_or(-1, |index| index as isize),
            queue_length: self.queue.len(),
            upcoming,
            error: self.error.clone(),
            queue_kind: self.queue_kind.clone(),
            wave_refreshing: self.wave_refreshing,
            wave_settings: self.wave_settings.clone(),
        }
    }

    fn replace_wave(&mut self, items: Vec<WaveItem>) {
        self.queue = items
            .into_iter()
            .map(|item| QueueEntry {
                track: item.track.clone(),
                wave_item: Some(item),
            })
            .collect();
        self.queue_kind = "wave".into();
        self.index = Some(0);
    }

    fn refresh_wave(&mut self, items: Vec<WaveItem>) {
        let keep = self.index.map_or(0, |index| index + 1);
        self.queue.truncate(keep);
        self.queue.extend(items.into_iter().map(|item| QueueEntry {
            track: item.track.clone(),
            wave_item: Some(item),
        }));
        self.error.clear();
    }

    fn append_wave(&mut self, items: Vec<WaveItem>) {
        self.queue.extend(items.into_iter().map(|item| QueueEntry {
            track: item.track.clone(),
            wave_item: Some(item),
        }));
    }

    fn next_index(&self) -> Option<usize> {
        let index = self.index?;
        if self.queue.is_empty() {
            None
        } else if self.queue_kind == "wave" {
            Some(index + 1)
        } else {
            Some((index + 1) % self.queue.len())
        }
    }

    fn previous_index(&self) -> Option<usize> {
        let index = self.index?;
        if self.queue.is_empty() {
            None
        } else if self.queue_kind == "wave" {
            Some(index.saturating_sub(1))
        } else {
            Some((index + self.queue.len() - 1) % self.queue.len())
        }
    }
}

struct Timed<T> {
    at: Instant,
    value: T,
}

struct Caches {
    url_cache: HashMap<String, Timed<String>>,
    url_order: VecDeque<String>,
    url_fetching: HashSet<String>,
    search_cache: HashMap<String, Timed<Vec<TrackData>>>,
    search_order: VecDeque<String>,
}

pub struct Player {
    token_path: PathBuf,
    mpv: MpvHandle,
    state: Mutex<PlayerState>,
    api: RwLock<Option<Arc<YandexApi>>>,
    wave: Mutex<Option<WaveSession>>,
    caches: Mutex<Caches>,
    transitions: Mutex<()>,
    statuses: broadcast::Sender<Status>,
}

impl Player {
    #[must_use]
    pub fn new(token_path: PathBuf, mpv: MpvHandle) -> Arc<Self> {
        let state = PlayerState::default();
        let (statuses, _) = broadcast::channel(128);
        Arc::new(Self {
            token_path,
            mpv,
            state: Mutex::new(state),
            api: RwLock::new(None),
            wave: Mutex::new(None),
            caches: Mutex::new(Caches {
                url_cache: HashMap::new(),
                url_order: VecDeque::new(),
                url_fetching: HashSet::new(),
                search_cache: HashMap::new(),
                search_order: VecDeque::new(),
            }),
            transitions: Mutex::new(()),
            statuses,
        })
    }

    pub fn subscribe(&self) -> broadcast::Receiver<Status> {
        self.statuses.subscribe()
    }

    pub async fn status(&self) -> Status {
        self.state.lock().await.status()
    }

    async fn emit(&self) -> Status {
        let status = self.status().await;
        let _ = self.statuses.send(status.clone());
        status
    }

    pub async fn initialize(self: &Arc<Self>) {
        let _ = self.reload_auth().await;
    }

    pub async fn dispatch(self: &Arc<Self>, command: Command) -> Result<Value, String> {
        match command {
            Command::Status => {
                serde_json::to_value(self.status().await).map_err(|error| error.to_string())
            }
            Command::ReloadAuth => Ok(json!({"authenticated": self.reload_auth().await})),
            Command::Search { query } => {
                serde_json::to_value(self.search(&query).await?).map_err(|error| error.to_string())
            }
            Command::PlayTrack { id } => self.play_track(&id).await.map(to_value),
            Command::PlayWave => self.play_wave().await.map(to_value),
            Command::PlayPause => self.play_pause().await.map(to_value),
            Command::Next => self.next(false).await.map(to_value),
            Command::Previous => self.previous().await.map(to_value),
            Command::PlayQueueIndex { index } => self.play_queue_index(index).await.map(to_value),
            Command::Seek { position } => self.seek(position).await.map(to_value),
            Command::Like => self.like().await.map(to_value),
            Command::Dislike => self.dislike().await.map(to_value),
            Command::LoadMore => self.load_more().await.map(to_value),
            Command::SetWaveSettings {
                mood_energy,
                diversity,
                language,
            } => self
                .set_wave_settings(&mood_energy, &diversity, &language)
                .await
                .map(to_value),
        }
    }

    pub async fn reload_auth(&self) -> bool {
        let _transition = self.transitions.lock().await;
        let token = tokio::fs::read_to_string(&self.token_path)
            .await
            .unwrap_or_default()
            .trim()
            .to_owned();
        if token.is_empty() {
            *self.api.write().await = None;
            *self.wave.lock().await = None;
            let mut state = self.state.lock().await;
            state.authenticated = false;
            state.auth_error = "Требуется вход в Яндекс".into();
            drop(state);
            self.emit().await;
            return false;
        }
        let result = async {
            let api = Arc::new(YandexApi::new(&token).map_err(|error| error.to_string())?);
            api.account_status()
                .await
                .map_err(|error| error.to_string())?;
            let settings = api
                .station_info(WAVE_STATION)
                .await
                .ok()
                .and_then(|items| items.into_iter().find_map(|item| item.settings2));
            Ok::<_, String>((api, settings))
        }
        .await;
        match result {
            Ok((api, settings)) => {
                *self.wave.lock().await = Some(WaveSession::new(api.clone()));
                *self.api.write().await = Some(api);
                let mut state = self.state.lock().await;
                state.authenticated = true;
                state.auth_error.clear();
                if let Some(settings) = settings {
                    state.wave_settings = WaveSettings {
                        mood_energy: settings.mood_energy.unwrap_or_else(|| "all".into()),
                        diversity: settings.diversity,
                        language: settings.language,
                    };
                }
            }
            Err(error) => {
                *self.api.write().await = None;
                *self.wave.lock().await = None;
                let mut state = self.state.lock().await;
                state.authenticated = false;
                state.auth_error = format!("Ошибка авторизации: {error}");
            }
        }
        let authenticated = self.state.lock().await.authenticated;
        self.emit().await;
        authenticated
    }

    async fn api(&self) -> Result<Arc<YandexApi>, String> {
        if let Some(api) = self.api.read().await.clone() {
            Ok(api)
        } else {
            Err(self.state.lock().await.auth_error.clone())
        }
    }

    async fn search(&self, query: &str) -> Result<Vec<TrackData>, String> {
        let query = query.trim();
        if query.is_empty() {
            return Ok(Vec::new());
        }
        let key = query.to_lowercase();
        {
            let mut caches = self.caches.lock().await;
            if let Some(cached) = caches
                .search_cache
                .get(&key)
                .filter(|item| item.at.elapsed() < SEARCH_CACHE_TTL)
            {
                return Ok(cached.value.clone());
            }
            caches.search_cache.remove(&key);
        }
        let tracks = self
            .api()
            .await?
            .search(query)
            .await
            .map_err(|error| error.to_string())?;
        let values = tracks
            .into_iter()
            .take(8)
            .map(|track| TrackData::from_track(&track, false, false))
            .collect::<Vec<_>>();
        let mut caches = self.caches.lock().await;
        caches.search_cache.insert(
            key.clone(),
            Timed {
                at: Instant::now(),
                value: values.clone(),
            },
        );
        caches.search_order.retain(|item| item != &key);
        caches.search_order.push_back(key);
        while caches.search_order.len() > 24 {
            if let Some(old) = caches.search_order.pop_front() {
                caches.search_cache.remove(&old);
            }
        }
        Ok(values)
    }

    pub async fn play_track(self: &Arc<Self>, id: &str) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        let tracks = self
            .api()
            .await?
            .tracks(&[id.to_owned()])
            .await
            .map_err(|error| error.to_string())?;
        let track = tracks
            .into_iter()
            .next()
            .ok_or_else(|| "Трек недоступен".to_owned())?;
        self.play_single_track(track).await
    }

    async fn play_single_track(self: &Arc<Self>, track: Track) -> Result<Status, String> {
        let (current, generation) = self.load_track(&track, false).await?;
        let mut state = self.state.lock().await;
        state.queue = vec![QueueEntry {
            track,
            wave_item: None,
        }];
        state.queue_kind = "track".into();
        commit_current(&mut state, 0, current, generation);
        drop(state);
        self.prefetch_upcoming();
        Ok(self.emit().await)
    }

    pub async fn play_wave(self: &Arc<Self>) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        self.play_wave_locked().await
    }

    async fn play_wave_locked(self: &Arc<Self>) -> Result<Status, String> {
        let (refreshing, current_id, auth_error) = {
            let state = self.state.lock().await;
            (
                state.queue_kind == "wave" && state.current.is_some(),
                state
                    .index
                    .and_then(|index| state.queue.get(index))
                    .map(|entry| entry.track.track_id()),
                state.auth_error.clone(),
            )
        };
        let mut wave_guard = self.wave.lock().await;
        let wave = wave_guard.as_mut().ok_or(auth_error)?;
        let items = if let (true, Some(id)) = (refreshing, current_id) {
            wave.refresh(&id).await
        } else {
            wave.start().await
        }
        .map_err(|error| error.to_string())?;
        if items.is_empty() {
            return Err(if refreshing {
                "Яндекс не вернул новых рекомендаций"
            } else {
                "Моя волна сейчас недоступна"
            }
            .into());
        }
        drop(wave_guard);
        if refreshing {
            let mut state = self.state.lock().await;
            state.refresh_wave(items);
            drop(state);
            self.prefetch_upcoming();
            Ok(self.emit().await)
        } else {
            let first = items
                .first()
                .cloned()
                .expect("non-empty Wave response checked above");
            let (current, generation) = self.load_track(&first.track, first.liked).await?;
            let mut state = self.state.lock().await;
            state.replace_wave(items);
            commit_current(&mut state, 0, current, generation);
            drop(state);
            let status = self.emit().await;
            self.after_wave_play(first).await;
            Ok(status)
        }
    }

    async fn play_index(self: &Arc<Self>, index: usize) -> Result<Status, String> {
        let (actual, track, liked, wave_item) = {
            let state = self.state.lock().await;
            if state.queue.is_empty() {
                return Ok(state.status());
            }
            let actual = if state.queue_kind == "wave" {
                if index >= state.queue.len() {
                    return Err("Не удалось загрузить продолжение Моей волны".into());
                }
                index
            } else {
                index % state.queue.len()
            };
            let entry = state.queue[actual].clone();
            (
                actual,
                entry.track,
                entry.wave_item.as_ref().is_some_and(|item| item.liked),
                entry.wave_item,
            )
        };
        let (current, generation) = self.load_track(&track, liked).await?;
        {
            let mut state = self.state.lock().await;
            commit_current(&mut state, actual, current, generation);
        }
        let status = self.emit().await;
        if let Some(item) = wave_item {
            self.after_wave_play(item).await;
        } else {
            self.prefetch_upcoming();
        }
        Ok(status)
    }

    async fn load_track(&self, track: &Track, liked: bool) -> Result<(TrackData, u64), String> {
        let url = self.resolve_url(track).await?;
        let generation = self.mpv.load(&url).await?;
        Ok((TrackData::from_track(track, liked, false), generation))
    }

    async fn after_wave_play(self: &Arc<Self>, item: WaveItem) {
        if let Some(wave) = self.wave.lock().await.as_mut() {
            let _ = wave.track_started(&item).await;
        }
        self.ensure_wave_buffer();
        self.prefetch_upcoming();
    }

    async fn resolve_url(&self, track: &Track) -> Result<String, String> {
        let id = track.track_id();
        {
            let mut caches = self.caches.lock().await;
            if let Some(value) = caches
                .url_cache
                .get(&id)
                .filter(|item| item.at.elapsed() < URL_CACHE_TTL)
                .map(|item| item.value.clone())
            {
                caches.url_order.retain(|item| item != &id);
                caches.url_order.push_back(id);
                return Ok(value);
            }
            caches.url_cache.remove(&id);
        }
        let api = self.api().await?;
        let infos = api
            .download_info(&id)
            .await
            .map_err(|error| error.to_string())?;
        let info = infos
            .iter()
            .filter(|item| !item.preview && matches!(item.codec.as_str(), "aac" | "mp3"))
            .max_by_key(|item| (item.codec == "aac", item.bitrate_in_kbps))
            .or_else(|| {
                infos
                    .iter()
                    .filter(|item| matches!(item.codec.as_str(), "aac" | "mp3"))
                    .max_by_key(|item| (item.codec == "aac", item.bitrate_in_kbps))
            })
            .ok_or_else(|| "Нет доступного аудиопотока".to_owned())?;
        let url = api
            .direct_download_url(info)
            .await
            .map_err(|error| error.to_string())?;
        let mut caches = self.caches.lock().await;
        caches.url_cache.insert(
            id.clone(),
            Timed {
                at: Instant::now(),
                value: url.clone(),
            },
        );
        caches.url_order.retain(|item| item != &id);
        caches.url_order.push_back(id);
        while caches.url_order.len() > 16 {
            if let Some(old) = caches.url_order.pop_front() {
                caches.url_cache.remove(&old);
            }
        }
        Ok(url)
    }

    fn prefetch_upcoming(self: &Arc<Self>) {
        let player = self.clone();
        tokio::spawn(async move {
            let tracks = {
                let state = player.state.lock().await;
                let start = state.index.map_or(0, |index| index + 1);
                state
                    .queue
                    .iter()
                    .skip(start)
                    .take(3)
                    .map(|entry| entry.track.clone())
                    .collect::<Vec<_>>()
            };
            let pending = {
                let mut caches = player.caches.lock().await;
                tracks
                    .into_iter()
                    .filter(|track| {
                        let id = track.track_id();
                        let cached = caches
                            .url_cache
                            .get(&id)
                            .is_some_and(|item| item.at.elapsed() < URL_CACHE_TTL);
                        !cached && caches.url_fetching.insert(id)
                    })
                    .collect::<Vec<_>>()
            };
            for track in pending {
                let id = track.track_id();
                let player = player.clone();
                tokio::spawn(async move {
                    let _ = player.resolve_url(&track).await;
                    player.caches.lock().await.url_fetching.remove(&id);
                });
            }
        });
    }

    fn ensure_wave_buffer(self: &Arc<Self>) {
        let player = self.clone();
        tokio::spawn(async move {
            let _transition = player.transitions.lock().await;
            let should_extend = {
                let mut state = player.state.lock().await;
                let remaining = state
                    .index
                    .map_or(0, |index| state.queue.len().saturating_sub(index + 1));
                if state.queue_kind != "wave"
                    || state.wave_refreshing
                    || remaining >= WAVE_BUFFER_TARGET
                {
                    false
                } else {
                    state.wave_refreshing = true;
                    true
                }
            };
            if !should_extend {
                return;
            }
            player.emit().await;
            let result = player.extend_wave().await;
            let mut state = player.state.lock().await;
            state.wave_refreshing = false;
            if let Err(error) = result {
                state.error = format!("Не удалось обновить Волну: {error}");
            }
            drop(state);
            player.emit().await;
        });
    }

    async fn extend_wave(&self) -> Result<usize, String> {
        let mut wave = self.wave.lock().await;
        let items = wave
            .as_mut()
            .ok_or_else(|| "Моя волна недоступна".to_owned())?
            .fetch_more()
            .await
            .map_err(|error| error.to_string())?;
        drop(wave);
        let count = items.len();
        self.state.lock().await.append_wave(items);
        Ok(count)
    }

    pub async fn play_pause(&self) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        let has_current = self.state.lock().await.current.is_some();
        if has_current {
            self.mpv.send(json!(["cycle", "pause"])).await?;
        }
        Ok(self.status().await)
    }

    pub async fn play(self: &Arc<Self>) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        let (current, stopped, index) = {
            let state = self.state.lock().await;
            (
                state.current.is_some(),
                state.playback == "stopped",
                state.index,
            )
        };
        if !current {
            return Ok(self.status().await);
        }
        if stopped {
            self.play_index(index.unwrap_or(0)).await
        } else {
            self.mpv
                .send(json!(["set_property", "pause", false]))
                .await?;
            Ok(self.status().await)
        }
    }

    pub async fn pause(&self) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        if self.state.lock().await.current.is_some() {
            self.mpv
                .send(json!(["set_property", "pause", true]))
                .await?;
        }
        Ok(self.status().await)
    }

    pub async fn stop(&self) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        let has_current = self.state.lock().await.current.is_some();
        if has_current {
            self.mpv.send(json!(["stop"])).await?;
        }
        let mut state = self.state.lock().await;
        state.playback = "stopped".into();
        state.position = 0.0;
        drop(state);
        Ok(self.emit().await)
    }

    pub async fn set_volume(&self, volume: f64) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        self.mpv
            .send(json!(["set_property", "volume", volume.clamp(0.0, 100.0)]))
            .await?;
        Ok(self.status().await)
    }

    pub async fn next(self: &Arc<Self>, finished: bool) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        self.next_locked(finished).await
    }

    async fn next_locked(self: &Arc<Self>, finished: bool) -> Result<Status, String> {
        let (index, is_wave, target, item, played) = {
            let state = self.state.lock().await;
            let Some(index) = state.index else {
                return Ok(state.status());
            };
            if state.queue.is_empty() {
                return Ok(state.status());
            }
            (
                index,
                state.queue_kind == "wave",
                state.next_index().expect("non-empty queue has next index"),
                state.queue[index].wave_item.clone(),
                state.position,
            )
        };
        if !is_wave {
            return self.play_index(target).await;
        }
        let mut wave = self.wave.lock().await;
        if let (Some(wave), Some(item)) = (wave.as_mut(), item.as_ref()) {
            let duration = item.track.duration_ms.map(|value| value as f64 / 1000.0);
            let _ = if finished {
                wave.track_finished(item, played, duration)
            } else {
                wave.track_skipped(item, played, duration)
            };
        }
        let needs_more = index + 1 >= self.state.lock().await.queue.len();
        if needs_more {
            let items = wave
                .as_mut()
                .ok_or_else(|| "Моя волна недоступна".to_owned())?
                .fetch_more()
                .await
                .map_err(|error| error.to_string())?;
            if items.is_empty() {
                return Err("Не удалось загрузить продолжение Моей волны".into());
            }
            drop(wave);
            return self.play_wave_continuation(index + 1, items).await;
        } else {
            drop(wave);
        }
        self.play_index(index + 1).await
    }

    async fn play_wave_continuation(
        self: &Arc<Self>,
        index: usize,
        items: Vec<WaveItem>,
    ) -> Result<Status, String> {
        let first = items
            .first()
            .cloned()
            .ok_or_else(|| "Не удалось загрузить продолжение Моей волны".to_owned())?;
        let (current, generation) = self.load_track(&first.track, first.liked).await?;
        let mut state = self.state.lock().await;
        state.append_wave(items);
        commit_current(&mut state, index, current, generation);
        drop(state);
        let status = self.emit().await;
        self.after_wave_play(first).await;
        Ok(status)
    }

    pub async fn previous(self: &Arc<Self>) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        let (position, target, item) = {
            let state = self.state.lock().await;
            let Some(index) = state.index else {
                return Ok(state.status());
            };
            if state.queue.is_empty() {
                return Ok(state.status());
            }
            (
                state.position,
                state
                    .previous_index()
                    .expect("non-empty queue has previous index"),
                (state.queue_kind == "wave")
                    .then(|| state.queue[index].wave_item.clone())
                    .flatten(),
            )
        };
        if position > 5.0 {
            self.mpv.send(json!(["seek", 0, "absolute"])).await?;
            return Ok(self.status().await);
        }
        if let Some(item) = item.as_ref()
            && let Some(wave) = self.wave.lock().await.as_mut()
        {
            let _ = wave.track_skipped(
                item,
                position,
                item.track.duration_ms.map(|value| value as f64 / 1000.0),
            );
        }
        self.play_index(target).await
    }

    pub async fn play_queue_index(self: &Arc<Self>, index: usize) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        let (item, played) = {
            let state = self.state.lock().await;
            if state.queue.is_empty() {
                return Ok(state.status());
            }
            let item = if state.queue_kind == "wave" {
                state.queue[state.index.unwrap_or(0)].wave_item.clone()
            } else {
                None
            };
            (item, state.position)
        };
        if let Some(item) = item.as_ref()
            && let Some(wave) = self.wave.lock().await.as_mut()
        {
            let _ = wave.track_skipped(
                item,
                played,
                item.track.duration_ms.map(|v| v as f64 / 1000.0),
            );
        }
        self.play_index(index).await
    }

    pub async fn seek(&self, position: f64) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        self.mpv
            .send(json!(["seek", position.max(0.0), "absolute"]))
            .await?;
        Ok(self.status().await)
    }

    pub async fn like(&self) -> Result<Status, String> {
        let (id, liked) = {
            let state = self.state.lock().await;
            let Some(current) = &state.current else {
                return Ok(state.status());
            };
            (current.id.clone(), !current.liked)
        };
        self.api()
            .await?
            .like_track(&id, liked)
            .await
            .map_err(|error| error.to_string())?;
        let mut state = self.state.lock().await;
        if state
            .current
            .as_ref()
            .is_some_and(|current| current.id == id)
            && let Some(current) = state.current.as_mut()
        {
            current.liked = liked;
        }
        if state
            .current
            .as_ref()
            .is_some_and(|current| current.id == id)
            && let Some(index) = state.index
            && let Some(item) = state
                .queue
                .get_mut(index)
                .and_then(|entry| entry.wave_item.as_mut())
        {
            item.liked = liked;
        }
        drop(state);
        Ok(self.emit().await)
    }

    pub async fn dislike(self: &Arc<Self>) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        let id = {
            let state = self.state.lock().await;
            let Some(current) = &state.current else {
                return Ok(state.status());
            };
            current.id.clone()
        };
        self.api()
            .await?
            .dislike_track(&id, true)
            .await
            .map_err(|error| error.to_string())?;
        {
            let mut state = self.state.lock().await;
            if state
                .current
                .as_ref()
                .is_some_and(|current| current.id == id)
                && let Some(current) = state.current.as_mut()
            {
                current.disliked = true;
            }
        }
        self.next_locked(false).await
    }

    pub async fn load_more(self: &Arc<Self>) -> Result<Status, String> {
        let _transition = self.transitions.lock().await;
        if self.state.lock().await.queue_kind != "wave" {
            return Ok(self.status().await);
        }
        self.extend_wave().await?;
        self.prefetch_upcoming();
        Ok(self.emit().await)
    }

    pub async fn set_wave_settings(
        self: &Arc<Self>,
        mood: &str,
        diversity: &str,
        language: &str,
    ) -> Result<Status, String> {
        if !["all", "fun", "active", "calm", "sad"].contains(&mood) {
            return Err("Неизвестное настроение Волны".into());
        }
        if !["favorite", "popular", "discover", "default"].contains(&diversity) {
            return Err("Неизвестный режим разнообразия".into());
        }
        if !["any", "russian", "not-russian"].contains(&language) {
            return Err("Неизвестный язык Волны".into());
        }
        let _transition = self.transitions.lock().await;
        self.wave
            .lock()
            .await
            .as_ref()
            .ok_or_else(|| "Моя волна недоступна".to_owned())?
            .set_settings(mood, diversity, language)
            .await
            .map_err(|error| error.to_string())?;
        let mut state = self.state.lock().await;
        state.wave_settings = WaveSettings {
            mood_energy: mood.into(),
            diversity: diversity.into(),
            language: language.into(),
        };
        let refresh = state.queue_kind == "wave" && state.current.is_some();
        drop(state);
        if refresh {
            self.play_wave_locked().await
        } else {
            Ok(self.emit().await)
        }
    }

    pub async fn observe(self: &Arc<Self>, event: MpvEvent) {
        if let MpvEvent::EndFile {
            generation,
            reason,
            error,
        } = event
        {
            let _transition = self.transitions.lock().await;
            if self.state.lock().await.load_generation != Some(generation) {
                return;
            }
            match reason.as_str() {
                "eof" => {
                    if let Err(error) = self.next_locked(true).await {
                        self.set_automatic_error(error).await;
                    }
                }
                "error" => {
                    let detail = error.unwrap_or_else(|| "неизвестная ошибка mpv".into());
                    self.set_automatic_error(format!("Ошибка воспроизведения: {detail}"))
                        .await;
                }
                _ => {}
            }
            return;
        }
        if let MpvEvent::Exited(error) = event {
            let _transition = self.transitions.lock().await;
            self.set_automatic_error(error).await;
            return;
        }
        let mut state = self.state.lock().await;
        match event {
            MpvEvent::Pause(paused) => {
                state.playback = if paused {
                    "paused"
                } else if state.current.is_some() {
                    "playing"
                } else {
                    "stopped"
                }
                .into()
            }
            MpvEvent::Position(value) => state.position = value,
            MpvEvent::Duration(value) => state.duration = value,
            MpvEvent::Volume(value) => state.volume = value,
            MpvEvent::EndFile { .. } => unreachable!(),
            MpvEvent::Exited(_) => unreachable!(),
        }
        drop(state);
        self.emit().await;
    }

    pub async fn set_error(&self, error: String) {
        let mut state = self.state.lock().await;
        state.error = error;
        drop(state);
        self.emit().await;
    }

    pub async fn set_automatic_error(&self, error: String) {
        let mut state = self.state.lock().await;
        state.error = error;
        state.playback = "stopped".into();
        drop(state);
        self.emit().await;
    }
}

fn commit_current(state: &mut PlayerState, index: usize, current: TrackData, load_generation: u64) {
    state.index = Some(index);
    state.position = 0.0;
    state.duration = current.duration;
    state.current = Some(current);
    state.load_generation = Some(load_generation);
    state.playback = "playing".into();
    state.error.clear();
}

fn to_value(status: Status) -> Value {
    serde_json::to_value(status).expect("status is serializable")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{Album, Artist};

    fn track(id: &str) -> Track {
        Track {
            id: id.into(),
            title: Some(id.into()),
            artists: Vec::<Artist>::new(),
            albums: vec![Album {
                id: "a".into(),
                title: String::new(),
            }],
            cover_uri: None,
            og_image: None,
            duration_ms: Some(10_000),
            available: Some(true),
        }
    }
    fn item(id: &str) -> WaveItem {
        WaveItem {
            track: track(id),
            batch_id: "b".into(),
            liked: false,
        }
    }

    async fn cache_url(player: &Player, track: &Track, url: &str) {
        let id = track.track_id();
        let mut caches = player.caches.lock().await;
        caches.url_cache.insert(
            id.clone(),
            Timed {
                at: Instant::now(),
                value: url.into(),
            },
        );
        caches.url_order.push_back(id);
    }

    async fn seed_track_queue(player: &Player, tracks: Vec<Track>) {
        let current = TrackData::from_track(&tracks[0], false, false);
        let mut state = player.state.lock().await;
        state.queue = tracks
            .into_iter()
            .map(|track| QueueEntry {
                track,
                wave_item: None,
            })
            .collect();
        state.queue_kind = "track".into();
        commit_current(&mut state, 0, current, 0);
    }

    fn queue_identity(state: &PlayerState) -> Vec<(String, Option<(String, bool)>)> {
        state
            .queue
            .iter()
            .map(|entry| {
                (
                    entry.track.track_id(),
                    entry
                        .wave_item
                        .as_ref()
                        .map(|item| (item.batch_id.clone(), item.liked)),
                )
            })
            .collect()
    }

    #[test]
    fn wave_refresh_keeps_current_and_replaces_only_upcoming() {
        let mut state = PlayerState::default();
        state.replace_wave(vec![item("1"), item("2"), item("3")]);
        state.index = Some(1);
        state.refresh_wave(vec![item("4"), item("5")]);
        assert_eq!(
            state
                .queue
                .iter()
                .map(|entry| entry.track.id.as_str())
                .collect::<Vec<_>>(),
            ["1", "2", "4", "5"]
        );
        assert_eq!(state.index, Some(1));
    }

    #[test]
    fn status_exposes_only_wave_upcoming_with_queue_indices() {
        let mut state = PlayerState::default();
        state.replace_wave(vec![item("1"), item("2")]);
        let status = state.status();
        assert_eq!(status.upcoming.len(), 1);
        assert_eq!(status.upcoming[0].queue_index, 1);
        state.queue_kind = "track".into();
        assert!(state.status().upcoming.is_empty());
    }

    #[test]
    fn next_and_previous_wrap_tracks_but_not_wave() {
        let mut state = PlayerState {
            queue: vec![
                QueueEntry {
                    track: track("1"),
                    wave_item: None,
                },
                QueueEntry {
                    track: track("2"),
                    wave_item: None,
                },
            ],
            index: Some(0),
            queue_kind: "track".into(),
            ..PlayerState::default()
        };
        assert_eq!(state.previous_index(), Some(1));
        state.index = Some(1);
        assert_eq!(state.next_index(), Some(0));
        state.queue_kind = "wave".into();
        assert_eq!(state.next_index(), Some(2));
        state.index = Some(0);
        assert_eq!(state.previous_index(), Some(0));
    }

    #[test]
    fn status_uses_the_existing_camel_case_contract() {
        let value = serde_json::to_value(PlayerState::default().status()).unwrap();
        for key in [
            "authenticated",
            "authError",
            "playback",
            "position",
            "duration",
            "volume",
            "current",
            "queueIndex",
            "queueLength",
            "upcoming",
            "error",
            "queueKind",
            "waveRefreshing",
            "waveSettings",
        ] {
            assert!(value.get(key).is_some(), "missing {key}");
        }
    }

    #[tokio::test]
    async fn acknowledged_mpv_does_not_block_status_and_transitions_stay_ordered() {
        let (mpv, mut commands) = MpvHandle::fake(1);
        let player = Player::new(PathBuf::from("/missing-token"), mpv);
        player.state.lock().await.playback = "playing".into();

        let gate = player.transitions.lock().await;
        let first_player = player.clone();
        let first = tokio::spawn(async move { first_player.seek(1.0).await });
        tokio::task::yield_now().await;
        let second_player = player.clone();
        let second = tokio::spawn(async move { second_player.seek(2.0).await });
        tokio::task::yield_now().await;
        drop(gate);
        tokio::task::yield_now().await;

        let status = tokio::time::timeout(Duration::from_millis(50), player.status())
            .await
            .expect("state must remain responsive while mpv send is blocked");
        assert_eq!(status.playback, "playing");
        assert!(!first.is_finished());
        assert!(!second.is_finished());
        let first_command = commands.recv().await.unwrap();
        assert_eq!(first_command.value(), &json!(["seek", 1.0, "absolute"]));
        let request_id = first_command.request_id();
        first_command
            .respond(&json!({"request_id": request_id, "error": "success"}))
            .unwrap();
        first.await.unwrap().unwrap();
        let second_command = commands.recv().await.unwrap();
        assert_eq!(second_command.value(), &json!(["seek", 2.0, "absolute"]));
        let request_id = second_command.request_id();
        second_command
            .respond(&json!({"request_id": request_id, "error": "success"}))
            .unwrap();
        second.await.unwrap().unwrap();
    }

    #[tokio::test]
    async fn manual_next_ignores_old_eof_waiting_at_transition_boundary() {
        let (mpv, mut commands) = MpvHandle::fake(1);
        let player = Player::new(PathBuf::from("/missing-token"), mpv);
        let tracks = vec![track("old"), track("next"), track("later")];
        seed_track_queue(&player, tracks.clone()).await;
        cache_url(&player, &tracks[1], "https://audio/next").await;

        let next_player = player.clone();
        let manual_next = tokio::spawn(async move { next_player.next(false).await });
        let command = commands.recv().await.unwrap();
        let eof_player = player.clone();
        let old_eof = tokio::spawn(async move {
            eof_player
                .observe(MpvEvent::EndFile {
                    generation: 0,
                    reason: "eof".into(),
                    error: None,
                })
                .await;
        });
        tokio::task::yield_now().await;
        assert!(!old_eof.is_finished());

        let request_id = command.request_id();
        command
            .respond(&json!({"request_id": request_id, "error": "success"}))
            .unwrap();
        manual_next.await.unwrap().unwrap();
        old_eof.await.unwrap();

        let status = player.status().await;
        assert_eq!(status.queue_index, 1);
        assert_eq!(
            status.current.as_ref().map(|track| track.id.as_str()),
            Some("next:a")
        );
    }

    #[tokio::test]
    async fn matching_end_file_error_stops_but_stale_error_is_ignored() {
        let (mpv, mut commands) = MpvHandle::fake(1);
        let player = Player::new(PathBuf::from("/missing-token"), mpv);
        let tracks = vec![track("old"), track("next")];
        seed_track_queue(&player, tracks.clone()).await;
        cache_url(&player, &tracks[1], "https://audio/next").await;

        let next_player = player.clone();
        let manual_next = tokio::spawn(async move { next_player.next(false).await });
        let command = commands.recv().await.unwrap();
        let request_id = command.request_id();
        command
            .respond(&json!({"request_id": request_id, "error": "success"}))
            .unwrap();
        manual_next.await.unwrap().unwrap();

        player
            .observe(MpvEvent::EndFile {
                generation: 0,
                reason: "error".into(),
                error: Some("old decoder failure".into()),
            })
            .await;
        assert_eq!(player.status().await.playback, "playing");

        player
            .observe(MpvEvent::EndFile {
                generation: 1,
                reason: "error".into(),
                error: Some("HTTP 403".into()),
            })
            .await;
        let status = player.status().await;
        assert_eq!(status.queue_index, 1);
        assert_eq!(status.playback, "stopped");
        assert_eq!(status.error, "Ошибка воспроизведения: HTTP 403");
    }

    #[tokio::test]
    async fn hung_mpv_acknowledgement_releases_transition_lock() {
        let (mpv, mut commands) = MpvHandle::fake_with_timeout(1, Duration::from_millis(20));
        let player = Player::new(PathBuf::from("/missing-token"), mpv);
        let seek_player = player.clone();
        let seek = tokio::spawn(async move { seek_player.seek(4.0).await });
        let _hung = commands.recv().await.unwrap();

        assert_eq!(
            seek.await.unwrap(),
            Err("mpv не подтвердил команду вовремя".into())
        );
        let _transition =
            tokio::time::timeout(Duration::from_millis(20), player.transitions.lock())
                .await
                .expect("timed-out command must release transition lock");
    }

    #[tokio::test]
    async fn failed_load_rolls_back_index_current_and_single_track_queue() {
        let (mpv, mut commands) = MpvHandle::fake(2);
        let player = Player::new(PathBuf::from("/missing-token"), mpv);
        let old = track("old");
        let next = track("next");
        seed_track_queue(&player, vec![old.clone(), next.clone()]).await;
        cache_url(&player, &next, "https://audio/next").await;

        let next_player = player.clone();
        let transition = tokio::spawn(async move { next_player.next(false).await });
        let command = commands.recv().await.unwrap();
        assert_eq!(
            command.value(),
            &json!(["loadfile", "https://audio/next", "replace"])
        );
        let pending_status = player.status().await;
        assert_eq!(
            pending_status
                .current
                .as_ref()
                .map(|track| track.id.as_str()),
            Some("old:a")
        );
        assert_eq!(pending_status.queue_index, 0);
        let request_id = command.request_id();
        command
            .respond(&json!({"request_id": request_id, "error": "write failed"}))
            .unwrap();
        assert_eq!(
            transition.await.unwrap(),
            Err("mpv отклонил команду: write failed".into())
        );
        {
            let state = player.state.lock().await;
            assert_eq!(state.index, Some(0));
            assert_eq!(
                state.current.as_ref().map(|track| track.id.as_str()),
                Some("old:a")
            );
            assert_eq!(state.playback, "playing");
            assert_eq!(
                state
                    .queue
                    .iter()
                    .map(|entry| entry.track.id.as_str())
                    .collect::<Vec<_>>(),
                ["old", "next"]
            );
        }

        let replacement = track("replacement");
        cache_url(&player, &replacement, "https://audio/replacement").await;
        let replace_player = player.clone();
        let replace =
            tokio::spawn(async move { replace_player.play_single_track(replacement).await });
        let command = commands.recv().await.unwrap();
        let request_id = command.request_id();
        command
            .respond(&json!({"request_id": request_id, "error": "closed"}))
            .unwrap();
        assert_eq!(
            replace.await.unwrap(),
            Err("mpv отклонил команду: closed".into())
        );
        let state = player.state.lock().await;
        assert_eq!(
            state.current.as_ref().map(|track| track.id.as_str()),
            Some("old:a")
        );
        assert_eq!(
            state
                .queue
                .iter()
                .map(|entry| entry.track.id.as_str())
                .collect::<Vec<_>>(),
            ["old", "next"]
        );
    }

    #[tokio::test]
    async fn url_resolution_failure_preserves_full_status_and_queue_identity() {
        let (mpv, _commands) = MpvHandle::fake(1);
        let player = Player::new(PathBuf::from("/missing-token"), mpv);
        seed_track_queue(&player, vec![track("old"), track("queued")]).await;
        let before_status = player.status().await;
        let before_queue = queue_identity(&*player.state.lock().await);

        assert_eq!(
            player.play_single_track(track("uncached")).await,
            Err("Требуется вход в Яндекс".into())
        );
        assert_eq!(player.status().await, before_status);
        assert_eq!(queue_identity(&*player.state.lock().await), before_queue);
    }

    #[tokio::test]
    async fn rejected_wave_continuation_load_preserves_fetched_item_rollback() {
        let (mpv, mut commands) = MpvHandle::fake(1);
        let player = Player::new(PathBuf::from("/missing-token"), mpv);
        let current_item = item("wave-old");
        {
            let current = TrackData::from_track(&current_item.track, current_item.liked, false);
            let mut state = player.state.lock().await;
            state.replace_wave(vec![current_item]);
            commit_current(&mut state, 0, current, 0);
        }
        let fetched = vec![item("wave-next"), item("wave-later")];
        cache_url(&player, &fetched[0].track, "https://audio/wave-next").await;
        let before_status = player.status().await;
        let before_queue = queue_identity(&*player.state.lock().await);

        let continuation_player = player.clone();
        let continuation =
            tokio::spawn(
                async move { continuation_player.play_wave_continuation(1, fetched).await },
            );
        let command = commands.recv().await.unwrap();
        assert_eq!(
            command.value(),
            &json!(["loadfile", "https://audio/wave-next", "replace"])
        );
        let request_id = command.request_id();
        command
            .respond(&json!({"request_id": request_id, "error": "loading failed"}))
            .unwrap();
        assert_eq!(
            continuation.await.unwrap(),
            Err("mpv отклонил команду: loading failed".into())
        );
        assert_eq!(player.status().await, before_status);
        assert_eq!(queue_identity(&*player.state.lock().await), before_queue);
    }

    #[tokio::test]
    async fn exit_waits_for_transition_and_closed_mpv_cannot_commit_playing() {
        let (mpv, mut commands) = MpvHandle::fake(1);
        let player = Player::new(PathBuf::from("/missing-token"), mpv);
        let old = track("old");
        let next = track("next");
        seed_track_queue(&player, vec![old.clone(), next.clone()]).await;
        cache_url(&player, &next, "https://audio/next").await;

        let next_player = player.clone();
        let transition = tokio::spawn(async move { next_player.next(false).await });
        let command = commands.recv().await.unwrap();
        let exit_player = player.clone();
        let exit = tokio::spawn(async move {
            exit_player
                .observe(MpvEvent::Exited("mpv exited".into()))
                .await;
        });
        tokio::task::yield_now().await;
        assert!(!exit.is_finished());
        assert_eq!(
            player
                .status()
                .await
                .current
                .as_ref()
                .map(|track| track.id.as_str()),
            Some("old:a")
        );
        let request_id = command.request_id();
        command
            .respond(&json!({"request_id": request_id, "error": "success"}))
            .unwrap();
        transition.await.unwrap().unwrap();
        exit.await.unwrap();
        let status = player.status().await;
        assert_eq!(
            status.current.as_ref().map(|track| track.id.as_str()),
            Some("next:a")
        );
        assert_eq!(status.playback, "stopped");
        assert_eq!(status.error, "mpv exited");

        seed_track_queue(&player, vec![old, next.clone()]).await;
        let closed_player = player.clone();
        let closed = tokio::spawn(async move { closed_player.next(false).await });
        let pending = commands.recv().await.unwrap();
        drop(pending);
        drop(commands);
        assert_eq!(closed.await.unwrap(), Err("mpv недоступен".into()));
        let status = player.status().await;
        assert_eq!(
            status.current.as_ref().map(|track| track.id.as_str()),
            Some("old:a")
        );
        assert_eq!(status.playback, "playing");
    }

    #[tokio::test]
    async fn delayed_transition_boundary_does_not_block_state_observations() {
        let (mpv, _commands) = MpvHandle::fake(1);
        let player = Player::new(PathBuf::from("/missing-token"), mpv);
        let (release, wait) = tokio::sync::oneshot::channel::<()>();
        let boundary_player = player.clone();
        let boundary = tokio::spawn(async move {
            let _transition = boundary_player.transitions.lock().await;
            let _ = wait.await;
        });
        tokio::task::yield_now().await;
        tokio::time::timeout(
            Duration::from_millis(50),
            player.observe(MpvEvent::Position(4.5)),
        )
        .await
        .expect("mpv observation must not wait for delayed network transition");
        assert_eq!(player.status().await.position, 4.5);
        let _ = release.send(());
        boundary.await.unwrap();
    }

    #[tokio::test]
    async fn command_errors_preserve_playback_but_automatic_errors_stop() {
        let (mpv, _commands) = MpvHandle::fake(1);
        let player = Player::new(PathBuf::from("/missing-token"), mpv);
        player.state.lock().await.playback = "playing".into();
        player.set_error("command failed".into()).await;
        let status = player.status().await;
        assert_eq!(status.playback, "playing");
        assert_eq!(status.error, "command failed");
        player.set_automatic_error("EOF failed".into()).await;
        assert_eq!(player.status().await.playback, "stopped");
        player.state.lock().await.playback = "playing".into();
        player.observe(MpvEvent::Exited("mpv exited".into())).await;
        let status = player.status().await;
        assert_eq!(status.playback, "stopped");
        assert_eq!(status.error, "mpv exited");
    }

    #[tokio::test]
    async fn missing_token_initializes_unauthenticated_status() {
        let (mpv, _commands) = MpvHandle::fake(1);
        let player = Player::new(PathBuf::from("/definitely/missing/qanda-ymusic-token"), mpv);
        player.initialize().await;
        let status = player.status().await;
        assert!(!status.authenticated);
        assert_eq!(status.auth_error, "Требуется вход в Яндекс");
        assert_eq!(status.playback, "stopped");
    }
}
