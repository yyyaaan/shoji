# Idle Torii

| State | Glyph |
|---|---|
| Idle | Static Torii gate |
| Working | Blue spinning arc |
| Done | Checkmark; Hachi on an unseen agent finish follows the app preference |
| Needs you | Orange ring and exclamation, plus Hachi |
| Running / error | Pulsing dot / ring with × |

The Torii means an idle prompt, not a finished agent turn. The app icon has no Torii, and toolbar, pane and shortcut glyphs stay SF Symbols. The one other use is the Hub button at the window's top right: the bare glyph at 20 pt, white at 55%, full while the Hub shows.

## Assets

- [torii-idle.svg](assets/torii-idle.svg): 24-unit vector master, ink `#E2E8F0` at full opacity, no raster.
- The delivered template PDF (24 × 24 pt, Preserve Vector Data) is `Sources/Shoji/UI/Hachi/Hachi.xcassets/IdleTorii.imageset`; `tools/export-torii.swift <pdf>` regenerates it with CoreGraphics.

Tint it once, natively: `Palette.done.opacity(0.55)` as a status. No vermilion, glow, ring or animation.

## Sizing

- `StatusIcon` fits it to the whole `size` canvas (the artwork carries its own optical padding), not the rings' inner frame: 22 pt on full shelf cards, 18 pt on mini cards and in the ⌃Tab switcher, 16 pt in pane headers, 24 pt on Hub cards, all times Interface Size.
- At 22 pt the 1.7-unit strokes read at about 18 pt wide, the weight of the other states.
