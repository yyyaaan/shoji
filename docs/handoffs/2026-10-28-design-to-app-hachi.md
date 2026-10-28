# Hachi — remaining native integration

**Design review — 2026-10-28:** assets and export evidence rechecked; no design-side work remains. All five items below are still app-side work: no Hachi asset set, card integration or native icon document is present in the current source. Ready for the app agent to claim with `Taken by: app, <date>`.

Source of truth: [signed-off specification](../design/hachi/README.md) and [vector preview](../design/hachi/preview.html). Design-side notes are addressed; only the following native work remains. Remove each item when addressed and delete this file when empty.

- [ ] Add `assets/hachi-c.pdf` to a native image set with **Preserve Vector Data** and original colors. Use the PDF/SVG vector artwork, not the archival PNG. Keep any build settings in `project.yml` and regenerate with XcodeGen.
- [ ] In `ThreadCard`, show Hachi only for needs-you agent cards. At 100%: 32 pt square, top 6 pt, trailing 38 pt. Multiply all sizes/offsets by the existing `zoom`. Add the overlay before `.glassEffect`; preserve status shape/text/badge, hit targets and the existing accessibility label. Keep the portrait static and hidden from accessibility.
- [ ] Check native cards at 75/100/200% zoom and Retina density, counts 1/999, long titles, all statuses and task cards. Confirm no overlaps or clipping, correct glass ordering, Reduce Motion/Transparency, and unchanged keyboard/focus behavior. HTML collision checks are evidence, not a substitute for the native check.
- [ ] Create the native Icon Composer document from `assets/icon-layers/`, using `composition.json` for alignment/order and the native ink-green background. Keep Hachi matte/opaque, panels restrained and the platform mask/effects native. Check macOS 16 pt legibility and appearances, then add the native icon document through XcodeGen. The flattened PNG and composite SVG are reference previews only.
- [ ] Build and run the repository's appropriate native checks after integration. Confirm terminal content remains solid and SF Symbols remain the UI glyphs. Record any actual integration gap in this handoff; remove completed items instead of retaining a completion log.
