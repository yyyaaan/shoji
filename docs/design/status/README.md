# Status glyphs — idle Torii

[Visual reference and size checks](preview.html).

## Approved mapping

| State | Presentation |
|---|---|
| Idle | Static Torii gate, replacing the dashed circle |
| Working | Existing blue spinning arc |
| Done | Existing checkmark; optional Hachi on unseen agent completion follows the current app preference |
| Needs you | Existing orange ring/exclamation plus the approved Hachi portrait |
| Running / error | Existing pulsing dot / error glyph |

Torii means an idle prompt, not an agent turn finishing. Hachi marks attention/input and, under the user's optional setting, an agent turn completed unseen. Done still keeps its checkmark; it does not become the orange exclamation state. Status labels and accessibility names retain their existing meanings. No status source or model change is required.

This Torii is a UI status glyph only. The signed-off face-only Open Shoji app icon stays without Torii. Toolbar, pane action and shortcut glyphs remain SF Symbols.

## Production assets

- [torii-idle.svg](assets/torii-idle.svg): editable 24-unit vector master, no raster or baked opacity.
- [IdleTorii.imageset](assets/IdleTorii.imageset/): ready-to-copy vector PDF image set with Preserve Vector Data and template rendering.
- [torii-idle.pdf](assets/IdleTorii.imageset/torii-idle.pdf): 24 × 24 pt, transparent outside the strokes.

Render the template with **`Palette.done.opacity(0.55)`**, matching the old idle treatment. The source ink is `#E2E8F0` at full opacity so the native tint/opacity is applied exactly once. No vermilion, glow, surrounding ring or animation.

## Sizing and alignment

- Keep `StatusIcon`'s existing outer `size` and alignment: 22 pt on cards, 16 pt in pane headers and 18 pt in the recent-thread switcher, before app zoom.
- The 24-unit artwork has 1.7-unit rounded strokes. At a 22 pt canvas its visible width is approximately **18.1 pt**, matching the requested 18–20 pt optical size and existing status weight.
- Fit the asset to the **full `size` canvas** for idle. Do not then constrain it through the old ring-sized inner frame: the artwork already has optical padding and would be undersized twice.
- Scale the whole canvas with the existing zoom. The preview checks 75/100/200% for all three current call sites, including the 12 pt pane-header minimum at 75%.
- The glyph stays inside the existing status slot, so card title, Hachi and badge positions do not move. Native previews should confirm baseline and optical balance against adjacent states.

The SVG and PDF use the same quadratic upper beam, lower rail, two gently splayed posts and short center support. `tools/export-torii.swift` regenerates the PDF using CoreGraphics; it adds no app dependency.

[Validation evidence](validation.json): all nine size/zoom combinations passed at both 1× and 2× display density. The one-page PDF has a 24 × 24 pt media box and no raster image objects. The app's native checks (all three call sites at 75/100/200% zoom, 1× and 2×, beside the other states) passed on 2026-10-29.

## Implementation boundary

Only `.idle` in the shared `StatusIcon` changes. Its existing callers therefore remain consistent across shelf, pane headers and recent switcher. Keep the outer size, help text and accessibility label. Hachi, the needs-you corner indicator, status hooks and terminal content remain unchanged.

The dark-surface HTML is a sizing/reference preview, not app code. Native rendering and regression checks belong to [the active app handoff](../../handoffs/). Delete the handoff when addressed; retain this specification and assets.
