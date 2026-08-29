# qanda-shell Architecture

Use this reference when changing ownership, windows, masks, services, widgets, settings, or immersive behavior.

## Runtime Topology

`shell.qml` creates one `ShellRoot` and one instance of every service. It then creates three per-screen Variants:

1. Normal `TopBar`
2. Immersive `TopBar`
3. `BarExclusionZone`

Services and their `isOpen` state are global. Windows are per screen. A global state change can therefore affect every monitor, and multiple windows can request focus if focus policy is broadened.

Both TopBars exist continuously. `ImmersiveService.enabled` selects which presentation is active; windows are not recreated through a Loader.

## Window Responsibilities

### `components/TopBar.qml`

- `PanelWindow`, anchored top/left/right
- `implicitHeight: 560` to contain expanded panels plus attached visual overflow
- transparent window background
- input restricted by `mask: Region`
- normal namespace/layer: `qanda-shell-bar`, `WlrLayer.Top`
- immersive namespace/layer: `qanda-shell-immersive`, `WlrLayer.Overlay`
- `ExclusionMode.Ignore`
- keyboard focus is exclusive only while an active presentation has an open widget

The mask combines the bar, center island, and settings islands. Transparent pixels outside the mask must remain click-through.

### `components/BarExclusionZone.qml`

- transparent inputless reservation surface
- namespace `qanda-shell-exclusion`
- normal mode reserves `Theme.barHeight` (42 px)
- immersive mode reserves nothing

The visual and reservation surfaces are intentionally separate. Merging them would reserve the TopBar's full 560 px window or require a larger redesign.

### `components/TrayMenuPopup.qml`

Independent `PopupWindow` anchored to a tray item. It owns menu navigation and close timing and does not participate in shell-wide widget exclusion.

## Main Component Tree

`TopBar` owns:

- `LeftSettingsIsland` and `ControlCenterPanel`
- `LeftCluster`
- `CenterIsland`
- `RightCluster` and tray popups

`CenterIsland` owns compact content, toast content, and the main panels:

- launcher
- clipboard
- bindings
- Docker
- notifications
- timer
- calendar
- generic and Yandex media
- audio
- power
- performance
- wallet
- wallpaper
- weather

`CenterIsland` contains a manual width/height decision table. Panels with dynamic height expose `preferredHeight`; a panel geometry change may require changing this table and the TopBar mask.

`LeftSettingsIsland` has a second extent beyond its content box. `visualOverflowRight` and `visualOverflowBottom` allow the shared outer Shape to continue past rectangular Settings content and form concave/convex transitions. TopBar remains 560 px tall so expanded content and visual overflow are not clipped.

## Service Ownership

Services live in `services/` and are instantiated once by `shell.qml`.

- `SystemService`: Rust backend lifecycle/socket, common metrics, network/VPN, recording/camera, layout, weather projection, and theme/accent events
- `NotificationService`: notification server, current toast, in-memory history, DND
- `LauncherService`: application/file/action/command/calculator search
- `ClipboardService`: cliphist integration
- `BindingsService`: displayed shortcut map
- `DockerService`: container list/actions
- `TimerService`: countdown state machine
- `CalendarService`: calendar selection/navigation
- `MediaService`: Yandex backend plus generic mode state
- `WeatherService`: panel visibility; data comes from `SystemService`
- `AudioService`: panel visibility plus the shared PipeWire sink/source model, volume, mute, and default-device actions
- `PowerService`: session/power actions
- `PerformanceService`: expanded metrics projected from the shared Rust backend, with script fallback
- `WalletService`: wallet data
- `WallpaperService`: wallpaper discovery/apply
- `SettingsService`: control center section/profile state, capability snapshots, fixed system actions, and maintenance actions
- `ImmersiveService`: global enabled flag and `bar` IPC

Most panel services expose `isOpen`, `open()`, `close()`, `toggle()`, and an `IpcHandler`.

## Mutual Exclusion

Widget exclusion is intentionally defensive but duplicated:

- `shell.qml` Connections close other services when one opens.
- `TopBar.anyWidgetOpen` and `closeAllWidgets()` repeat the registry.
- `CenterIsland` priority expressions prevent conflicting panels from rendering during transient inconsistent state.

There is no centralized registry. Search all names when adding or renaming a module.

## Appearance

The shell has one liquid appearance with edge-attached surfaces and concave transitions. Normal and immersive presentations share this geometry; immersive changes compositor layer, reservation, and cluster visibility rather than selecting another appearance mode.

## Control Center

`components/ControlCenterPanel.qml` owns the eight-section UI: profiles, audio, connections, display, shell, performance, privacy, and maintenance. `SettingsService` orchestrates it; live PipeWire data remains owned by `AudioService`, while `scripts/control-center` is the validated boundary for capability/status JSON and fixed host actions.

Unavailable host capabilities must be rendered as unavailable rather than as optimistic switches. System polling runs only while the Control Center is open. Profiles may coordinate several services, but the `game` profile must never read or modify `ImmersiveService`; immersive mode remains an explicit user choice.

## Immersive Flow

Immersive mode is a manual global IPC toggle, not automatic fullscreen detection:

1. External binding calls the `bar` IPC target.
2. `ImmersiveService.enabled` flips.
3. Normal TopBar deactivates; overlay TopBar activates.
4. Exclusion changes from 42 px to none.
5. Left/right clusters are concealed; center remains.

Do not describe this as per-window, per-workspace, or automatic fullscreen state.

## Configuration And Persistence

`config/Theme.qml` owns palette, typography, dimensions, and common motion durations. `accent` is mutable. Components conventionally import `../config` as `Config`.

`config/Preferences.qml` loads and debounces saves through `scripts/settings`. Persistent data is stored under `${XDG_STATE_HOME:-~/.local/state}/qanda-shell/settings.json` using atomic JSON writes. The script merges validated stored values with defaults for `activeProfile`, animation enable/speed, effect flags, notification duration, theme settings, and left/right cluster visibility. `Theme.motionFast` and `Theme.motionNormal` are the global animation-speed boundary; avoid hard-coded UI animation durations.

Other scripts may write cache/runtime state or invoke external tools. Do not run them casually as validation.

## High-Risk Coupling

- global services versus per-screen focus/windows
- duplicated widget registry and close lists
- 560 px visual window versus narrow input mask
- manual CenterIsland size table
- split weather ownership
- external dependencies and hard-coded user paths
- repeated polling processes
- destructive Docker/power/wallpaper/theme actions
- arbitrary command execution intentionally supported by launcher command mode
