# Design references

Only accepted designs, source artwork and regeneration tools belong here. Keep active agent work in [handoffs](../handoffs/); remove superseded candidates, temporary renders and intermediate exports after sign-off.

| Reference | Purpose |
|---|---|
| [Shelf and panes](threads-shelf.html) | Original layout reference; later interaction decisions live in [PLAN.md](../../PLAN.md) |
| [Hub](hub.html) | Hub look reference; the app keeps cards in shelf order, without the Agents / Tasks split |
| [Hachi and app icon](hachi/README.md) | Approved ink portrait, placement and aligned Icon Composer layers |
| [Idle Torii](status/README.md) | Status glyph, template PDF and sizing |
| [Quiet finish](completion/README.md) | Completion chrome and static halo, independent of the Hachi preference |

Each artwork folder keeps its editable vector master and delivery PDF/imageset under `assets/`, approved raster sources where needed, provenance in `PROMPTS.md`, and reusable exporters under `tools/`. These sources support regeneration; they are not discarded iterations. Layered icon masters stay in `hachi/assets/icon-layers/`; the native Icon Composer document lives in `Sources/Shoji/UI/Hachi/AppIcon.icon`.
