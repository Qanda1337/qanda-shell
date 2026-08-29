# qanda-shell

A personal Quickshell desktop shell for Wayland/Hyprland.

## Configuration

Open Control Center and select **Data** to configure weather and read-only wallet widgets. The following values are stored locally in
`${XDG_STATE_HOME:-~/.local/state}/qanda-shell/settings.json` and are not part of this repository:

- weather city, latitude, longitude, and IANA timezone;
- public Tron and Hyperliquid wallet addresses.

Wallet integration only reads public blockchain data. Never put private keys, seed phrases, passwords, or API tokens in the settings file.

The Yandex Music backend reads its OAuth token from `~/.local/share/qanda-ymusic/token`. Keep that file private with mode `0600`; it must not be committed.

## Development

Run the baseline static checks before committing:

```bash
git diff --check
bash -n scripts/*
cargo test --manifest-path backend/Cargo.toml
cargo test --manifest-path ymusic-backend/Cargo.toml
```

Cargo build output, local agent artifacts, and personal runtime settings are excluded from Git.
