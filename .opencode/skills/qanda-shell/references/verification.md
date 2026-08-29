# Verification

Use the least invasive checks that establish the behavior changed.

## Baseline Checks

Always inspect the dirty worktree without reverting unrelated changes:

```bash
git status --short
git diff --check
git diff -- <touched paths>
```

When scripts change:

```bash
bash -n scripts/<script>
```

For broad script-only changes, validate each touched script rather than executing it.

## QML Tooling In This Environment

- Quickshell version: `0.3.0` (Arch Linux package)
- `qmllint`: unavailable
- `qmlformat`: unavailable
- Quickshell has no parse-only CLI mode

Check availability rather than assuming:

```bash
qs --version
command -v qmllint
command -v qmlformat
```

## Runtime Load Check

This command validates actual configuration loading:

```bash
timeout 4s quickshell -p . --no-color
```

It is not a harmless parser. It creates a second shell instance, windows, pollers, IPC handlers, and service registration attempts. Expected duplicate-instance warnings can include notification server registration. Use it only when runtime validation is worth those side effects, keep the timeout short, and report that it was a runtime launch.

`QT_QPA_PLATFORM=offscreen` is not an adequate substitute because `PanelWindow` has no layer-shell backend there and loading fails before useful validation.

Inspect running instances with:

```bash
quickshell list --all
```

Do not kill the user's persistent instance as part of verification.

## Exact-State Visual Check

When a visual state is reachable through IPC, launch a temporary instance and address it by PID. Do not use `--newest`: overlapping startup or shutdown can make it operate on the persistent shell or a different temporary instance.

```bash
quickshell -p . --no-color > /tmp/opencode/qanda-test.log 2>&1 &
test_pid=$!
sleep 2
quickshell ipc --pid "$test_pid" call settings open
sleep 2
grim /tmp/opencode/qanda-test.png
kill "$test_pid"
wait "$test_pid" 2>/dev/null || true
```

Adapt the IPC target to the state under test. Verify the saved image directly, then run `quickshell list --all` to ensure only the persistent shell remains. This check briefly displays a duplicate shell and must not invoke destructive IPC methods.

## Visual Matrix

For layout/rendering changes, syntax and configuration loading are insufficient. Check or explicitly request confirmation for:

| State | Required coverage |
|---|---|
| Appearance | liquid |
| Presentation | normal, immersive |
| Size | compact, expanded panel, toast if relevant |
| Window context | desktop/wallpaper, maximized, fullscreen contrasting content |
| Input | inside controls, transparent outside area, animated edges |
| Focus | opening, Escape/close, no unintended focus stealing |
| Display | target monitor; fractional DPR/multi-monitor when geometry is DPR-sensitive |

For attached popouts, add a geometry audit: compare `item.y + item.height + visualOverflowBottom` against the containing window height. A screenshot cropped exactly at the window boundary is evidence of parent clipping, not necessarily a bad curve.

Do not state that a visual defect is fixed when only `Configuration Loaded` was observed.

## Safe Diagnostics

Useful read-only checks:

```bash
hyprctl monitors -j
quickshell list --all
git log --oneline -10
```

Check dependencies with `command -v`; do not invoke destructive or stateful backends.

## Commands Not Suitable As Generic Tests

Avoid running these merely to prove code quality:

- `scripts/restart`
- power/session actions
- Docker remove/actions
- wallpaper or theme apply
- wallet/weather/network calls
- `scripts/sync-greeter-wallpaper`
- long-lived inhibitors
- IPC methods that mutate user state

Some read commands still create cache/state directories. Inspect their implementation before running them.

## Completion Report

State separately:

- files and behavior changed
- static checks run
- runtime checks run and expected warnings
- visual states actually observed
- remaining visual/manual verification

This distinction prevents a successful parser/load check from being mistaken for proof of rendering quality.
