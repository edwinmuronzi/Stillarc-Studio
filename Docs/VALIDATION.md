# Validation

## 0.2.0, build 2 — active sections and framing

The simulator and iPhone 17 Pro processing suites passed for active-section indicators, section reset/undo, exact-value parsing, preset framing isolation, movable crops, 19 individual controls, and 400 geometry fixtures covering odd/even dimensions, four rotations, five angles, five ratios and both edge anchors. A fractional crop-boundary issue found by the fixture was corrected before release. JPEG and PNG exports retained the straightened crop; original-preservation and large-image checks still passed.

The strengthened simulator legacy fixture also checked that non-neutral 0.1 edits survive migration with neutral defaults for new fields. Indicators are derived from the recipe, so reopening and applying recipes use the same logic. Reset is per section and undoable; a zero-strength look alone does not light the Film dot.

The first fresh 0.2 phone preview check requested 180 changes with film, grain, bloom, straightening and cropping enabled. It completed 151 coalesced renders, zero GPU failures and zero idle redraws; p95 render completion was 12.83 ms. Thermal state stayed fair. Coalescing means intermediate requests may be skipped so the newest state wins; this is not a claim of 60 displayed frames per second. Raw results are under Verification/0.2.0.

The final uninterrupted 0.2 phone run requested 7,200 updates and completed 5,799 coalesced renders over 130.0 seconds, with p95 render completion 13.70 ms, zero GPU failures and zero idle redraws. Thermal state remained fair. This is a sample-photo test with a look, grain, bloom, straighten and crop active, not a claim of 60 displayed fps or negligible battery use. Interrupted attempts were excluded. The diagnostic now reads live application activity, records interruptions, and temporarily disables automatic screen locking only during the explicit test, restoring the prior setting afterward. These hooks are absent from production.

## 0.1.0, build 1 — foundation

11 November 2026. This is a first working photo-editor milestone. Checks below do not establish feature parity with other editors, certify every iPhone or prove negligible energy use.

## Automated correctness

Passed on iPhone 17 Pro and simulator:

- All 17 individual adjustment controls and all five non-neutral built-in looks changed rendered pixels; a neutral recipe preserved the baseline pixels.
- Project recipes and saved presets survived disk serialization/reloading. Undo/redo grouped a slider gesture correctly.
- Both JPEG and PNG exports reopened with expected geometry. The suite caught and corrected fractional centered-crop rounding before release.
- Imported source bytes stayed identical after editing/export. Removing a Studio project removed its index without touching the external source.
- Synthetic 12MP, 24MP and 48MP JPEG fixtures decoded within the 1600-pixel preview bound and exported at 4000×3000, 6000×4000 and 8000×6000. These are simple gradients, not complex camera RAW files; timings must not be generalized to those.
- 120 sequential adjustment renders completed without failure.

The test uses isolated temporary projects and temporary export files, not the user's Photos library.

## iPhone 17 Pro live-preview check

An optimized diagnostic build exercised 7,200 exposure/warmth changes, requested 16 ms apart for approximately two minutes, with Daylight, 15% grain and 10% bloom enabled. It used the bundled sample, bounded to the preview size.

- **7,200 renders** completed; **0 GPU failures**.
- Render submission-to-completion p95: **8.71 ms**. This is not measured touch-to-display latency or a direct presentation frame-rate measurement.
- **0 additional frames** during the three-second idle check.
- System thermal state was **fair at start and fair at end**. It did not start cool, and no temperature sensor or battery-energy benchmark was captured. This does not prove the phone did not warm or establish all-day efficiency.

[Raw preview report](Verification/iPhone17Pro-sustained-preview.json) · [Raw processing report](Verification/iPhone17Pro-processing.json) · [Simulator report](Verification/Simulator.json)

## Build and layout

The signed normal Release archive passed Xcode compilation and strict code-signature verification. Diagnostic hooks are compiled only in Debug. The production Release was installed and launched successfully on iPhone 17 Pro. The app uses a separate identifier from Stillarc Camera and does not replace it.

Actual simulator views were inspected at iPhone 18 Pro, compact iPhone 13 mini and iPad Pro sizes. Portrait uses bottom controls; wide layouts use a sidebar. [Screenshots](Screenshots) show the real app with the owned illustrative sample. This verifies layout on those simulators, not physical older-device performance or every Dynamic Type size.

## Repeat the checks

```sh
scripts/verify-simulator.sh BOOTED_SIMULATOR_UDID
```

The script builds Debug, installs, and runs processing/export/persistence and preview checks. Reports are written into the app's Documents folder. The diagnostic launch arguments are `--verify-studio --demo-editor --verify-preview`; add `--sustained-preview` for 7,200 requests instead of 180. Diagnostics only operate automatically when explicitly launched with those flags. Do not interrupt an active test and treat an old report as a new result.

## Still needs real-world validation

- A representative set of supported RAW/ProRAW cameras, orientations and HDR/HEIF sources, including visually matching previews to exports.
- Long editing sessions from a cool phone, energy measurements, large complex RAWs and full-resolution effect-heavy exports.
- Physical older iPhones, older supported OS releases, memory pressure, low storage, interruptions and accessibility sizes/VoiceOver.
- Manual Photos/Files picker, permission-denied and Save to Photos/share-sheet flows. Automated tests avoid changing the real Photos library.
- User testing of crop positioning needs, advanced tool discoverability and whether the simplified initial controls meet actual tasks.
