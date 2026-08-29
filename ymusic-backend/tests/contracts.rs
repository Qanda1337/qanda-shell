use qanda_ymusic::api::unwrap_result;
use qanda_ymusic::model::{Track, TrackData};
use qanda_ymusic::wave::WaveSession;

#[test]
fn unwraps_result_envelopes() {
    let fixture = include_str!("fixtures/envelope.json");
    let value: serde_json::Value = serde_json::from_str(fixture).unwrap();
    let tracks: Vec<Track> = serde_json::from_value(unwrap_result(value).unwrap()).unwrap();
    assert_eq!(tracks[0].id, "123");
}

#[test]
fn creates_compound_ids_cover_urls_and_player_data() {
    let track: Track = serde_json::from_str(include_str!("fixtures/track.json")).unwrap();
    assert_eq!(track.track_id(), "123:456");
    assert_eq!(
        track.cover_url("400x400").as_deref(),
        Some("https://avatars.yandex.net/get-music-content/fixture/400x400")
    );

    let data = TrackData::from_track(&track, true, false);
    assert_eq!(data.artist, "First Artist, Second Artist");
    assert_eq!(data.duration, 215.5);
    assert_eq!(
        serde_json::to_value(data).unwrap()["artUrl"],
        track.cover_url("400x400").unwrap()
    );
}

#[test]
fn wave_deduplicates_fixture_tracks() {
    let mut session = WaveSession::without_api(20, 300);
    let response = serde_json::from_str(include_str!("fixtures/wave.json")).unwrap();
    let items = session.apply_response(response).unwrap();
    assert_eq!(items.len(), 2);
    assert_eq!(items[0].track.track_id(), "1:10");
    assert!(items[0].liked);
    assert_eq!(session.session_id(), Some("session-fixture"));
}
