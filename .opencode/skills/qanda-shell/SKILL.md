---
name: qanda-shell
description: Work safely and idiomatically on the qanda-shell Quickshell/QML desktop shell. Use this skill whenever a task touches shell.qml, components/*.qml, services/*.qml, config/*.qml, scripts/*, PanelWindow, WlrLayershell, widgets, appearance modes, immersive/fullscreen behavior, QML rendering, Shapes, masks, effects, animations, or Quickshell IPC in this repository, even when the user does not explicitly mention Quickshell.
compatibility: Quickshell 0.3.0, Qt 6, Wayland/Hyprland, OpenCode project skills
---

# qanda-shell

Treat this repository as a stateful desktop shell, not as an ordinary isolated QML application. A small visual edit can affect input regions, compositor layers, exclusion zones, focus, and every screen.

## Start With Context

1. Read the complete target component and its parent before editing.
2. Trace every service/property supplied by `shell.qml`; services are global while windows are created per screen.
3. Identify all affected presentations:
   - normal liquid bar
   - immersive/fullscreen overlay
   - compact and expanded states
4. Check the worktree and preserve unrelated user changes. This repository may intentionally be dirty.
5. Read [references/architecture.md](references/architecture.md) for changes involving windows, services, widget registration, persistence, appearance modes, or immersive behavior.
6. Read [references/rendering.md](references/rendering.md) before changing Shapes, rounded/concave geometry, transparency, shadows, masks, layers, blur, or animations.
7. Read [references/verification.md](references/verification.md) before running the shell or external scripts.

## Implementation Rules

- Make the smallest coherent change and preserve the established visual language.
- Keep persistent or shared state in a service/config singleton, not in a per-screen visual delegate.
- Pass external services through existing `required property var` wiring unless a typed reusable API already exists.
- Use `Config.Theme` for palette, typography, dimensions, and motion where an appropriate token exists.
- Keep the visual shape, `PanelWindow.mask`, shadow source, and exclusion behavior conceptually separate. Updating one does not update the others.
- Before changing a popout size or offset, calculate its full visual extent: `item.y + item.height + visualOverflowBottom` plus intentional effect padding. The containing `PanelWindow` must cover it or valid curves and shadows will be hard-clipped.
- Preserve click-through: `TopBar` is 560 px tall and safe only because its `Region` mask is narrow and explicit.
- Preserve the split between visual `TopBar` windows and `BarExclusionZone`. Do not reserve the full visual window.
- Treat `WlrLayer.Overlay` and exclusive keyboard focus as exceptional. Do not broaden either without a concrete interaction requirement.
- Use argv arrays with `Process`; avoid `sh -c` for values containing user or service data.
- Coalesce process refreshes and handle stderr/non-zero exits. Do not start duplicate pollers in per-screen components.
- Do not add compatibility branches without an actual persisted-data or external-consumer requirement.

## Widget Changes

Adding, removing, or renaming a widget is cross-cutting. Search for and update every relevant registry instead of fixing only the visible component:

- service instance and exported alias in `shell.qml`
- per-screen `TopBar` property wiring in both Variants
- mutual-exclusion `Connections` in `shell.qml`
- `TopBar.required` properties
- `TopBar.anyWidgetOpen`
- `TopBar.closeAllWidgets()`
- `CenterIsland.required` properties
- panel priority/open expressions
- `CenterIsland` width/height selection
- `TopBar.mask` if geometry changes
- launcher/module actions and IPC target, when applicable

Keep temporary inconsistent `isOpen` states visually harmless by retaining the existing panel-priority guards.

## Visual And Rendering Changes

- Do not guess at rendering fixes. Check Qt documentation and at least one established Quickshell implementation when changing unusual geometry or compositor behavior.
- Prefer one continuous `Shape`/`ShapePath` for a continuous surface.
- When another presentation already renders the desired geometry correctly, reuse that Shape and vary only offsets, colors, or strokes. Do not create a parallel renderer until reuse is proven impossible.
- Prefer `Shape.CurveRenderer` for scalable curved paths and use quadratic curves or true arcs when they model the intended geometry.
- Separate fill and outline paths when a stroke changes edge quality or alpha composition.
- Do not add `layer.enabled`, MSAA, Canvas supersampling, or `MultiEffect` merely as an antialiasing flag. Each creates a real render pass or texture and can alter alpha composition.
- Keep panel materials opaque unless transparency is explicitly requested. Window transparency and panel material opacity are different decisions.
- Do not let rectangular content end at the same edge as an attached rounded shell. Follow the Settings pattern: content ends first, while the outer Shape continues through `visualOverflowBottom` to form the visible silhouette.
- Avoid changing path geometry every frame unless measured. Prefer animating scalar item properties, transforms, and opacity.
- For popout open/close motion, prefer one normalized progress value with overlapping smoothstep ranges. Do not model a visually continuous handoff as sequential animations with a hard midpoint.
- When timing is within budget but motion still looks jerky, investigate visibility, overflow, mask, clipping, and neighboring-module state discontinuities before attempting rendering optimizations.
- Check actual geometry at integer and fractional coordinates; avoid zero-radius/degenerate path segments.

## Verification Discipline

Use the risk-based matrix in [references/verification.md](references/verification.md). At minimum:

1. Run `git diff --check`.
2. Inspect the exact diff and distinguish your edits from pre-existing changes.
3. Validate shell scripts with `bash -n` when touched.
4. Validate QML with available tooling. `qmllint` is currently absent; a runtime launch is not a harmless parser and must be treated accordingly.
5. For visual changes, explicitly account for normal and immersive presentations. Do not claim visual success based only on syntax/load success.
6. For stateful screenshots, target the temporary Quickshell instance by PID; `--newest` can select the wrong instance when launches overlap.
7. Report what was actually verified and what still requires visual confirmation.

## External References

Prefer primary documentation and established implementations:

- Quickshell 0.3.0 docs: <https://quickshell.org/docs/v0.3.0/>
- Qt Quick Shapes: <https://doc.qt.io/qt-6/qml-qtquick-shapes-shape.html>
- Qt Quick performance: <https://doc.qt.io/qt-6/qtquick-performance.html>
- Caelestia Shell: <https://github.com/caelestia-dots/shell>
- DankMaterialShell: <https://github.com/AvengeMedia/DankMaterialShell>
- Noctalia legacy QML: <https://github.com/noctalia-dev/noctalia/tree/legacy-v4>
- end-4 dots-hyprland: <https://github.com/end-4/dots-hyprland>
- asteriau NotchShape: <https://github.com/asteriau/dotfiles/blob/50405e1789f394243b118700256b1d0373f646ce/home/services/quickshell/modules/island/shapes/NotchShape.qml>

Use project code and current Qt/Quickshell documentation as the source of truth. Borrow principles from other shells, not their architecture wholesale.
