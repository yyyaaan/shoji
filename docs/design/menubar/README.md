# Menu bar Hachi — signed off

The user approved the seated, side-facing dog with the white collar on 2026-10-29. Character exploration is complete; no design choices remain. Earlier frontal/profile/husky studies and temporary previews have been removed. The existing fuller ink portrait on cards and layered app icon remain as approved previously.

## Final assets

| File | Purpose |
|---|---|
| [Approved dog PNG](assets/dog-monochrome.png) | Approved monochrome artwork; opaque white body and collar, transparent exterior |
| [SVG](assets/hachi-menubar.svg) | Path-only trace of the approved dark outlines, with transparent interiors for template tint |
| [HachiMenuBar.imageset](assets/HachiMenuBar.imageset/) | Production 16 × 16 pt vector PDF, Preserve Vector Data and template rendering enabled |
| [Provenance and prompt](PROMPTS.md) | Source origin and exact edit prompt; Desktop original untouched |
| [Vector exporter](tools/export.sh) | Reproducible trace using the existing Hachi mask utility and local Potrace 1.16; no app dependency |

The trace uses the approved image's ink mask (luminance below 96, alpha at least 80), discards isolated speckles up to eight source pixels and smooths contours with Potrace. The dark dog outlines, collar, paws and curled tail remain; the white body becomes transparent in the template glyph so macOS can tint a single ink layer. No extra face details or further character redesign.

## Menu bar behavior

- Calm: Hachi alone, no zero. Calling: the same Hachi plus the existing `wantsYou` count as system text beside it.
- Start at 16 × 16 pt; artwork already includes optical padding. Do not apply the terminal window's zoom to the menu bar.
- Use template rendering / `NSImage.isTemplate`; let macOS choose tint for light, dark and selected appearances. No baked color, glow, animation or count in the image. Use native menu bar spacing; 4 pt image-to-count gap if a custom label needs one.
- Preserve the existing count semantics, menu ordering and click behavior. Accessible label: “Shoji, no threads need you” or “Shoji, N threads need you”; avoid separately announcing the decorative image.
- Toolbar and pane controls remain SF Symbols. The Torii retains its idle-terminal meaning. This dedicated menu bar asset is the exception to the custom-toolbar-glyph restriction.

## Validation and integration

The PDF has one 16 × 16 pt page and vector paths only. The traced PDF was visually inspected against the approved shape, including light/dark ink and 16/32-pixel samples. Temporary proof files were not retained. These checks do not establish native menu bar rendering.

The coding agent should copy the imageset into the app catalog and check actual 1×/2× menu bars, selected/unselected appearances, counts 1/9/10/999, accessibility and menu behavior. Preserve the complete approved dog; if native legibility requires a material simplification, bring that specific issue back rather than substituting an earlier rejected head.

Regenerate from the repository root with `sh docs/design/menubar/tools/export.sh`. App code is unchanged by design. Open implementation and later UI review work live in [handoffs](../../handoffs/).
