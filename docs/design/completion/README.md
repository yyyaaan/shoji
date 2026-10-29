# Optional Hachi on completion — visual exploration

[Interactive comparison](preview.html).

These are proposals, not changes to the live app or signed-off implementation instructions. No app handoff is opened until a treatment is selected.

## Current behavior reviewed

`ThreadStore.wantsYou` includes needs-you and, when enabled, a turn finished unseen. `ThreadCard` gives both the orange chrome and Hachi, while preserving the done checkmark. The setting remains optional. The on-screen line under a card identifies a thread currently shown in a pane; it is unrelated to completion.

The supplied native render is the reference. The HTML approximates glass and does not verify native compositing.

## Options

| Option | Completion treatment | Intent |
|---|---|---|
| **Current** | Orange chrome, checkmark and Hachi | Baseline from the live branch |
| **A · Quiet finish — recommended** | Existing checkmark and Hachi; subdued ivory border and neutral text | Distinguish finished unseen from blocked input with fewer competing accents |
| **B · Ink check** | A, with a static irregular ink-circle check in place of the normal done circle | Add a small ink detail that relates to the sketch portrait |
| **C · Shoji mark** | A, with a 12 pt lattice mark in the lower-left of an unseen-finish card | Echo the app icon's paper-screen geometry |

A adds no motif. Its calmer contrast and empty space are the strongest starting point. B is a possible signature detail: keep the checkmark unmistakable and the ring static so it does not read as a working spinner. C is intentionally shown as the more decorative option; the extra mark may be unnecessary beside Hachi and the checkmark. Do not combine B and C by default.

## Semantics and constraints

- Hachi may mean "something is waiting to be seen" under the user's completion preference. A turn finished unseen is not a permission request.
- In the proposed treatments, strong orange stays with actual needs-you. Finished unseen retains a done icon and distinct text/accessibility meaning.
- Keep the current optional setting, unseen clearing/focus behavior, counts, hooks and `StatusEvent` path. These sketches propose presentation only.
- Keep the same C portrait and placement. Do not create another dog expression or animate the portrait.
- Keep working, running, idle Torii and errors as implemented. The app icon is unchanged.
- Keep the bottom-center pane indicator. The optional shoji mark is separate at bottom-left and conveys no new app state by itself.
- Preview dimensions are points at 100%: 188 × 104 pt cards, 22 pt status slot, 32 pt Hachi at top 6/trailing 38, and 12 pt optional lattice at leading 14/bottom 8. Scale all metrics with app zoom.
- Proposed ivory border is a surface treatment, not a replacement for status shape/text. Use the existing `Palette.done`/text neutrals rather than introducing a new status color.

## Preview controls

Compare all cards or finished cards only. The zoom control covers 75–200%. The completion-Hachi switch demonstrates the existing preference: off removes the unseen-finish attention presentation while needs-you retains Hachi. Option B's done-check drawing remains a completion glyph in that preview; option C's extra finish decoration follows the finish-attention preference.

`assets/ink-check.svg` and `assets/shoji-seal.svg` are editable vector prototypes. If selected, prepare the native PDF/template asset or SwiftUI geometry and check optical size in the app before integration.

2026-10-29: reviewed current `ThreadCard`, `StatusIcon`, `HachiPortrait`, PLAN and the user's native render. Added this design-only comparison; no app code, runtime state or preference default changed.
