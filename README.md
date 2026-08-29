# qanda-shell

A Quickshell desktop shell for Arch Linux, Hyprland, and Wayland.

It provides a top bar, launcher, notification center, clipboard history,
media and audio controls, system monitoring, quick settings, weather,
read-only wallet widgets, wallpaper selection, and an optional Yandex Music
backend.

## Requirements

The supported environment is Arch Linux with Hyprland. Install the core
runtime and build dependencies:

```bash
sudo pacman -S --needed \
  quickshell hyprland jq curl rust base-devel \
  networkmanager pipewire pipewire-audio wireplumber \
  procps-ng psmisc iproute2 \
  adwaita-fonts ttf-adwaitamono-nerd
```

The Rust toolchain is required because qanda-shell builds its system backend
from source. Quickshell provides the required Qt 6, Wayland, and PipeWire
libraries.

## Installation

Clone the repository to the Quickshell configuration directory:

```bash
mkdir -p ~/.config/quickshell
git clone https://github.com/Qanda1337/qanda-shell.git \
  ~/.config/quickshell/qanda-shell
```

Build the system backend once before the first start:

```bash
cargo build --locked --release \
  --manifest-path ~/.config/quickshell/qanda-shell/backend/Cargo.toml
```

Start the shell:

```bash
qs -c qanda-shell
```

The bundled `scripts/system-backend` launcher automatically rebuilds the
backend when its Rust sources or lockfile change.

## Hyprland Startup

Add the following lines to `~/.config/hypr/hyprland.conf`:

```ini
exec-once = qs -c qanda-shell
exec-once = ~/.config/quickshell/qanda-shell/scripts/power-key-inhibitor
```

The power-key inhibitor is optional. It prevents logind from handling the
power key before a Hyprland binding can open the shell power menu.

Shell modules can be controlled through IPC. For example:

```bash
qs -c qanda-shell ipc call launcher toggle
qs -c qanda-shell ipc call settings toggle
qs -c qanda-shell ipc call bar toggle
```

Bind these commands through Hyprland using the key combinations you prefer.

## Optional Dependencies

Install only the packages needed by the features you use.

| Feature | Arch packages |
| --- | --- |
| Launcher file search and calculator | `fd`, `libqalculate`, `xdg-utils`, `kitty` |
| Clipboard history | `cliphist`, `wl-clipboard` |
| Audio tools and notification sounds | `pavucontrol`, `libnotify`, `sound-theme-freedesktop` |
| Bluetooth | `bluez`, `bluez-utils` |
| Laptop brightness | `brightnessctl` |
| External monitor brightness | `ddcutil` |
| Night light | `hyprsunset` or `wlsunset` |
| Power profiles | `power-profiles-daemon`, `python-gobject` |
| Docker panel | `docker` |
| NVIDIA metrics | `nvidia-utils` |
| Yandex Music playback | `mpv` |
| Wallpaper and generated themes | `waypaper`, `swaybg`, `matugen`, `imagemagick`, `glib2` |

Most packages are available from the official Arch repositories. `waypaper`
is available from the AUR, for example:

```bash
paru -S waypaper
```

Enable the services used by installed features:

```bash
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now power-profiles-daemon.service
sudo systemctl enable --now docker.service
```

Only enable services whose packages you installed.

### Clipboard Capture

The shell displays `cliphist` data but does not start clipboard watchers.
Add these commands to Hyprland startup if you want text and image history:

```ini
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
```

### Wallpaper And Theme Integration

The wallpaper picker expects Waypaper configuration at
`~/.config/waypaper/config.ini`. Theme controls additionally expect an
external executable at `~/.config/theme/apply.sh`. That personal theme
pipeline is not bundled, so preset application and Matugen integration must
be adapted to your own setup.

### VPN Integration

The VPN button expects an executable helper at `~/.local/bin/vpn-toggle.sh`.
The helper is not bundled because VPN connection names and credentials are
machine-specific. Network status itself works through NetworkManager without
this helper.

## Personal Configuration

Open Control Center and select **Data** to configure:

- weather city, latitude, longitude, and IANA timezone;
- public Tron and Hyperliquid wallet addresses.

These values are stored locally in:

```text
${XDG_STATE_HOME:-~/.local/state}/qanda-shell/settings.json
```

The settings file is created with owner-only permissions and is not part of
the repository. Wallet integration only reads public blockchain APIs. Never
put private keys, seed phrases, passwords, or API tokens in this file.

For Russian weekday names in the weather forecast, enable `ru_RU.UTF-8` in
`/etc/locale.gen` and regenerate locales.

## Yandex Music Backend

Build the optional backend:

```bash
cargo build --locked --release \
  --manifest-path ~/.config/quickshell/qanda-shell/ymusic-backend/Cargo.toml
```

It reads an OAuth token from `~/.local/share/qanda-ymusic/token`. Keep this
file private:

```bash
chmod 600 ~/.local/share/qanda-ymusic/token
```

The repository does not include an OAuth acquisition helper or a systemd
unit. After obtaining a token, create
`~/.config/systemd/user/qanda-ymusic.service`:

```ini
[Unit]
Description=qanda-shell Yandex Music backend
After=graphical-session.target

[Service]
ExecStart=%h/.config/quickshell/qanda-shell/ymusic-backend/target/release/qanda-ymusic
Restart=on-failure

[Install]
WantedBy=default.target
```

Then enable it:

```bash
systemctl --user daemon-reload
systemctl --user enable --now qanda-ymusic.service
```

## Development

Run the baseline checks before committing:

```bash
git diff --check
bash -n scripts/*
cargo test --locked --manifest-path backend/Cargo.toml
cargo test --locked --manifest-path ymusic-backend/Cargo.toml
```

Cargo build output, local agent artifacts, internal plans, and personal
runtime settings are excluded from Git.

## License

qanda-shell is available under the [MIT License](LICENSE).
