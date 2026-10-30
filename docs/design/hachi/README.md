# Hachi

Hachi, an Akita in fuller ink (Quiet Balance C, one ear tip relaxed), is static decoration for threads that want you; status shapes, labels, badges and colours stay authoritative.

- Hachi appears on needs-you cards and, with Threads › Show Hachi When an Agent Finishes, on agent turns finished unseen (`ThreadStore.wantsYou`). The window corner counts the same set and opens the next one; otherwise it stays empty.
- No welcome illustration, terminal decoration or toolbar glyph. Idle is the [Torii](../status/README.md); an unseen finish keeps its checkmark and gets the [quiet finish](../completion/README.md) halo with or without Hachi.
- The app icon is the face only between shoji panels: no paws, no Torii.

## Artwork

| Asset | Use |
|---|---|
| [hachi-c.svg](assets/hachi-c.svg) | Four-tone vector portrait, paths only |
| `Sources/Shoji/UI/Hachi/Hachi.xcassets/HachiPortrait.imageset` | The delivered PDF (about 200 × 200 pt, Preserve Vector Data) |
| [Icon Composer layers](assets/icon-layers/) | 1024 × 1024 aligned canvases, imported in numeric order; [composition.json](assets/icon-layers/composition.json) is the manifest |
| [hachi-c.png](assets/hachi-c.png) | The approved raster the vectors are traced from |

The portrait's white face is opaque and everything outside the silhouette transparent. Use its own colours, never a template tint or inversion.

## Placement (points at 100%, times Interface Size)

| Where | Size and position |
|---|---|
| Shelf card (188 × 104, 18 pt corners) | 32 × 32, top 6, trailing 38, clear of the status icon, title and a 999 count badge |
| Mini card | None |
| Window corner | 36 × 36, capped at 58 (the column is 78 at any size), under the window buttons, bottom aligned with the cards; count badge top-trailing |
| Hub corner | 36 × 36 beside the window buttons, bottom aligned in the 44 pt row |
| Hub card | 26 × 26 in the action row, after Open Maximized |

## Rendering

- Overlays go before `.glassEffect` inside a `GlassEffectContainer`; the portrait doesn't take hits and is hidden from accessibility, leaving the card's label and actions as they are.
- Static by default and under Reduce Motion; any later fade stays subtle, off with Reduce Motion, and never repeats on count or hook updates.
- Dark UI only: terminal `#0C0F15`, window `#0B0E13`, glass on chrome, a solid surface behind terminal text.

## App icon layers

All layers share a 1024-unit canvas with no baked mask, blur, shadow or lighting; Icon Composer adds material, lighting and the mask ([Apple's guide](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)).

1. Background: ink green `#17201F`, set in Icon Composer (`00-background.svg` is only the colour reference).
2. `01-hachi.svg`: the opaque matte face at x=248, y=240, 528 units square.
3. `02-shoji-left.svg`, `03-shoji-right.svg`: the paper panels.
4. `04-shoji-rail.svg`: the front lower rail.

The native document is `Sources/Shoji/UI/Hachi/AppIcon.icon`; check it at 16 pt and in its appearances before accepting a change.

## Regenerating

[PROMPTS.md](PROMPTS.md) records how the raster was made. The tools are offline, not app dependencies: `tools/trace-masks.swift <png> <dir>` writes tone masks, Potrace 1.16 traces silhouette, light, mid and ink, then `tools/build-vectors.py` builds the portrait and icon layers from that trace folder. Compare the result with the PNG; they aren't pixel-identical, and no redesign is intended.
