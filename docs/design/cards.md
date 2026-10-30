# Card shortcut markers

Holding ⌘ shows shortcut positions 1–9. These are navigation hints; orange badges remain attention counts.

## Full shelf and Hub cards

Move the shortcut marker from the overhanging leading corner to the **top center of its own card**. It must not share the inter-card gap with the preceding card's attention count.

At 100% Interface Size:

- Marker: 20 pt wide, 18 pt high, 6 pt corners; ivory fill, dark text, 11 pt bold rounded numeral.
- Align its horizontal center with the card's center and offset its top by −8 pt. No horizontal overhang. The marker ends 10 pt below the card top; header content starts at 12 pt, leaving 2 pt clearance.
- Preserve existing shelf top padding (10 pt) and Hub grid top padding (8 pt). This marker fits both, including the first row. Scale its geometry with Interface Size.
- Attention counts stay top-trailing with the existing +7 / −7 pt overhang, content and colors. Hachi, titles, status icons and the bottom pane marker keep their positions.

For the 188 pt shelf card, the shortcut marker occupies x=84…104 pt, separate from Hachi at x=118…150 pt. A preceding count ends at most 7 pt into the gap; the new marker starts another 84 pt into its own card. The two no longer look like a combined “9+ 2”. On wider Hub cards, centering preserves the same separation.

## Mini cards

Keep the existing plain numeral in the leading gutter (10 pt type, x=4, y=34, width 8), with no capsule or overhang. The 44 pt spine has no room for the full-card top marker. Keep its capped `9+` visual attention badge and full semantic count.

## Integration checks

Apply the full-card placement to both `ThreadCard` and `HubCard`, before `.glassEffect`. Keep overlays decorative and non-interactive; preserve shortcut timing, shelf order and accessible card names/actions. Avoid shifting card content as ⌘ is pressed.

Check neighboring full/full, mini/full and full/mini cards; counts 1/9/10/999; numbers 1–9; first and later Hub rows; focused/on-screen and needs-you states at 85/100/115/130%. Confirm top-edge clipping and Increase Contrast in native glass. The [Hub reference](hub.html) shows the proposed marker; native integration is pending.
