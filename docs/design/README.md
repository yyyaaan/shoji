# Design references

Accepted designs, source artwork and the tools that regenerate it. What ships is described in [PLAN.md](../../PLAN.md); open design work goes through [handoffs](../handoffs/).

| Reference | Purpose |
|---|---|
| [Hub](hub.html) | Hub layout across Interface Sizes and window widths; interactive |
| [Card shortcut markers](cards.md) | Full-card number placement, distinct from attention counts; native integration pending |
| [Hachi and app icon](hachi/README.md) | Ink portrait, its placements, Icon Composer layers |
| [Idle Torii](status/README.md) | Idle status glyph, also the Hub button |
| [Quiet finish](completion/README.md) | Chrome and static halo for a turn finished unseen |

Each artwork folder keeps its vector master under `assets/`, the approved raster source where there is one, provenance in `PROMPTS.md` and exporters under `tools/`. Delivered PDFs live in the app's asset catalog (`Sources/Shoji/UI/Hachi/Hachi.xcassets`); the native icon document is `Sources/Shoji/UI/Hachi/AppIcon.icon`.
