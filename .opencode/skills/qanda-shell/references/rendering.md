# Rendering And UI Practices

Use this reference before changing Shapes, corners, transparency, effects, masks, or animation behavior.

## Continuous Surfaces

Represent one visual surface with one continuous contour. Composing several overlapping Rectangles or Shapes can create seams, doubled alpha, and mismatched antialiasing on fractional coordinates.

Before implementing a new contour, compare the normal and immersive presentations. Reuse the liquid Shape with presentation-specific offsets when possible; parallel geometry drifts and is harder to validate.

For curved QML paths:

- request `Shape.CurveRenderer`
- prefer `PathQuad`, `PathArc`, or SVG `Q`/`A` when they directly model the curve
- remember that CurveRenderer approximates cubic curves with quadratics
- avoid degenerate zero-radius arc/path segments
- constrain radii to available width and height
- use one Shape with multiple ShapePaths when fill and outline need separate treatment

DankMaterialShell uses a continuous SVG path and separate fill/border passes. Legacy Noctalia uses continuous paths with explicit convex/concave arcs. end-4 uses `PathAngleArc` for corner decorators. The asteriau notch uses quadratic top transitions.

## Antialiasing Decision Order

1. Verify that the geometry is mathematically appropriate; supersampling cannot fix a poor curve.
2. Prefer CurveRenderer's analytic AA for curved vector paths.
3. Check `rendererType` if backend support is uncertain; `preferredRendererType` is a request.
4. Align thin strokes and dimensions with the actual DPR when fractional scale is involved.
5. Use local MSAA only for GeometryRenderer after visual/performance comparison.
6. Use Canvas only when imperative raster drawing or subtraction is genuinely required.
7. Use SDF/custom shaders only for dynamic union/difference/morphing that ordinary paths cannot represent.

Do not treat these as interchangeable toggles:

- `antialiasing: true`
- `layer.smooth: true`
- `layer.samples`
- Canvas supersampling
- `MultiEffect`

They operate at different stages and have different alpha/performance behavior.

## Layers And Effects

`layer.enabled` renders an item subtree into an offscreen texture. It consumes texture memory, interrupts batching, and can change alpha composition. With MSAA it adds additional buffers. Use it only when an effect, grouped opacity, texture source, or measured local MSAA need justifies it.

`MultiEffect` is suitable for combining standard effects into one shader, but:

- minimize source area
- enable only required effect features
- avoid toggling shader-feature flags every frame
- animate opacity/offset/blur values rather than `blurMax` or padding geometry
- hide unused effects instead of leaving invisible work active
- remember the source item may still paint unless deliberately hidden

Never add a full rectangular offscreen layer around a non-rectangular translucent panel without checking its alpha output over contrasting fullscreen content.

## Opacity

Window transparency and panel material opacity are independent:

- `PanelWindow.color: "transparent"` allows non-rectangular shell surfaces.
- `Config.Theme.island` controls whether the actual panel material is opaque.
- a translucent fill painted twice becomes darker than single-painted wings/edges
- a shadow source should not accidentally repaint the panel fill

For qanda-shell, keep panel material opaque unless the user explicitly requests translucency. Do not infer a glass/translucent design from the transparent window.

## Shape, Input, Blur, And Exclusion Are Separate

Four geometries can coexist:

1. visual contour
2. `PanelWindow.mask` input region
3. compositor/backdrop blur region
4. layer-shell exclusive zone

None automatically follows another. Derive them from the same state where practical, and update each affected representation when geometry changes.

Regions use rectangular integer geometry. Check animated boundaries and fractional DPR for one-pixel gaps or accidental click blockers.

## Animation And Performance

- Prefer transforms, opacity, and a small number of scalar properties.
- Path-point animation can trigger CPU preprocessing/retriangulation.
- Avoid per-frame JS and broad binding cascades.
- Do not use `clip` as an optimization; it can reduce batching.
- Consider Loader for genuinely heavy, infrequently used panels, but account for recreation cost.
- Keep polling and process-backed state out of per-screen visual delegates.
- Profile before introducing caching layers.

Useful profiling variables include `QSG_RENDER_TIMING=1`, `QSG_RENDERER_DEBUG=render`, and `QSG_VISUALIZE=batches|overdraw|changes`. Use them intentionally; visualizer modes alter rendering and are not normal verification.

### Popout Transition Pattern

For a popout that must visually merge with a bar module, use one continuous timeline rather than a sequence of independently triggered animations:

1. Animate one normalized `transitionProgress` from 0 to 1 and back.
2. Derive width, height, opacity, visual overflow, mask extent, neighboring-module opacity, and focus/input state from that value.
3. Use smoothstep subranges when parts must overlap or hand off. A visually two-part morph should still have one uninterrupted velocity curve; do not implement it as back-to-back `SequentialAnimation` blocks unless a perceptible stop is intentional.
4. Keep panel content at its final geometry inside an animated clip viewport. This avoids relayout of the full subtree on every frame.
5. Keep expensive surfaces and content mounted across the transition. Use opacity and disabled input/focus instead of toggling `visible` at the first or last animation frame; otherwise scene-graph node creation can stall the first opening frame and close content can disappear before geometry finishes.
6. Keep vector geometry fixed where possible and reveal it through the viewport. Animating Shape path coordinates retriangulates the contour; animating the viewport and scalar opacity does not.

