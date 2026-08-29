# System backend

Build with `cargo build --release` or run `scripts/system-backend`. The daemon listens on
`$XDG_RUNTIME_DIR/qanda-shell-system.sock` (with a per-user `/tmp` fallback) and emits one
newline-delimited JSON snapshot immediately and approximately every two seconds.

Commands are NDJSON objects with an integer `id`: `refresh`, `set_wifi` with boolean
`params.enabled`, and `set_power_profile` with `params.profile`. Every command receives an
`{"id":N,"ok":true}` response or an error response.
