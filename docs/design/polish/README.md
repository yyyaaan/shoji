# Hub and chrome polish

The current Hub, mini cards, split panes and quick terminal retain their established appearance and behavior. This review focuses on hierarchy, constrained widths and controls. [Hub reference](../hub.html) now follows shelf order and bars, using compact cards and the existing palette. It replaces the obsolete Agents / Tasks layout. Native SwiftUI remains responsible for glass and SF Symbols.

## Hub navigation and totals

Keep the approved Torii glyph. Its 34 pt circular control, 18 pt artwork, selected fill and fixed trailing position distinguish navigation from the unframed idle status glyph. Retain the present 6% resting / 20% selected fill and 14% / 32% border. No new Torii variant, badge, glow or animation. Tooltips remain “Hub (⇧⌘H)” and “Back to Threads (Esc)”; keep the accessible selected state and a visible keyboard focus indication.

The top row must not sacrifice navigation to totals. Keep the 78 pt traffic-light clearance, Hachi slot, thread count and Torii anchored. When totals no longer fit, put them in a second, wrapping row below the identity controls and let the header grow. Preserve all nonzero totals and their text labels; only needs-you is an action. Do not truncate counts, shrink type or turn the other pills into filters. Use actual available width rather than assuming a full-screen window. The HTML uses `960 × interface size` as an illustrative fallback threshold; native layout should measure fit.

**Observed:** the current `HubTotals.fixedSize()` within the fixed-height header pushes the Torii out of the 740 pt mock render at 130% interface size. The overflow also consumes the leading clearance. Test this exact case after implementation, including multi-digit totals. Keep Hachi's current `wantsYou` count, which may differ from the needs-you total because it includes optional unseen finishes.

## Hub cards

Keep the 320 pt minimum width, 12 pt padding, 16 pt corners, 10 pt grid gaps, 24 pt status icon and 14 pt semibold title, scaled with Interface Size. Keep shelf order and untitled group breaks.

- Give the title its own flexible space: first row status icon, title, status pill. Move the agent/command tag to the metadata row with folder/branch and elapsed time. This removes competition between a title, fixed tag and status pill in the same line. Cap the tag near 72 pt and truncate it if needed. Preserve full name/folder/branch in tooltips/accessibility; middle truncation of native folder metadata is fine.
- Keep the summary at one line with a full-text tooltip. Keep the three-line excerpt on solid `#0C0F15`, with fixed height even when empty. It remains display-only. Do not infer state or actions from screen text.
- Separate actions into a primary row (Open, Open Maximized, shell Restart when available, Hachi at the trailing edge) and a quiet editor-link row below (installed editors only). Keep the primary buttons at the existing 26 pt height and use at least a 22 pt hit height for editor links. Reserve the secondary row consistently when editors are installed so card bottoms align. Hachi stays 26 pt, static, decorative, and preference-aware.
- Keep needs-you orange, finished-unseen ivory, working blue, running green and failed red. Replace only the idle pill's dashed 40% border with a faint solid rim, around 18%, to keep idle visually quiet; its Torii and “Idle” label already communicate state. Increase the rim under Increase Contrast. Other status styling stays as it is.

**Observed:** ordinary 320 pt cards fit; a long-title ended-shell render leaves only “Synchronize…” beside the fixed tag and status pill. The single action row nearly fills the card with both installed editors and Restart. The revised structure provides room without changing what the card does. The HTML uses browser text/Unicode symbol approximations, not production glyph artwork.

## Mini cards

Keep 44 × 104 pt, the centered 18 pt status icon, 11 pt monospaced name rotated clockwise, current status tint, count badge and pane marker. Keep Hachi hidden on minis. Long names truncate; tooltips and accessible names retain the full text. No new dog glyph.

