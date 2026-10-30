# Zen icons

Four original line drawings in the Torii's hand. [Preview](preview.html) shows them at small sizes, light and dark.

| Icon | Use | Master |
|---|---|---|
| Lantern | The Hub button, top right | [lantern.svg](assets/lantern.svg) |
| Stones | Under the lantern: a new thread in a folder | [stones.svg](assets/stones.svg) |
| Bamboo | Not placed yet | [bamboo.svg](assets/bamboo.svg) |
| Bonsai | Not placed yet | [bonsai.svg](assets/bonsai.svg) |

The delivered template PDFs (24 × 24 pt, Preserve Vector Data, black with alpha for native tint) are `Zen*.imageset` in `Sources/Shoji/UI/Artwork.xcassets`. `python3 docs/design/zen/tools/export.py` regenerates them there from the SVGs, which are authoritative.

## In the app

- `CornerControls`: the lantern over the stones in one column, 20 pt art in 34 pt hit frames 2 pt apart, all times Interface Size; the lantern sits on the window buttons' line in both Threads and the Hub.
- Bare glyphs: no circle, rim, glow or background. White at 55%; the lantern is full white while the Hub shows, with the selected accessibility state.
- The stones' accessible name is the action ("New Thread in a Folder"), not the picture.
- These are the exceptions to SF Symbols for controls; the Torii stays the idle status glyph.