For overlapping surfaces, avoid a complementary-opacity crossfade between two opaque copies of the same material: alpha composition can dip below 1 in the middle. Keep the underlying surface opaque until the incoming contour fully covers it, then retire it under the cover.

Do not use hard state boundaries in the middle of a morph:

- `visible: open` makes closing asymmetric because the surface disappears before its size animation ends.
- Boolean overflow additions make the mask and clipping bounds jump.
- `Math.max()` between independently moving extents can create a derivative discontinuity when the winning branch changes.
- A neighboring module with its own `Behavior on opacity` can visibly lag behind the panel timeline.

Instead, interpolate extents through the same smooth blend and drive neighboring content opacity directly from a derived progress while the morph is active. Keep a separate boolean only for input enablement when necessary.

### Liquid Module Morphs

Liquid mode represents connected ownership, not a generic capsule. When a panel originates from a module containing multiple controls, such as `Q` plus workspaces:

- derive the intermediate surface width from the controls' actual `implicitWidth`; do not guess a fixed capsule width
- keep the controls above one shared attached contour during the handoff
- use the same ear, bottom-radius, fill, and outline conventions as the central island
- interpolate visual overflow and `PanelWindow.mask` from the same transition values
- leave the final compact edge state unpainted when the design calls for controls directly on the bar
- overlap module emergence, workspace fading, and panel contraction on one timeline rather than waiting for one phase to finish before starting the next

The successful Control Center pattern uses a bell-shaped module presence derived from `transitionProgress`: the attached module appears only in the middle of the transition, while panel expansion and workspace opacity use overlapping smoothstep ranges. This conveys the relationship without introducing a stepped two-stage animation.

### Diagnosing Jitter

Separate rendering stalls from visual discontinuities before changing performance code:

- If `QSG_RENDER_TIMING=1` shows interaction frames within budget but the motion still looks jerky, inspect state boundaries, visibility, clipping, masks, and competing Behaviors.
- Distinguish temporary-instance startup spikes from frames around the exact IPC open/close calls.
- A frame spent in `swap` with no sync/render work is not evidence that the QML animation itself is expensive.
- Profile both opening and closing. Immediate `visible` changes often make only the closing path defective.
- Test the persisted `animationSpeed: 1` case explicitly; faster settings can hide discontinuities.

Established reference patterns:

- Caelestia `ClipWrapper.qml` uses clipped reveal geometry and translated final-size content: <https://github.com/caelestia-dots/shell/blob/ad8dca0a8bdc8c92fe6581f36c70ee4d7e65388d/modules/bar/popouts/ClipWrapper.qml>
- DankMaterialShell popouts derive translation, scale, clipping, and opacity from one `openProgress` and keep the surface mapped through close: <https://github.com/AvengeMedia/DankMaterialShell/blob/5ca033d839818b660b99f2cd8f9ab9d3402fbc5f/quickshell/Widgets/DankPopoutStandalone.qml>
- Noctalia legacy `SmartPanel.qml` keeps content loaded while geometry transitions: <https://github.com/noctalia-dev/noctalia/blob/a48885b9fec485c903c955749a7da6e30147cd38/Modules/MainScreen/SmartPanel.qml>

## Production References

- Qt Shape renderer behavior: <https://doc.qt.io/qt-6/qml-qtquick-shapes-shape.html>
- Qt item layers: <https://doc.qt.io/qt-6/qml-qtquick-item.html#item-layers>
- Qt MultiEffect: <https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html>
- DankMaterialShell BarCanvas: <https://github.com/AvengeMedia/DankMaterialShell/blob/d7b19809aa991b5049434809eab339752f96b9b1/quickshell/Modules/DankBar/BarCanvas.qml>
- Noctalia legacy backgrounds: <https://github.com/noctalia-dev/noctalia/blob/a48885b9fec485c903c955749a7da6e30147cd38/Modules/MainScreen/Backgrounds/AllBackgrounds.qml>
- end-4 RoundCorner: <https://github.com/end-4/dots-hyprland/blob/42d0aae17b744a38cd05c9044c189bfc9b13869a/dots/.config/quickshell/ii/modules/common/widgets/RoundCorner.qml>
- Caelestia SDF blobs: <https://github.com/caelestia-dots/shell/tree/ad8dca0a8bdc8c92fe6581f36c70ee4d7e65388d/plugin/src/Caelestia/Blobs>
- asteriau NotchShape: <https://github.com/asteriau/dotfiles/blob/50405e1789f394243b118700256b1d0373f646ce/home/services/quickshell/modules/island/shapes/NotchShape.qml>

Caelestia's custom C++/QSG SDF implementation is excellent for smooth dynamic blob unions, but is excessive for a single static notch. Select techniques based on the problem rather than project prestige.

## Window Clipping And Visual Overflow

`PanelWindow` clips its scene graph at the window boundary regardless of whether a child Shape path, input Region, or effect padding extends farther. A correctly rounded Shape can therefore appear square when the window cuts off the pixels containing the radius.

For every expanded surface, calculate:

```text
visualBottom = item.y + item.height + visualOverflowBottom
visualRight  = item.x + item.width + visualOverflowRight
```

Then verify:

- the containing window covers the complete extent
- the input mask covers intended interactive overflow
- rectangular child content does not paint over the visible curved edge
- effect padding is either covered or intentionally clipped

The qanda-shell Settings pattern deliberately lets rectangular content stop before the Shape. The attached Shape continues through `visualOverflowBottom`, so its lower curve remains visible in both normal and immersive presentations.
