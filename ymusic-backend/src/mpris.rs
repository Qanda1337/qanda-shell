use std::collections::HashMap;
use std::sync::Arc;

use tokio::sync::watch;
use zbus::fdo;
use zbus::object_server::SignalEmitter;
use zbus::zvariant::{ObjectPath, OwnedValue, Str, Value};
use zbus::{Connection, interface};

use crate::player::{Player, Status};

const PATH: &str = "/org/mpris/MediaPlayer2";
const PLAYER_INTERFACE: &str = "org.mpris.MediaPlayer2.Player";

struct MprisRoot;

#[interface(name = "org.mpris.MediaPlayer2")]
impl MprisRoot {
    fn raise(&self) {}
    fn quit(&self) {}
    #[zbus(property)]
    fn can_quit(&self) -> bool {
        false
    }
    #[zbus(property)]
    fn can_raise(&self) -> bool {
        false
    }
    #[zbus(property)]
    fn has_track_list(&self) -> bool {
        false
    }
    #[zbus(property)]
    fn identity(&self) -> &str {
        "Qanda Yandex Music"
    }
    #[zbus(property)]
    fn desktop_entry(&self) -> &str {
        ""
    }
    #[zbus(property)]
    fn supported_uri_schemes(&self) -> Vec<String> {
        Vec::new()
    }
    #[zbus(property)]
    fn supported_mime_types(&self) -> Vec<String> {
        Vec::new()
    }
}

struct MprisPlayer {
    player: Arc<Player>,
}

fn dbus_error(error: String) -> fdo::Error {
    fdo::Error::Failed(error)
}