**Fix:** while ⌘ numbers show, the current overhanging 20 pt number badge collides with an attention badge on the preceding mini card at the 10 pt gap. Use a mini-specific plain ordinal in its leading gutter instead of a second overhanging capsule: start with 10 pt semibold, x=4 pt, y=34 pt, about 8 pt wide. Keep the centered rotated name within x=15…29 pt and the status icon above; no status replacement or adjacent-card overlap. Preserve the existing ordinal badge for normal shelf and Hub cards. Verify the mini treatment at 85% before accepting its optical size.

Shorten the rotated name's 64 pt viewport to about 60 pt if needed to preserve at least 4 pt before the bottom pane marker. Preserve the 104 pt card height and drag area. Check neighboring full/mini cards, counts 1/10/999, ⌘ numbers 1–9, focused/on-screen markers, idle Torii and error rings together.

## Pane header, shelf corner and drop preview

Keep plain SF Symbol controls and the quiet glass header. Reserve the controls' layout space so hover does not move the title; show them on hover **or when keyboard focus is inside the header**, with visible focus and existing menu alternatives. Use approximately 24 pt control hit frames (about 20 pt at 85%). Respect Reduce Motion for the hover fade. The full-form thread chevron stays separate from the double-clickable title; the compact name remains the dropdown.

At the 320 pt pane minimum, prioritize the thread name over folder metadata; shorten/hide the folder before starving the title or clipping the controls. The folder stays available through the dropdown/tooltip. Keep Restart visible for a dead shell. Do not reintroduce Pin or a layout switcher.

Keep the shelf corner visually empty apart from the Hub button. Its breathing room is useful; it does not need a stamp, label or extra decoration.

Keep the current blue half-pane drop preview, 14% flat fill, 2 pt rim, 18 pt corners and exact half-minus-gap geometry; center drops keep the full-pane outline. Preserve the distinction between card drags and file/text pastes. Before showing an edge as a valid destination, use the same feasibility rules as the actual split (including minimum pane size and compact-form restrictions). An impossible split must not be advertised as an available blue half; use no split preview in that case. This is a preflight presentation check, not another status path. Preserve existing drop semantics and keyboard/menu split actions.

## Quick terminal

Keep the floating pane treatment: 18 pt corners, glass header, solid terminal, subtle 12% scrim and present elevated position/shadow. No decorative glyph or extra glass layer. The terminal stays opaque regardless of room light.

At narrow widths, use a first header row for the terminal symbol, “Quick terminal” and a flexible folder; place the existing close/running hint on a quiet second line when it does not fit. Keep “⌘K keeps it running as a thread” readable, rather than allowing it to displace the title or terminal. Reserve header space within the popup height. Constrain the frame to the available window with at least 18 pt outer clearance; retain the current roughly two-thirds width and 300 pt × interface size height where they fit. Do not couple terminal font size to Interface Size.

The popup remains a terminal: no new Escape-to-close binding, and no changes to click-outside, ⌘K, ⌘W or adoption of a running shell. In particular, Escape while the popup is over the Hub still reaches its shell.

## Evidence and implementation checks

Review used current SwiftUI source and temporary headless `ImageRenderer` checks with invented `Mock` threads: 320 pt Hub cards at 85/100/130%, a long-title ended shell, all-state totals at 740 pt, minis with numbers and an attention badge, and the minimum pane. Render checks passed; their temporary test file was removed. The pane render cannot faithfully capture the hosted AppKit terminal, and glass renders flat. No live-user terminal or screenshot was used.

The replacement HTML was visually checked at 1360/100% and 740/130%. Its width, totals and action layout checks cover 740/1000/1360 pt at 85/100/115/130%. It is a reviewable translation reference, not proof of native behavior. Temporary proof files stay outside the design pack.

The coding agent should validate the native changes at all four Interface Sizes, window widths near 740 and 1360, and 480 pt compact/quick-terminal width, including both editors, dead shells, long names, large counts, VoiceOver, keyboard navigation, Increase Contrast, Reduce Transparency and Reduce Motion. Confirm no hidden terminal receives keyboard input in the Hub, no source of status changed, and card clicks, focus and split/drop behavior remain intact. Build and run the appropriate existing checks. Native hover, drop, material and keyboard interaction are still open implementation checks.
