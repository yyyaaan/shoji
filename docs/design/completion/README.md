# Quiet finish — option A selected

The user selected Quiet finish A with the soft static ivory halo. The glow is **independent of the Hachi-on-finish preference**. Temporary comparison pages and screenshots have been removed; this is the final specification.

## Signed-off direction

- Keep the existing done checkmark and elapsed time. Show the existing C portrait only when the completion-Hachi preference allows it.
- Use quiet ivory chrome and neutral subtitle text for an unseen completed turn, while actual needs-you retains orange and its exclamation symbol.
- Add a restrained static ivory halo to the completed card. Do not add the earlier ink-circle or shoji-stamp alternatives.
- Keep the current finish-Hachi preference for the portrait and existing navigation/count behavior. Completion chrome and glow do not depend on that preference. Preserve unseen clearing, status events, focus, keyboard behavior and the pane marker.

Native implementation remains in [the app handoff directory](../../handoffs/).

## Treatment — points at 100%

| Element | Reference target |
|---|---|
| Card | Existing 188 × 104 pt, 18 pt corners |
| Border | Existing hairline width; `Palette.done` at approximately 36% |
| Completion surface | At most a light ivory wash, approximately 3%; preserve the existing focus distinction |
| Subtitle | Existing neutral text at approximately 75%; no orange completion text |
| Hachi | Existing 32 pt C portrait at top 6 / trailing 38 pt, unchanged |
| Soft glow | `Palette.done` at **7%**, **8 pt** blur radius, zero directional offset or added spread |

The glow numbers are a visual target; tune the native effect to remain faint and subordinate to the orange needs-you treatment. Glow radius and any added metrics scale with app zoom; keep the existing card, glyph and portrait geometry.

## When the halo appears

Use `activity.status == .done && activity.isUnseen` for the quiet completion chrome and halo. **Do not gate them on `wantsYou` or the finish-Hachi preference.** Hachi itself keeps its existing preference-aware condition. Do not add persistence or another status.

The halo clears with the current unseen state when seen or when the thread moves on. Turning off Hachi on finish hides the portrait but leaves the unseen-completion halo and quiet chrome. Needs-you keeps its existing orange styling. Other statuses retain their existing presentation.

The window-corner Hachi/count/navigation behavior is outside this card-chrome change. The bottom-center line still means the thread is shown in a pane; neither halo nor completion changes that marker.

## Native compositing and accessibility

- Create the glow from the rounded card shape behind the chrome. Do not blur the whole card, text, terminal content or portrait, and do not give each glyph its own shadow.
- Respect the existing GlassEffectContainer overlay ordering: Hachi, border and badge remain before `.glassEffect`. Verify the halo in the running app; an ImageRenderer/HTML approximation cannot prove the native material result.
- Check the current shelf's 10 pt top / 6 pt bottom padding, 10 pt card gap, scrolled first/last cards and neighboring completion halos. Avoid hard clipping or an unexpectedly wide bloom. Do not change the shelf or card dimensions just to accommodate the effect without assessing the native result.
- Preserve keyboard focus contrast, count-badge priority, click/drag hit targets and status text/accessibility labels, including "not seen yet".
- Static means no pulse, breathing cycle, repeated shimmer or count-change animation. It is already suitable for Reduce Motion. Under Reduce Transparency/increased contrast, keep a legible rim/checkmark; the glow is never the sole status cue.

## Verification

The temporary browser comparisons checked geometry at 75/100/200%. Those previews have been removed, and their previous preference-off check is superseded by the final independent-glow decision. The app agent must verify halo persistence with Hachi off, unseen clearing, native glass, clipping and runtime transitions.

No new image asset is required for A or its glow. Existing Hachi/vector status assets remain the artwork source. The earlier B/C prototype glyphs are removed from the active pack.

2026-10-29: A and soft halo confirmed; user clarified that glow remains with Hachi off. Final spec/handoff retained and temporary previews removed. No app code, model, hooks or preference default changed by design.

2026-10-29: implemented in the app (`ThreadCard`): ivory rim at 36% (60% with Increase Contrast), 3% surface wash, neutral subtitle, and the halo as a blurred card shape behind the glass. Offscreen renders at 75/100/200% show it only on unseen finishes, with Hachi on or off, fading inside the shelf padding; native glass is on the user's hands-on list.
