# Quiet finish

An agent turn that finishes while you aren't looking (`activity.status == .done && activity.isUnseen`) gets quiet ivory chrome and a soft static halo, whether or not Threads › Show Hachi When an Agent Finishes brings Hachi too. Needs-you keeps orange and its exclamation; done keeps its checkmark and elapsed time.

## Treatment (points at 100%, times Interface Size)

| Element | Target |
|---|---|
| Border | `Palette.done` at 36% (60% with Increase Contrast) |
| Surface | Ivory wash at about 3%, keeping the focus distinction |
| Subtitle | Neutral text at 75%, never orange |
| Hachi | The existing 32 pt portrait, only with the preference on |
| Halo | `Palette.done` at 7%, 8 pt blur, no offset or spread |

The halo clears with the unseen state, when you look or the thread moves on. It is never the only cue: the rim and checkmark stay legible under Reduce Transparency and Increase Contrast.

## Compositing

- Draw the halo from the card's rounded shape behind the glass; never blur the card, its text or Hachi, and give no glyph its own shadow.
- Overlays (Hachi, border, badges) go before `.glassEffect` inside a `GlassEffectContainer`.
- Static: no pulse, shimmer or count-change animation. Keep it inside the shelf's padding without hard clipping.
