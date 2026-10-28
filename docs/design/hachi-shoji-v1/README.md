# Hachi & Shoji — decoration study 01

Status: design assets and implementation proposal, 2026-10-28. Nothing is installed in the app.

Open [preview.html](preview.html) for placements, actual-size shelf cards, a Hub sample, and dark/light surface checks. [PROMPTS.md](PROMPTS.md) records generation inputs. [SESSION.md](SESSION.md) records this additive design session.

## Direction

**A quiet threshold, a familiar face.** Shoji panels frame the workspace; Hachi waits at its edge when a thread needs attention. Warm honey fur and ivory paper balance the existing ink, blue and teal palette.

Hachi has a broad Akita head, thick neck ruff, upright ears, ivory cheeks, rounded paws and a calm, closed-mouth expression. Use the supplied portrait as the character reference for future work. The delivered treatment is a soft, detailed fur illustration; small placements rely on its silhouette rather than individual hairs.

Keep the existing 18 pt shelf radii, 22 pt Hub radii, spacing, type, status palette and solid terminal surface. Hachi is supplementary decoration. Existing status shapes and labels remain authoritative.

## Deliverables

| File | Master | Proposed use | Display size |
|---|---|---|---|
| [hachi-attentive.png](assets/hachi-attentive.png) | 1254 × 1254, RGBA | Needs-you shelf and Hub cards | 32 × 32 pt shelf; 48 × 48 pt Hub |
| [hachi-resting.png](assets/hachi-resting.png) | 1536 × 1024, RGBA | Workspace with zero threads | 160 × 107 pt; up to 192 × 128 pt |
| [shoji-app-icon-concept.png](assets/shoji-app-icon-concept.png) | 1254 × 1254, opaque visual square | Future app icon / About artwork | Preview at 128–256 pt |
| [shoji-mark.svg](assets/shoji-mark.svg) | 24 × 24 vector, 1.5 unit stroke | Optional About / welcome identity accent | 20–24 pt |

PNG masters were generated with the built-in imagegen tool. The lattice mark is hand-authored vector geometry. Both Hachi PNGs contain genuine transparent pixels and soft alpha edges; preserve the alpha when exporting. The icon has a full square background; the preview adds its own presentation mask.

### Palette

| Role | Color | Treatment |
|---|---|---|
| Hachi fur | Honey amber, approximately `#D99A55` | Natural illustration shading; no state tint |
| Cheeks / paper | Warm ivory, approximately `#F4E9D8` | Character and identity artwork |
| Nose / eyes | Charcoal, approximately `#252A33` | Preserve facial contrast |
| Needs you | Existing `#FF9F43` / `#FFA94D` | Existing border, count and ring |
| Terminal | Existing `#0C0F15` | Solid, decoration-free |
| Lattice mark | `#E2E8F0` master stroke | Template tint from surrounding text |

Do not add wood textures or paper textures throughout the live workspace. The shoji panels belong in identity artwork; the lattice mark is the restrained chrome-scale counterpart.

## Coding-agent handoff

These are instructions for a later implementation task. Adopt one placement at a time, using mock threads first.

### 1. Needs-you shelf card — first increment

Target: `Sources/Shoji/UI/Shelf/ThreadCard.swift`.

- Show `hachi-attentive` only for agent cards whose existing `activity.status == .needsYou`. Derive no new state.
- Keep the current 196 × 104 pt card. Place a 32 × 32 pt aspect-fit image at x = 146, y = 8 from its top-left: equivalently top = 8, trailing = 18. These coordinates describe the full card bounds, not the padded content bounds.
- Preserve the 22 pt status ring and CLI kind on the left. Preserve the title and one-line status across the lower rows. The top-right area is otherwise empty in this status.
- Leave the existing count capsule at its current top-right offset. Hachi ends 18 pt inside the right edge and 40 pt below the top; the capsule remains outside that silhouette.
- Add the Hachi overlay **before** the card's `.glassEffect(...)`, following the existing overlay-order gotcha in `PLAN.md`. Confirm native compositing: the HTML cannot reproduce `GlassEffectContainer` behavior.
- Use full-color rendering, aspect fit, no tint, no new shadow, and no glass effect on the illustration. Do not crop ears or paws.
- Set `.allowsHitTesting(false)` and `.accessibilityHidden(true)` on this decorative image. Preserve the card's existing consolidated accessibility label and click behavior.
- Keep it static for this increment. Do not add a timeline or animation loop.

If long labels or a future compact card collide with Hachi, hide the decoration before shortening required content. Do not change card height or shelf spacing to accommodate it.

### 2. Hub card — when M4 exists

Target: future `Sources/Shoji/UI/Hub/` views. There is no native Hub implementation in this checkout; `../hub.html` is the layout reference.

- Show the same portrait at 48 × 48 pt in the needs-you card's header trailing region, inside its 18 pt padding.
- Keep the original status symbol, title, CLI kind and text status pill. If the header cannot fit the original pill and the portrait, place the pill below the title or omit Hachi; do not remove the label.
- Keep a 12 pt gap between Hachi and text. The preview demonstrates this arrangement with a simplified text label; implementation must retain the existing design's full status treatment.
- At narrow widths or large accessibility text sizes, omit Hachi first. Permission details, buttons and status remain visible.
- Hachi never overlaps the solid terminal preview, command detail or action row. No approval or other action is attached to the image.

