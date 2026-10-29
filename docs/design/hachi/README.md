# Hachi — signed-off design specification

[Visual reference and zoom checks](preview.html). Active coding work lives in [the handoff directory](../../handoffs/); remove addressed handoff content rather than accumulating completed notes.

## Decisions

- Quiet Balance C throughout, retaining the fuller ink sketch and relaxed ear tip.
- Open Shoji app icon, face only: no paws or Torii.
- Hachi appears on needs-you cards and optionally on agent turns finished unseen, using the existing Threads › Show Hachi When an Agent Finishes preference. The window corner counts the same `ThreadStore.wantsYou` set and opens the next waiting thread; otherwise it stays empty. No welcome illustration, terminal decoration or custom toolbar glyph.
- Static artwork; existing status shapes, labels, badge, colors and click behavior remain authoritative.
- Idle uses the separately approved [Torii status glyph](../status/README.md). Finished unseen keeps its done checkmark even when Hachi appears. The app icon remains Torii-free.

The base character and app-icon choices remain settled. The user has since added optional Hachi on unseen completion; [completion chrome alternatives](../completion/README.md) are exploratory and have not been selected.

## Production artwork

| Asset | Use |
|---|---|
| [hachi-c.svg](assets/hachi-c.svg) | Genuine four-tone vector portrait: paths only, no embedded bitmap |
| [hachi-c.pdf](assets/hachi-c.pdf) | Approximately 200 × 200 pt vector PDF for an asset catalog; preserve vector data |
| [Icon Composer layers](assets/icon-layers/) | Full 1024 × 1024 aligned canvases; import foreground SVGs in numeric order |
| [composition.json](assets/icon-layers/composition.json) | Background color, order and material intent; a manifest, not a native `.icon` file |
| [shoji-app-icon.svg](assets/shoji-app-icon.svg) | Vector reference composite, not the production layered icon |
| [hachi-c.png](assets/hachi-c.png) | Unchanged approved raster source for provenance/comparison only |
| [shoji-app-icon-1024.png](assets/shoji-app-icon-1024.png) | Flattened reference/marketing preview only |

The portrait is a four-tone contour trace of the approved source, retaining the eyes, muzzle and fur marks. Its white face is opaque; outside the silhouette is transparent. Use original colors, not template tint or inversion. Vector paths scale independently of display density; the PNG source is not the runtime export.

The trace suppresses isolated speckles up to two source pixels and quantizes gray to four tones. Compare the reference pair in the preview if regenerating. Source and trace are not pixel-identical, and no character redesign is intended.

## Geometry — points at 100% zoom

| Element | Size / position |
|---|---|
| Cards | 188 × 104 pt (one width since threads became shells) |
| Card corner / padding | 18 pt radius; 14 horizontal / 12 vertical |
| Existing status symbol | 22 pt, top-left |
| Existing count badge | Keep current minimum 22 pt and 7 pt overhang; allow digit-driven width |
| Hachi on shelf | 32 × 32 pt, aspect fit; top **6 pt**, trailing **38 pt** |
| Hachi in the window corner | 36 × 36 pt, capped at 58 pt (the column is 78 pt at any zoom); centered under the window buttons, bottom aligned with the cards; count badge top-trailing |
| Hachi on future Hub needs-you card | 48 × 48 pt, trailing in header, 12 pt text gap; hide first if space is insufficient |

Every chrome dimension and offset uses the existing `@Environment(\.zoom)` scale. Shelf portrait bounds at 100% are x=118…150, y=6…38. The title begins at y=40 in the current layout. The portrait moves left from the previous proposal so a **999** count badge can grow left without touching it. The ring and CLI kind retain the leading header area. Pixel density is independent of zoom; vector assets cover 75–200% at 1×/2× without a bitmap upscale.

The preview measures portrait-vs-status, portrait-vs-badge and portrait-vs-title intersections for counts 1 and 999 at 75%, 100% and 200%. It also checks that the portrait stays inside its card. These are HTML geometry checks; native SwiftUI validation remains necessary.

## Rendering and behavior

- Condition: existing `ThreadStore.wantsYou(id)`, which includes needs-you and optionally unseen agent completion. No scraping, extra status source or state change.
- Attach the decorative overlay **before** `.glassEffect(...)` inside `GlassEffectContainer`.
- `.allowsHitTesting(false)` and `.accessibilityHidden(true)` on the illustration. Preserve the existing card accessibility label and actions.
- Static appearance is the supplied Reduce Motion version and default. If a later implementation adds an appearance fade, keep it subtle, disable it under Reduce Motion and do not repeat it on count/hook updates.
- Dark UI only. Working `#74B8FF`, needs-you `#FF9F43`, done `#E2E8F0`, running `#4FD1B5`, error `#FF8787`. The portrait does not replace the ring plus exclamation mark or text label.
- Terminal `#0C0F15`, window `#0B0E13`. Glass stays on chrome, with a solid opaque surface behind terminal text.
- Toolbar, pane and shortcut glyphs remain SF Symbols. This portrait is decoration, not a new UI glyph; do not replace existing symbols with it.
- Original [shelf](../threads-shelf.html) and [Hub](../hub.html) HTML remain the layout references. Translate the design to SwiftUI rather than copying HTML.

## Layered app icon

All layers use the same 1024-unit canvas, with no baked corner mask, blur, shadow or lighting.

1. **Native background:** ink green `#17201F`. `00-background.svg` is a color reference; use Icon Composer's background setting instead of importing a redundant opaque foreground.
2. **01-hachi.svg:** opaque matte face, x=248, y=240, 528-unit square placement of the portrait canvas. No glass or distortion on the face.
3. **02-shoji-left.svg** and **03-shoji-right.svg:** separate paper panels; retain color and alignment. Any restrained material effects belong in Icon Composer.
4. **04-shoji-rail.svg:** front lower rail, without paws.

The reference composite uses a flat fallback background. Native Icon Composer provides the platform material, lighting and mask. A flattened image or an SVG containing `<image>` is not the production delivery. Preview the native document on macOS at 16 pt and its relevant appearances before accepting it.

Apple recommends aligned SVG layers, meaningful back-to-front numbering, no exported canvas mask and effects applied in Icon Composer: [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).

## Provenance and regeneration

[Historical generation prompt](PROMPTS.md) describes the approved raster source. The earlier sparse-line request is superseded by the fuller sketch selection.

Export utilities in `tools/` use macOS CoreGraphics/ImageIO, Python's standard library and the local design tool Potrace 1.16. These are offline export tools, not application dependencies. Generate tone masks with `trace-masks.swift`, trace silhouette/light/mid/ink with Potrace, then run `build-vectors.py` on that trace directory. The original PNG is retained so the trace can be reproduced.

2026-10-28: addressed app-side design constraints with genuine vector exports, separate icon layers and a badge-safe zoom-aware placement. Existing app code and `AGENTS.md` are untouched. Native integration and Icon Composer packaging are intentionally handed off. No commit or push.

[Export and geometry evidence](validation.json): path-only production SVGs, no PDF image objects, and all six Retina-density HTML collision cases passed. Native checks are deliberately not reported as complete.