#[interface(name = "org.mpris.MediaPlayer2.Player")]
impl MprisPlayer {
    async fn next(&self) -> fdo::Result<()> {
        self.player
            .next(false)
            .await
            .map(|_| ())
            .map_err(dbus_error)
    }
    async fn previous(&self) -> fdo::Result<()> {
        self.player.previous().await.map(|_| ()).map_err(dbus_error)
    }
    async fn pause(&self) -> fdo::Result<()> {
        self.player.pause().await.map(|_| ()).map_err(dbus_error)
    }
    async fn play_pause(&self) -> fdo::Result<()> {
        self.player
            .play_pause()
            .await
            .map(|_| ())
            .map_err(dbus_error)
    }
    async fn stop(&self) -> fdo::Result<()> {
        self.player.stop().await.map(|_| ()).map_err(dbus_error)
    }
    async fn play(&self) -> fdo::Result<()> {
        self.player.play().await.map(|_| ()).map_err(dbus_error)
    }
    async fn seek(
        &self,
        offset: i64,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> fdo::Result<()> {
        let status = self.player.status().await;
        let position = (status.position + offset as f64 / 1_000_000.0).max(0.0);
        self.player.seek(position).await.map_err(dbus_error)?;
        Self::seeked(&emitter, (position * 1_000_000.0) as i64)
            .await
            .map_err(|error| dbus_error(error.to_string()))
    }
    async fn set_position(
        &self,
        track_id: ObjectPath<'_>,
        position: i64,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> fdo::Result<()> {
        let status = self.player.status().await;
        let Some(position) = set_position_target(
            status.current.as_ref().map(|track| track.id.as_str()),
            track_id.as_str(),
            position,
        ) else {
            return Ok(());
        };
        self.player
            .seek(position as f64 / 1_000_000.0)
            .await
            .map_err(dbus_error)?;
        Self::seeked(&emitter, position)
            .await
            .map_err(|error| dbus_error(error.to_string()))
    }
    async fn open_uri(&self, _uri: &str) {}

    #[zbus(property)]
    async fn playback_status(&self) -> String {
        capitalize(&self.player.status().await.playback)
    }
    #[zbus(property)]
    fn loop_status(&self) -> &str {
        "None"
    }
    #[zbus(property)]
    fn set_loop_status(&self, _value: &str) {}
    #[zbus(property)]
    fn rate(&self) -> f64 {
        1.0
    }
    #[zbus(property)]
    fn set_rate(&self, _value: f64) {}
    #[zbus(property)]
    fn shuffle(&self) -> bool {
        false
    }
    #[zbus(property)]
    fn set_shuffle(&self, _value: bool) {}
    #[zbus(property)]
    async fn metadata(&self) -> HashMap<String, OwnedValue> {
        metadata(&self.player.status().await)
    }
    #[zbus(property)]
    async fn volume(&self) -> f64 {
        self.player.status().await.volume / 100.0
    }
    #[zbus(property)]
    async fn set_volume(&self, value: f64) -> fdo::Result<()> {
        self.player
            .set_volume(value * 100.0)
            .await
            .map(|_| ())
            .map_err(dbus_error)
    }
    #[zbus(property)]
    async fn position(&self) -> i64 {
        (self.player.status().await.position * 1_000_000.0) as i64
    }
    #[zbus(property)]
    fn minimum_rate(&self) -> f64 {
        1.0
    }
    #[zbus(property)]
    fn maximum_rate(&self) -> f64 {
        1.0
    }
    #[zbus(property)]
    async fn can_go_next(&self) -> bool {
        self.player.status().await.queue_length > 1
    }
    #[zbus(property)]
    async fn can_go_previous(&self) -> bool {
        self.player.status().await.queue_length > 0
    }
    #[zbus(property)]
    async fn can_play(&self) -> bool {
        self.player.status().await.current.is_some()
    }
    #[zbus(property)]
    async fn can_pause(&self) -> bool {
        self.player.status().await.current.is_some()
    }
    #[zbus(property)]
    async fn can_seek(&self) -> bool {
        self.player.status().await.current.is_some()
    }
    #[zbus(property)]
    fn can_control(&self) -> bool {
        true
    }

    #[zbus(signal)]
    async fn seeked(emitter: &SignalEmitter<'_>, position: i64) -> zbus::Result<()>;
}

pub async fn run(player: Arc<Player>, mut shutdown: watch::Receiver<bool>) -> zbus::Result<()> {
    let connection = zbus::connection::Builder::session()?
        .name("org.mpris.MediaPlayer2.qanda_ymusic")?
        .serve_at(PATH, MprisRoot)?
        .serve_at(
            PATH,
            MprisPlayer {
                player: player.clone(),
            },
        )?
        .build()
        .await?;
    let mut statuses = player.subscribe();
    loop {
        tokio::select! {
            status = statuses.recv() => if let Ok(status) = status { emit_properties(&connection, &status).await?; },
            changed = shutdown.changed() => if changed.is_err() || *shutdown.borrow() { break; },
        }
    }
    Ok(())
}

async fn emit_properties(connection: &Connection, status: &Status) -> zbus::Result<()> {
    let mut changed = HashMap::<String, OwnedValue>::new();
    changed.insert(
        "PlaybackStatus".into(),
        OwnedValue::from(Str::from(capitalize(&status.playback))),
    );
    changed.insert(
        "Metadata".into(),
        OwnedValue::try_from(Value::from(metadata(status)))?,
    );
    changed.insert("Volume".into(), OwnedValue::from(status.volume / 100.0));
    changed.insert(
        "CanGoNext".into(),
        OwnedValue::from(status.queue_length > 1),
    );
    changed.insert(
        "CanGoPrevious".into(),
        OwnedValue::from(status.queue_length > 0),
    );
    let has_track = status.current.is_some();
    for name in ["CanPlay", "CanPause", "CanSeek"] {
        changed.insert(name.into(), OwnedValue::from(has_track));
    }
    connection
        .emit_signal(
            None::<&str>,
            PATH,
            "org.freedesktop.DBus.Properties",
            "PropertiesChanged",
            &(PLAYER_INTERFACE, changed, Vec::<String>::new()),
        )
        .await
}

fn metadata(status: &Status) -> HashMap<String, OwnedValue> {
    let Some(track) = &status.current else {
        return HashMap::new();
    };
    let mut result = HashMap::new();
    let path = track_object_path(&track.id);
    if let Ok(path) = ObjectPath::try_from(path) {
        result.insert("mpris:trackid".into(), OwnedValue::from(path));
    }
    result.insert(
        "mpris:length".into(),
        OwnedValue::from((track.duration * 1_000_000.0) as i64),
    );
    result.insert(
        "xesam:title".into(),
        OwnedValue::from(Str::from(track.title.clone())),
    );
    if let Ok(value) = OwnedValue::try_from(Value::from(vec![track.artist.clone()])) {
        result.insert("xesam:artist".into(), value);
    }
    result.insert(
        "xesam:album".into(),
        OwnedValue::from(Str::from(track.album.clone())),
    );
    if !track.art_url.is_empty() {
        result.insert(
            "mpris:artUrl".into(),
            OwnedValue::from(Str::from(track.art_url.clone())),
        );
    }
    result
}

fn track_object_path(track_id: &str) -> String {
    format!("{PATH}/track/{}", track_id.replace(':', "_"))
}

fn set_position_target(
    current_id: Option<&str>,
    supplied_path: &str,
    position: i64,
) -> Option<i64> {
    let current_id = current_id?;
    (supplied_path == track_object_path(current_id)).then_some(position.max(0))
}

fn capitalize(value: &str) -> String {
    let mut chars = value.chars();
    chars.next().map_or_else(String::new, |first| {
        first.to_uppercase().collect::<String>() + chars.as_str()
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn set_position_ignores_stale_track_ids() {
        assert_eq!(
            set_position_target(
                Some("current:album"),
                "/org/mpris/MediaPlayer2/track/stale_album",
                2_000_000,
            ),
            None
        );
        assert_eq!(
            set_position_target(None, "/org/mpris/MediaPlayer2/track/current_album", 1),
            None
        );
    }

    #[test]
    fn set_position_accepts_current_track_and_clamps_negative_position() {
        let path = track_object_path("current:album");
        assert_eq!(
            set_position_target(Some("current:album"), &path, 2_000_000),
            Some(2_000_000)
        );
        assert_eq!(
            set_position_target(Some("current:album"), &path, -500_000),
            Some(0)
        );
    }
}
