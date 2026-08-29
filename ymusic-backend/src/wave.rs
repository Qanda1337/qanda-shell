use std::collections::{HashSet, VecDeque};
use std::sync::Arc;

use chrono::{SecondsFormat, Utc};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::api::{ApiError, Result, YandexApi, unwrap_result};
use crate::model::{RotorSettings, Track};

pub const WAVE_STATION: &str = "user:onyourwave";
pub const FEEDBACK_FROM: &str = "web-home-rup_main-radio-default";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct WaveItem {
    pub track: Track,
    pub batch_id: String,
    pub liked: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct Feedback<'a> {
    from: &'a str,
    batch_id: &'a str,
    event: FeedbackEvent<'a>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct FeedbackEvent<'a> {
    #[serde(rename = "type")]
    kind: &'a str,
    timestamp: &'a str,
    track_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    total_played_seconds: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    track_length_seconds: Option<f64>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SessionResponse {
    #[serde(default, alias = "radio_session_id")]
    radio_session_id: Option<String>,
    #[serde(default, alias = "batch_id")]
    batch_id: Option<String>,
    #[serde(default)]
    wave: Option<WaveMetadata>,
    #[serde(default)]
    sequence: Vec<SequenceItem>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct WaveMetadata {
    #[serde(default, alias = "id_for_from")]
    id_for_from: Option<String>,
}

#[derive(Deserialize)]
struct SequenceItem {
    #[serde(default)]
    track: Option<Track>,
    #[serde(default)]
    liked: bool,
}

pub struct WaveSession {
    api: Option<Arc<YandexApi>>,
    history_limit: usize,
    seen_limit: usize,
    session_id: String,
    batch_id: String,
    feedback_from: String,
    history: VecDeque<String>,
    seen_order: VecDeque<String>,
    seen: HashSet<String>,
    feedbacks: Vec<Value>,
}

impl WaveSession {
    #[must_use]
    pub fn new(api: Arc<YandexApi>) -> Self {
        Self::with_limits(api, 20, 300)
    }

    #[must_use]
    pub fn with_limits(api: Arc<YandexApi>, history_limit: usize, seen_limit: usize) -> Self {
        Self::create(Some(api), history_limit, seen_limit)
    }

    #[doc(hidden)]
    #[must_use]
    pub fn without_api(history_limit: usize, seen_limit: usize) -> Self {
        Self::create(None, history_limit, seen_limit)
    }

    fn create(api: Option<Arc<YandexApi>>, history_limit: usize, seen_limit: usize) -> Self {
        Self {
            api,
            history_limit,
            seen_limit,
            session_id: String::new(),
            batch_id: String::new(),
            feedback_from: FEEDBACK_FROM.into(),
            history: VecDeque::with_capacity(history_limit),
            seen_order: VecDeque::with_capacity(seen_limit),
            seen: HashSet::with_capacity(seen_limit),
            feedbacks: Vec::new(),
        }
    }

    #[must_use]
    pub fn active(&self) -> bool {
        !self.session_id.is_empty()
    }

    #[must_use]
    pub fn session_id(&self) -> Option<&str> {
        self.active().then_some(self.session_id.as_str())
    }

    #[must_use]
    pub fn history(&self) -> &VecDeque<String> {
        &self.history
    }

    pub async fn start(&mut self) -> Result<Vec<WaveItem>> {
        let payload = json!({
            "includeTracksInResponse": true,
            "includeWaveModel": true,
            "interactive": true,
            "seeds": [WAVE_STATION]
        });
        let response = self.api()?.rotor_session_new(&payload).await?;
        self.history.clear();
        self.seen_order.clear();
        self.seen.clear();
        self.feedbacks.clear();
        self.apply_response(response)
    }

    pub async fn track_started(&self, item: &WaveItem) -> Result<()> {
        if !self.active() {
            return Ok(());
        }
        let timestamp = timestamp();
        let feedback = self.feedback(item, "trackStarted", &timestamp, None, None)?;
        self.api()?
            .rotor_session_feedback(&self.session_id, &feedback)
            .await
    }

    pub fn track_finished(
        &mut self,
        item: &WaveItem,
        played_seconds: f64,
        track_length: Option<f64>,
    ) -> Result<()> {
        self.queue_feedback(item, "trackFinished", played_seconds, track_length)
    }

    pub fn track_skipped(
        &mut self,
        item: &WaveItem,
        played_seconds: f64,
        track_length: Option<f64>,
    ) -> Result<()> {
        self.queue_feedback(item, "skip", played_seconds, track_length)
    }

    fn queue_feedback(
        &mut self,
        item: &WaveItem,
        kind: &str,
        played_seconds: f64,
        track_length: Option<f64>,
    ) -> Result<()> {
        let timestamp = timestamp();
        let feedback = self.feedback(
            item,
            kind,
            &timestamp,
            Some(played_seconds.max(0.0)),
            track_length.map(|v| v.max(0.0)),
        )?;
        self.feedbacks.push(feedback);
        self.remember_history(item.track.track_id());
        Ok(())
    }

    pub async fn fetch_more(&mut self) -> Result<Vec<WaveItem>> {
        if !self.active() {
            return self.start().await;
        }
        let payload = json!({"feedbacks": self.feedbacks, "queue": self.history});
        let response = self
            .api()?
            .rotor_session_tracks(&self.session_id, &payload)
            .await?;
        self.feedbacks.clear();
        self.apply_response(response)
    }

    pub async fn refresh(&mut self, current_track_id: &str) -> Result<Vec<WaveItem>> {
        self.remember_history(current_track_id.to_owned());
        self.fetch_more().await
    }

    pub async fn set_settings(
        &self,
        mood_energy: &str,
        diversity: &str,
        language: &str,
    ) -> Result<()> {
        self.api()?
            .station_settings(
                WAVE_STATION,
                &RotorSettings {
                    language: language.into(),
                    diversity: diversity.into(),
                    mood_energy: Some(mood_energy.into()),
                },
            )
            .await
    }

    pub fn apply_response(&mut self, response: Value) -> Result<Vec<WaveItem>> {
        let response: SessionResponse = serde_json::from_value(unwrap_result(response)?)
            .map_err(|error| ApiError::Response(error.to_string()))?;
        if let Some(session_id) = response.radio_session_id {
            self.session_id = session_id;
        }
        if let Some(batch_id) = response.batch_id {
            self.batch_id = batch_id;
        }
        if let Some(feedback_from) = response.wave.and_then(|wave| wave.id_for_from) {
            self.feedback_from = feedback_from;
        }

        let mut items = Vec::new();
        for sequence_item in response.sequence {
            let Some(track) = sequence_item.track else {
                continue;
            };
            let track_id = track.track_id();
            if self.seen.contains(&track_id) {
                continue;
            }
            self.remember_seen(track_id);
            items.push(WaveItem {
                track,
                batch_id: self.batch_id.clone(),
                liked: sequence_item.liked,
            });
        }
        Ok(items)
    }

    fn feedback(
        &self,
        item: &WaveItem,
        kind: &str,
        timestamp: &str,
        played_seconds: Option<f64>,
        track_length: Option<f64>,
    ) -> Result<Value> {
        serde_json::to_value(Feedback {
            from: &self.feedback_from,
            batch_id: &item.batch_id,
            event: FeedbackEvent {
                kind,
                timestamp,
                track_id: item.track.track_id(),
                total_played_seconds: played_seconds,
                track_length_seconds: track_length,
            },
        })
        .map_err(|error| ApiError::Response(error.to_string()))
    }

    fn remember_history(&mut self, track_id: String) {
        if self.history.back() == Some(&track_id) {
            return;
        }
        if self.history_limit == 0 {
            return;
        }
        if self.history.len() == self.history_limit {
            self.history.pop_front();
        }
        self.history.push_back(track_id);
    }

    fn remember_seen(&mut self, track_id: String) {
        if self.seen_limit == 0 || !self.seen.insert(track_id.clone()) {
            return;
        }
        self.seen_order.push_back(track_id);
        while self.seen_order.len() > self.seen_limit {
            if let Some(expired) = self.seen_order.pop_front() {
                self.seen.remove(&expired);
            }
        }
    }

    fn api(&self) -> Result<&YandexApi> {
        self.api
            .as_deref()
            .ok_or_else(|| ApiError::Configuration("WaveSession has no API transport".into()))
    }
}

fn timestamp() -> String {
    Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(id: &str) -> WaveItem {
        WaveItem {
            track: serde_json::from_value(json!({"id": id, "albums": [{"id": "9"}]})).unwrap(),
            batch_id: "batch-fixture".into(),
            liked: false,
        }
    }

    #[test]
    fn history_is_bounded_and_ignores_adjacent_duplicates() {
        let mut session = WaveSession::without_api(2, 3);
        session.remember_history("1".into());
        session.remember_history("1".into());
        session.remember_history("2".into());
        session.remember_history("3".into());
        assert_eq!(
            session.history.iter().cloned().collect::<Vec<_>>(),
            ["2", "3"]
        );
    }

    #[test]
    fn feedback_has_exact_reference_fields() {
        let mut session = WaveSession::without_api(20, 300);
        session.feedback_from = "fixture-from".into();
        let feedback = session
            .feedback(
                &item("42"),
                "skip",
                "2026-08-23T12:34:56.789Z",
                Some(1.25),
                Some(180.0),
            )
            .unwrap();
        let expected: Value =
            serde_json::from_str(include_str!("../tests/fixtures/feedback.json")).unwrap();
        assert_eq!(feedback, expected);
    }

    #[test]
    fn seen_window_expires_old_ids() {
        let mut session = WaveSession::without_api(20, 2);
        session.remember_seen("1".into());
        session.remember_seen("2".into());
        session.remember_seen("3".into());
        assert!(!session.seen.contains("1"));
        assert!(session.seen.contains("2"));
        assert!(session.seen.contains("3"));
    }
}