### 3. Empty workspace — after real empty-state support

Targets: future empty state in `MainView` / `PaneGrid`, after the new-thread flow exists.

- Show `hachi-resting` only when `store.threads.isEmpty`, centered above a short heading and the actual New thread action.
- Proposed copy: **Your next thread starts here** / **Open an agent or start a task.**
- Use 160 pt width, original 3:2 aspect ratio, 16 pt space before the heading and generous whitespace. This is an empty-workspace illustration, not a terminal background.
- Zero visible panes with existing threads is a different state: offer reopening a shelf thread. Do not imply the user's threads vanished.
- Never show this pose merely because agents are idle, tasks are stopped, or a process failed. Avoid implying a health state through a dog pose.
- Keep illustration noninteractive and hidden from accessibility; expose the heading and real button. Do not implement a decorative fake button from the HTML.

### 4. Identity artwork — separate later increment

The app-icon PNG is a concept, not an installed AppIcon or a finished platform icon package. Its large face and open shoji panels establish the composition. Test it at 16, 32, 64, 128 and 256 pt before adopting. Fine fur, wood detail and panel rails may need simplification at Dock/menu sizes; use the lattice mark for small identity-only contexts in the meantime.

Do not use the icon artwork as a toolbar button, status indicator or busy background. Optional About artwork can use the PNG at 128–192 pt. The small lattice mark may appear once beside the app name in welcome/About chrome. It is not an interactive control and does not replace the pane-layout picker icons.

The SVG's central open bay echoes the icon's doorway. For native use, recreate its simple 24-unit geometry as a SwiftUI shape, or export a vector PDF as an Xcode template image. Tint it with the existing secondary foreground color; the white master is unsuitable on a light background without tinting.

## Native asset preparation

When implementation is authorized, copy adopted assets into a new asset catalog under `Sources/Shoji/UI/Hachi/` (for example `HachiAssets.xcassets`). Suggested image-set names: `HachiAttentive`, `HachiResting`, `ShojiMark`. Use original rendering for Hachi; template rendering only for the lattice mark.

Keep masters in this folder. Create appropriately sized derivatives rather than decoding full masters for every tiny card. Suggested raster exports:

| Image | 1× | 2× |
|---|---|---|
| Shelf portrait | 32 × 32 px | 64 × 64 px |
| Hub portrait | 48 × 48 px | 96 × 96 px |
| Resting illustration | 192 × 128 px | 384 × 256 px |

Use separate shelf/Hub image sets if supplying those exact scales. Preserve unassociated alpha correctly through the export tool, and inspect against dark and light surfaces. Do not flatten PNGs against the terminal color or sharpen translucent fur edges.

The current XcodeGen source root is `Sources/Shoji`; check that the generated build includes the new catalog. Any necessary build settings belong in `project.yml`, followed by regeneration. Never hand-edit `.pbxproj`. Do not add a package for decoration. AppIcon packaging and build settings belong to the later icon task.

## Motion and accessibility

- Static assets are the default. A later appear treatment may fade Hachi in over 160 ms when the status transitions to needs-you; no bounce, paw tapping, blinking or recurring attention motion.
- With Reduce Motion enabled, show/hide immediately. Do not animate every hook update or unread-count change.
- Preserve the existing ring, exclamation mark, text label and attention count; the illustration must never be the only status cue.
- With Reduce Transparency enabled, use the app's opaque chrome treatment; keep the illustration itself unchanged. No blur behind terminal text.
- Offer a decoration preference only if product settings later call for it. Hiding artwork must not hide status or change behavior.

## Acceptance checks for the implementation task

- Preview `.needsYou`, `.working`, `.done`, `.idle`, `.running` and `.exited` with mock threads. Hachi appears only on needs-you agent cards.
- Check long thread titles, 1- and 3-digit attention counts, horizontal scrolling, pane focus and compact widths. No overlaps or lost hit targets.
- Check dark/light chrome and increased contrast; inspect transparent edges at 1× and 2×. The light toggle in the HTML is an art contrast check, not a new app theme proposal.
- Check Reduce Motion, Reduce Transparency and VoiceOver. Decoration contributes no repeated accessibility announcement.
- Confirm the app launches headless in tests as before; art adds no shells, status sources or terminal keystrokes.
- Build with the existing project command after native integration. No native build is required for this docs-only study.

## Source references

Reviewed `PLAN.md` Status and Gotchas; `../threads-shelf.html`; `../hub.html`; and the current `ThreadCard`, `ShelfView`, `MainView`, `PaneView`, `StatusIcon`, `Theme`, `Backdrop` and `project.yml`.

The preview is an additional proposal. The existing design HTML remains the layout source of truth. Hub samples are illustrative, not evidence that Hub has shipped. No M5 milestone is marked complete by this asset study.
