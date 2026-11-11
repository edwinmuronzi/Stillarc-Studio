# Validation

## 0.5.0, build 5 — LUT import and reusable looks

Passed on the black iPhone 16 Pro and simulator:

- Display-sRGB identity, red-fastest channel ordering, non-default domains, endpoints, transparent colors/alpha and strength blending against a linear-light reference.
- Eleven invalid .cube fixtures rejected, including 1D/combined tables, missing/extra rows, nonfinite values, invalid dimensions/domains and unsupported directives. Malformed embedded cube data was rejected.
- A self-contained 65-point LUT preset survived schema-2 serialization with its strength; framing was excluded. Project and saved-look disk persistence, import file reading, LUT undo/redo, Film reset/undo and active-dot state passed. Existing recipe migrations remained intact.
- Range inspection excluded the LUT. Full-size JPEG/PNG sampled exported colors matched the edit render. Existing geometry and 12/24/48MP synthetic gradient exports passed with a 65-point LUT and grading active; these are not complex RAW benchmarks.
- Actual 65-point .cube text parsing and the included 17-point Studio Cool example passed a separate optimized Mac-host check (both parsed in 0.62 seconds combined). That is not an iPhone import-latency measurement.

The optimized black iPhone 16 Pro diagnostic continuously varied a **65-point LUT's strength**, RGB curves, selective color, tonal wheels, channel mixer, exposure and warmth, with a built-in look, grain, bloom, crop and straighten active. It completed **7,200 renders for 7,200 requested updates** over **129.10 seconds**, with **9.83 ms render-completion p95**, **zero GPU failures** and **zero idle redraws**. Thermal state was **nominal at start and end**. These measurements do not establish touch-to-display latency, presented fps, battery energy or physical temperature; longer sessions, real RAW inputs and older physical devices remain unverified.

The signed production Release archive passed strict signature verification and was installed and launched on the black iPhone 16 Pro. Portrait and compact iPhone LUT layouts were visually inspected; system document-picker taps and every touch interaction were not automated. [Raw reports](Verification/0.5.0) and [LUT screenshots](Screenshots/LUTStrength.png) are retained.

## 0.4.0, build 4 — color wheels and channel mixer

Passed on the black iPhone 16 Pro using Metal stitchable functions and on the simulator using the portable Core Image path:

- Four tonal wheels, tonal isolation, Balance/Blend, brightness preservation and neutral black/white protection; exposure-only grading matched the reference exposure filter, including a saturated input above reference white.
- All 12 matrix/offset parameters matched stock CIColorMatrix behavior; negative coefficients, red/blue swap, monochrome and alpha preservation passed.
- Exact fractional hue persistence, recipe/preset round trips, older-recipe migration, section indicators, reset isolation and grading undo/redo passed.
- Range inspection excluded grading; JPEG/PNG sampled export colors matched the normal render. Existing controls and 12/24/48MP synthetic export fixtures also passed with wheels and mixer active. Those fixtures are gradients, not representative RAW benchmarks.

The sustained optimized iPhone 16 Pro diagnostic requested **7,200 changes** and completed **6,504 coalesced renders** over **133.25 seconds**, with wheels, mixer, RGB curves, selective color, film effects and framing active. Render-completion p95 was **11.71 ms**, with **zero GPU failures** and **zero idle redraws**. Thermal state was **nominal at start and end**. The final source also passed a short device run (165 renders; p95 11.50 ms). These are render-completion measurements, not touch-to-display latency, presented fps, battery energy or physical temperature. Longer sessions, real RAW inputs and older physical devices remain unverified.

The normal Release archive passed strict signature verification and was installed and launched on the black iPhone 16 Pro. Compact iPhone, portrait iPhone and iPad layouts were visually inspected; these are not automated touch-interaction tests. [Raw reports](Verification/0.4.0) and [screenshots](Screenshots) are retained.

## 0.3.0, build 3 — RGB curves and selective color

Passed on the black iPhone 16 Pro using the Metal stitchable kernel and on the simulator using the portable Core Image fallback:

- Isolated R/G/B channel changes and Master adjustment at known control points; 2,002 dense spline samples remained finite and bounded. The control graph uses the same shape-preserving curve model as the 1024-sample float tables.
- All 24 selective color components (eight ranges × hue/saturation/brightness) changed their intended swatch while leaving an opposite hue and neutral gray unaffected. Positive/negative hue direction, red wrap continuity and alpha preservation passed.
- Recipe/preset round trips, neutral defaults for older recipes, section reset isolation, and undo/redo of the new color controls passed.
- Temporary range inspection dims unrelated colors before film effects; the normal render and JPEG/PNG export tests remained free of that preview overlay. Sampled exported color matched the edit render within the fixture's JPEG/PNG tolerances.
- Existing geometry, original preservation, 19 legacy controls and 12/24/48MP synthetic export fixtures passed. Those large exports now include RGB and selective-color adjustments. They are simple gradients, not representative RAW benchmarks.

The optimized iPhone 16 Pro sustained diagnostic requested **7,200 changes** and completed **6,693 coalesced renders** over **130.8 seconds**, with RGB curve values and selective hue/saturation changing continuously, plus a look, grain, bloom, straighten and crop. Render-completion p95 was **10.91 ms**, with **zero GPU failures** and **zero idle redraws**. Thermal state was **nominal at start and end**. Render completion is not touch-to-display latency or a guaranteed presented frame rate; no battery-energy or physical-temperature measurement was taken. Real RAW inputs, longer sessions and older physical devices still need coverage.

The normal signed Release archive passed strict code-signature verification and was installed and launched on the black iPhone 16 Pro. [Raw reports](Verification/0.3.0) and current RGB/selective screenshots are retained with this version. Portrait, compact-phone and iPad layout inspection remains a visual check, not an automated tap/drag UI test.


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
