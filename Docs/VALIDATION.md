## 0.39.0, build 43 — Look library

Native library/preset compatibility, embedded LUT round-trip, metadata-only writes, split packages, duplicate handling, cancellation and rendering equivalence passed. Compact core and interaction checks cover organisation, reopening and both entry points. Native preview/export regression passed; sustained preview rendered 1,896 frames with 25.25 ms p95 GPU completion, zero failures/idle frames and nominal sampled thermal state throughout. [Reports and limits](Verification/0.39.0/README.md).

## 0.38.0, build 42 — Precision masks

Native zoom-coordinate/export alignment, tapped-subject and People inference, detailed portrait/landscape tracking and animated delivery regressions passed. Three UI workflows passed with a compact repeat, including a fixed high-zoom photo touch interaction. The sustained zoom run rendered 1,891 frames with 24.65 ms p95 GPU completion, zero failures/idle frames and nominal sampled thermal state throughout. [Reports and limits](Verification/0.38.0/README.md).

## 0.37.0, build 41 — Tracking corrections

Native corrected portrait/landscape video exports, animation/HDR/audio, versions, backups and queued/direct exports passed. Three UI workflows and a compact-screen repeat passed, including a repaired slider Undo defect. The sustained native run rendered 1,885 frames with 24.67 ms p95 GPU completion, zero failures/idle frames and nominal sampled thermal state throughout. [Reports and limits](Verification/0.37.0/README.md).

## 0.36.0, build 40 — Video keyframes

Native math/HDR/video/audio, animated backup/queue and compatibility regressions passed, plus four UI workflows and a compact-screen repeat. The sustained animation run completed 1,882 frames with 24.49 ms p95 completion, no GPU failures/idle frames, and fair thermal state throughout sampled checks. [Reports and limits](Verification/0.36.0/README.md).

## 0.35.0, build 39 — Backup fix and export queue

Actual-device path audit: 4/4 previously rejected asset paths now pass. Symlink-root 21-project/two-part backup, native queue lifecycle and core regressions passed, with five UI workflows passing across targeted retests. The native queue run ended at fair iOS thermal state after repeated tests; no no-heat guarantee is made. [Reports and limits](Verification/0.35.0/README.md).

## 0.34.0, build 38 — Portable project backups

Native/compact backup round-trip, damaged-file rejection and mid-stream cancellation checks passed, together with native core regression and the corrected backup UI workflows. The 128 MiB native streaming check retained nominal iOS thermal state, with 27.36 ms maximum main-actor wake interval including the requested 16 ms sleep. [Reports and limits](Verification/0.34.0/README.md).

## 0.33.0, build 37 — Color Warp and delivery

Native color/export and full Studio/video regressions, compact simulator correctness and five UI cases passed. The sustained native preview completed 1,799 renders for 1,800 updates with 26.74 ms p95 completion, no GPU failures or idle draws, and nominal iOS thermal state. [Reports and limits](Verification/0.33.0/README.md).

## 0.32.0, build 36 — Reference matching and Empty Bin

Native reference/photo/video/storage checks and eight distinct UI cases passed, including the corrected bin confirmation flow. [Reports and limits](Verification/0.32.0/README.md).

## 0.31.0, build 33 — Photo backgrounds and development

Native iPhone 17 Pro photo/video regression, real DNG development/export, 10-bit HLG still roundtrip, replacement/cache/history/pool delivery checks and 29 distinct UI cases passed. A 1,800-update graded-cutout/background preview run recorded 23.94 ms p95, no GPU failures or idle draws, and nominal iOS thermal state throughout. Compact simulator checks also passed; no older physical-device performance claim is made. [Reports and test limits](Verification/0.31.0/README.md).

# Validation

## 0.11.0, build 12 — Linear/radial local masks

Native iPhone 16 Pro and simulator references passed for radial center/outside weights, continuous feathering, complementary inversion, linear gradient direction, region-only exposure and linear strength blending. Neutral/disabled layers bypass processing. Masks round-trip with recipes, default neutrally for older projects, remain excluded from reusable presets/clipboard copies, and survive destination pastes. Decode/render counts are bounded to four layers. Invalid numeric shape values are clamped before rendering.

Masked PNG export retained the local adjustment and neutral channel balance, without the red guide, and preserved source bytes. Encoded video checks applied one-stop exposure inside a radial region while leaving outside pixels unchanged. Existing photo geometry/color/LUT/migration and native trim/HDR/audio checks remained green. Complete-version persistence now includes masks in its snapshot fixture.

The actual mask panel exercised four-layer creation, 180 position/exposure/inversion/guide updates, deletion and undo on device and simulator. It preserved the initial recipe/history afterward and created no second player loop. The native maximum main-actor wake-up interval was **76.10 ms** (including a requested 16 ms sleep), not measured touch-to-display latency.

The optimized 16 Pro sustained test combined **1080p/30 fps Log 2 playback**, HDR preview, trim, a 65-point LUT, scopes, moving split comparison, **four active mask layers** and a visible mask guide, with 7,200 grading/position changes. Across **128.27 seconds**, it completed **7,424 renders**, decoded **3,647 frames**, and ran **603 scope jobs**. GPU submission-to-completion p95 was **14.09 ms**, with **0 GPU failures**, **0 extra settled idle frames** and **0 scope jobs after hiding**. Scope worker-to-main-return p95 was **18.31 ms**, including scheduling. Thermal state was **nominal → nominal**. This is not touch-to-display latency, measured presentation FPS, a temperature/energy benchmark or a complex real-camera/long 4K test; the generated fixture has constant colors.

Masks are applied after global grading and framing. They follow normalized positions in the current cropped frame; they do not track subjects, animate with keyframes or provide brush/AI selection yet. Source-specific masks remain with complete versions but are excluded from reusable grades. Filter warm-up runs on the decode worker; guides/scopes stay out of export recipes.

[Native mask/PNG references](Verification/0.11.0/iPhone16Pro-photo.json) · [Native masked video](Verification/0.11.0/iPhone16Pro-video.json) · [Native mask UI](Verification/0.11.0/iPhone16Pro-mask-ui.json) · [Four-layer sustained test](Verification/0.11.0/iPhone16Pro-four-masks-preview.json) · [Simulator photo](Verification/0.11.0/Simulator-photo.json) · [Simulator video](Verification/0.11.0/Simulator-video.json) · [Simulator mask UI](Verification/0.11.0/Simulator-mask-ui.json)

## 0.10.0, build 11 — Selective adjustment copy/paste

Native iPhone 16 Pro and simulator checks passed for all ten selectable sections, full-grade paste, unselected-section retention, empty-paste no-op and neutral LUT clearing. Destination crop/geometry/rotation/straighten/position, input conversion/exposure, trim and HDR choice stayed intact. Partial copy excluded unselected LUT/source data; the complete copied LUT snapshot reopened intact, stayed unchanged after editing the source, was excluded from project indexing and cleared correctly. Isolated application-action tests exercised Copy, Paste, Undo, Redo and Clear through the same methods used by the UI.

The actual Copy and Paste panels were populated with all ten sections and presented/dismissed five times each on device and simulator, with ten distinct panel lifetimes and no new video-player creation loop. The diagnostic restores/clears only its temporary seeded clipboard and does not paste into the user's project. Full photo regression and existing native video trim/HDR/audio checks remained green.

This feature adds no rendering stage: copy stores a filtered immutable recipe once, and paste changes the existing recipe in a single undo transaction. Storage encoding/decoding happens on the project-vault actor. Preview/scopes pause behind the panels. No new sustained thermal or energy claim is made for this workflow-only update; the earlier renderer measurements remain documented below.

[Native copy/paste contracts/actions](Verification/0.10.0/iPhone16Pro-photo.json) · [Native populated panels](Verification/0.10.0/iPhone16Pro-transfer-ui.json) · [Native video regression](Verification/0.10.0/iPhone16Pro-video.json) · [Simulator contracts/actions](Verification/0.10.0/Simulator-photo.json) · [Simulator populated panels](Verification/0.10.0/Simulator-transfer-ui.json)

## 0.9.0, build 10 — Split comparison and complete versions

New checks passed for split boundaries at 0%, 25%, 50% and 100%, plus disabled-comparison graph bypass. Immutable snapshot files retained complete recipes (including LUT, input, framing and trim) after later autosaves. Version index reopening, source-byte preservation, deletion and older-project defaults passed. Isolated main-actor tests exercise Save version, Restore, Undo restore and Delete through the same EditSession methods used by the UI.

The optimized iPhone 16 Pro diagnostic combined **1080p/30 fps Log 2 playback**, HDR preview, trimmed playback, a 65-point LUT, scopes and a continuously moving split divider with **7,200 grading changes**. Over **127.91 seconds**, it completed **7,413 renders**, decoded **3,642 frames** and ran **601 scope jobs**, with **0 GPU failures**, **0 extra settled frames** and **0 scope jobs after hiding**. GPU submission-to-completion p95 was **13.05 ms**; scope worker-to-main-return p95 was **14.33 ms** including scheduling. Thermal state was **nominal → nominal**. This is not touch-to-display latency, measured presentation FPS, a physical-temperature/energy benchmark or a complex real-camera/long 4K test.

Comparison is a preview-only composite of two graphs from the same frame, in one Metal submission, with matching framing. It never creates a second video player or enters the export recipe. Named versions are source-specific immutable recipe files; only the metadata index accompanies normal project autosave. They do not duplicate media. Restore is undoable, while confirmed deletion removes that saved snapshot. Up to 20 versions can be retained per project.

The full native/simulator photo suite passed; five distinct Versions-panel presentations completed with no new video players. The five-cycle Trim regression remained green. UI diagnostics wait for the parent editor transition to settle before presenting child sheets. The normal Release archive passed compilation and strict signature verification.

[Native photo/version actions](Verification/0.9.0/iPhone16Pro-photo.json) · [Native Versions panel](Verification/0.9.0/iPhone16Pro-versions-ui.json) · [Native Trim panel](Verification/0.9.0/iPhone16Pro-trim-ui.json) · [Simulator photo/version actions](Verification/0.9.0/Simulator-photo.json) · [Simulator Versions panel](Verification/0.9.0/Simulator-versions-ui.json) · [Native split/scopes stress report](Verification/0.9.0/iPhone16Pro-split-scopes-preview.json)

## 0.8.0, build 9 — Scopes and geometry

RGB histogram bin references and the HDR linear 0–8× scale passed, alongside waveform/vectorscope raster generation. Thirty-six combinations of rotation, horizontal/vertical perspective and free crop rendered without transparent interior corners. Independent crop dimensions, mirrored-pixel references, legacy defaults, reset/active dots, recipe persistence and creative-preset isolation are covered. The full photo suite and existing video trim/HDR/audio/geometry checks remained green.

The optimized iPhone 16 Pro sustained test ran **1080p/30 fps Log 2 playback**, a trimmed range, HDR preview, a 65-point LUT and continuous grading with scope analysis enabled. Across **128.69 seconds**, it completed **6,893 renders**, decoded **3,661 frames**, and completed **601 scope jobs**, with **0 GPU failures**, **0 scope jobs after hiding**, and **0 extra settled idle frames**. GPU submission-to-completion p95 was **16.98 ms**; scope worker-to-main-return p95 was **14.80 ms**, including scheduling. These are not touch-to-display latency or measured presentation FPS. Thermal state was **nominal → nominal**. No physical temperature or battery-energy benchmark was recorded; generated constant-color footage is not a complex real-camera/long 4K benchmark.

Scopes use a 128×72 graded sample at no more than 5 Hz. They are preview guides, not full-resolution/sensor scopes, and may miss tiny clipped areas. HDR uses a fixed 0–8× SDR-white scale; values above it land at the ceiling. Vectorscope chroma normalizes super-white brightness. Geometry changes intentionally discard some edges during perspective correction. Free crop uses independent size sliders and framing drag/position controls; draggable crop-corner handles are future work.

The final native photo/geometry suite and five Trim-sheet open/adjust/close cycles also passed. Normal Release compilation/archive and strict signature verification passed.

[Native photo/geometry](Verification/0.8.0/iPhone16Pro-photo.json) · [Native Trim lifecycle](Verification/0.8.0/iPhone16Pro-trim-ui.json) · [Native scope playback report](Verification/0.8.0/iPhone16Pro-scopes-HDR-preview.json) · [Native video regression](Verification/0.8.0/iPhone16Pro-video.json) · [Simulator photo/geometry/scopes](Verification/0.8.0/Simulator-photo.json) · [Simulator Trim lifecycle](Verification/0.8.0/Simulator-trim-ui.json)

## 0.7.1, build 8 — Trim presentation freeze

The 0.7.0 freeze was reproduced by opening the actual Trim sheet in the simulator. A main-thread sample showed repeated Form/collection-view layout, `VideoPreview.onDisappear → VideoPlayback.clear`, and player construction during presentation. The UI heartbeat remained stuck at the first opening. The live preview now sits outside the recycled Form cells in a stable sibling view; the form contains only trim controls.

A new `--verify-trim-ui` Debug check opens the video editor, presents/dismisses Trim five times, changes and restores endpoints, and measures main-actor task wake-up delays. It asserts five actual sheet appearances, at most six player constructions (one editor plus five sheets), and no heartbeat stall of one second or more. Existing video edits are restored after the check. This exercises the real sheet lifecycle, not only export math; it is not an automated physical-touch test.

On iPhone 16 Pro: **5 sheets / 6 players / 450 heartbeat samples**, p95 wake-up interval **18.24 ms**, maximum **118.01 ms**; the test passed. These intervals include a requested 16 ms sleep and do not measure touch-to-display latency. No new thermal claim is made for this short interaction check.

The simulator also completed five presentations with six player constructions; the existing native trim/HDR/video export suite passed again. Normal Release archive and strict signature verification passed.

[Native Trim interaction report](Verification/0.7.1/iPhone16Pro-trim-ui.json) · [Simulator Trim interaction report](Verification/0.7.1/Simulator-trim-ui.json)

## 0.7.0, build 7 — Video trim, HLG HDR and safe-area header

Native iPhone 16 Pro correctness checks passed:

- A generated two-second clip trimmed to 0.20–1.30 seconds exported **33 frames / 1.10 seconds**, with a zero-based video timeline and both audio tracks aligned. Trim/HDR settings persist with the project, default neutrally in older recipes and stay out of creative presets.
- Five neutral extended-linear vectors (0, 0.18, 1, 4 and 8) survived HDR grading. Apple Log 2 highlights at four times SDR white survived 10-bit HLG export and a second HDR decode/re-export. Encoded HLG metadata, removal of the Log tag and actual **10-bit** component depth were checked, even when the caller requested eight-bit export.
- A generated PQ input was recognized and converted to HLG while retaining the same bright-highlight level. This is plain HLG output, not preservation of Dolby Vision/HDR10+ dynamic metadata.
- Existing native standard/Apple Log/Log 2 metadata, color, orientation, 4K crop, alternate eight-bit export, frame timing, multiple audio tracks, source preservation, cancellation and project reopening checks remained green.

The optimized 16 Pro test looped a **1080p/30 fps Log 2 generated fixture**, with **HDR preview and a trimmed playback range** enabled. It requested **7,200 grading changes** with a 65-point LUT, wheels, mixer, exposure, Daylight, grain and bloom. Over **130.92 seconds**, it decoded **3,708 frames**, completed **7,408 renders**, recorded **0 GPU failures** and **0 extra idle frames**. GPU submission-to-completion p95 was **14.46 ms**; this is not touch-to-display latency or measured presentation FPS. Thermal state was **nominal → nominal**. No temperature/energy sensor benchmark was recorded, and the fixture is constant-color, not complex real-camera footage or a long 4K stress test.

The editor now explicitly reserves the current window's safe insets before laying out its header. A Debug-only probe measures the header's actual rectangle relative to the window safe area after four export-sheet open/close cycles. The inset reader refreshes on window layout, safe-area changes and foregrounding. This fixes header placement without using a fixed notch-height assumption.

The full native and simulator photo suites passed, including legacy migrations, color/LUT references, geometry and 12/24/48MP synthetic exports. The final native and simulator header probes both measured **header Y = safe top = 62 points**, after repeated Export-sheet presentation. Normal Release archive compilation and strict signature verification passed.

Reports: [Native photo regressions](Verification/0.7.0/iPhone16Pro-photo.json) · [Native header placement](Verification/0.7.0/iPhone16Pro-header-layout.json) · [Simulator photo](Verification/0.7.0/Simulator-photo.json) · [Simulator video](Verification/0.7.0/Simulator-video.json) · [Simulator header](Verification/0.7.0/Simulator-header-layout.json) · [Native video/trim/HDR correctness](Verification/0.7.0/iPhone16Pro-video.json) · [Native HDR playback stress](Verification/0.7.0/iPhone16Pro-HDR-preview.json).

## 0.6.0, build 6 — Log input and single-clip video

Passed on the black iPhone 16 Pro:

- Apple Log/Log 2 inverse-curve anchors, 16 extended linear-color vectors for both gamuts, exposure/alpha, optional SDR highlight shoulder, Standard bypass, persistence and input/preset isolation.
- Generated native 10-bit HEVC fixtures for standard, Apple Log and Apple Log 2; native metadata detection, portrait orientation, bounded poster size, preview/export colors against numeric references, project reopening, cancellation and unchanged source bytes.
- All 18 source video frame presentation timestamps retained in each clip. All compressed audio payload hashes retained, including two audio tracks in the standard fixture. Export duration remained within 50 ms of the source.
- Alternate 8-bit HEVC export matched the preview. A 3840×2160 Log 2 source exported a 2160×2160 crop with all three frames retained.
- AVPlayer's decoded Log 2 frame matched the same reference used for export.

The optimized device diagnostic played a **1920×1080, 30 fps, 10-bit Log 2 generated clip** in a loop, while requesting **7,200 edits** to input exposure, a **65-point LUT**, global exposure, wheels and mixer with Daylight, grain and bloom enabled. During **131.29 seconds**, it decoded **3,719 frames**, completed **7,562 renders**, recorded **0 GPU failures**, and rendered **0 extra frames** during a three-second settled pause. Submission-to-GPU-completion p95 was **13.23 ms**. It is not touch-to-display latency or measured presentation FPS. Thermal state was **nominal → nominal**; no temperature sensor, energy/battery benchmark or complex long real-camera/4K playback test was captured. These generated constant-color clips do not establish performance for every codec, device or scene.

The complete native iPhone 16 Pro and simulator photo suites also passed, including legacy projects/presets, all color tools, LUT validation, JPEG/PNG color matching, 400 geometry edge fixtures and synthetic 12/24/48MP exports. See raw reports below. Normal Release compilation/archive and strict code-signature verification passed; diagnostics are Debug-only.

[Native video correctness](Verification/0.6.0/iPhone16Pro-video.json) · [Native playback stress](Verification/0.6.0/iPhone16Pro-video-preview.json) · [Simulator photo regressions](Verification/0.6.0/Simulator-photo.json) · [Native photo regressions](Verification/0.6.0/iPhone16Pro-photo.json)

To rerun, use a Debug build with `--verify-video-suite`, or `--verify-video-preview --sustained-preview` for the foreground playback test. Reports are written to the app's Documents directory. Fixtures/exports use temporary isolated files and do not save anything to Photos. Existing `--verify-studio` photo checks remain available. Keep the phone foreground/unlocked during the sustained test.

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

## Color and luminance masks — 0.13.0

[Versioned test evidence](Verification/0.13.0/README.md) covers simulator and physical iPhone 17 Pro pixel references, persistence, rendered-view updates and encoded exports. New checks verify hue wraparound/neutral protection, soft brightness ranges, a stable pre-local reference, preview-only guides, and HDR normalization/headroom. The existing `--verify-studio --verify-video-suite --verify-mask-ui` flags run these checks; `--verify-video-preview --sustained-preview` exercises changing color/luminance masks alongside brush painting, HDR playback, a LUT, scopes and split comparison.

## Mask combinations and slider reset — 0.14.0

[Versioned evidence](Verification/0.14.0/README.md) includes combined-mask pixel references, dependent brush preparation, source preservation, photo/video export matching and reset defaults/undo. `--verify-studio --verify-video-suite --verify-mask-ui` runs the regression checks; `--verify-video-preview --sustained-preview` exercises all three combination operations during HDR playback. The simulator-only [real-gesture harness](../Tests/SliderGestureQA/README.md) checks native double taps, normal dragging and the actual editor’s reset/Undo behavior.

## Video mask tracking — 0.15.0

[Versioned evidence](Verification/0.15.0/README.md) covers native/simulator moving-target tracking, portrait/landscape orientation, exact encoded frame counts, moved local adjustments, cancellation, persisted motion and crop/trim guards. The simulator gesture harness now also drags the real target box, resets it, analyzes and clears a track. `--verify-video-suite --verify-studio --verify-mask-ui` runs full regressions; `--verify-tracking-only --portrait-first` isolates tracking with the opposite fixture order. `--verify-video-preview --sustained-preview` checks saved tracked-mask playback alongside combined masks, HDR, LUTs and scopes. Progress/launch files are Debug-only; normal Release has no automatic diagnostic work.

## Automatic Subject/Sky masks — 0.16.0

[Versioned evidence](Verification/0.16.0/README.md) covers persisted soft mattes, real model inference, edge refinement, export matching and cancellation. `--verify-automatic-only` runs isolated math/inference checks; `--verify-studio --verify-video-suite --verify-mask-ui` covers full regressions. Subject inference requires the native Vision environment; simulator checks run bundled sky inference and mask math. `--verify-video-preview --sustained-preview` measures cached automatic-matte playback/refinement and asserts no repeated inference. The real-gesture harness includes creation, refinement/reset and cancel preservation. Model provenance/licenses are in [MODELS.md](MODELS.md).

## 0.17.0, build 18 — Direct crop handles

Simulator and optimized iPhone 17 Pro checks passed 288 corner fixtures across portrait/landscape/4K source dimensions, four rotations, straightening, Free/Original/fixed ratios and every corner. Fixtures verify opposite-corner anchoring, aspect locks, extreme-drag bounds, save/reopen, reset, preset isolation and agreement with full-source export geometry. Pre-0.17 geometry decodes with a neutral scale; existing automatic-mask/tracking signatures remain identical at default scale. Changing scale invalidates those source-specific selections as other framing changes do.

The actual editor touch suite passed **5 tests**, including corner resizing, frame dragging, fixed ratio locking, one-step undo/redo, slider reset/drag, tracking and automatic selection refinement. The crop workspace was visually inspected for control overlap. [Actual crop workspace](Screenshots/CropHandles.png).

On the iPhone 17 Pro, **180 crop updates** caused **0 image re-renders**, **0 settled idle renders**, **0 extra video players** and **0 GPU failures**. Maximum main-actor wake interval was **27.24 ms**, including a requested 16 ms sleep. Thermal state remained **nominal → nominal**. This brief crop test measures avoided work and scheduling, not touch-to-display latency, energy use or a guarantee of zero heat. Simulator measurements also passed. Global grades remain visible in the full-image workspace; local masks/scopes and video transport are hidden there, with playback paused, so moving the frame requires no repeated grading. Other tools restore final framing and local adjustment previews.

Native encoded checks passed Standard, Apple Log and Log 2, portrait/landscape, audio preservation, cancellation, local/automatic/tracked masks, trimmed output and 10-bit HLG. A **3840×2160 Log 2 source** corner-resized to **1860×1860** exported at that exact size with all 3 fixture frames. Existing full-size square crop still exported at 2160×2160. The Release archive built successfully and passed strict code-signature verification.

[Native crop UI](Verification/0.17.0/iPhone17Pro-crop-ui.json) · [Native photo](Verification/0.17.0/iPhone17Pro-photo.json) · [Native encoded video](Verification/0.17.0/iPhone17Pro-video.json) · [Touch tests](Verification/0.17.0/Simulator-gestures.json) · [Simulator photo](Verification/0.17.0/Simulator-photo.json) · [Simulator crop UI](Verification/0.17.0/Simulator-crop-ui.json)

## 0.18.0, build 19 — Crop export repair, fitted previews and detail controls

Automatic Subject/Sky selections now retain an immutable original matte and transform it into the changed crop on a background worker. This includes legacy 0.16/0.17 selections, Free/fixed/Original crops and saved subject translations. No AI inference runs for crop-only changes; expanding a crop reads the original matte again instead of resampling a previously trimmed mask. Export repairs its captured recipe immediately, even before the delayed preview update. Unused masks do not trigger new analysis or block exports. Different rotations/perspectives or a changed first-kept video frame use a fresh on-device selection for required masks; this resets that selection’s old position track. Other Brush/Radial tracks still keep their existing incompatible-framing guard.

Native and simulator correctness checks passed automatic-mask crop export dimensions and selected/unselected pixel references, source preservation, crop expansion, mask/anchor persistence, tracking rescaling and inactive-mask export safety. Native encoded video checks passed repaired crop mattes, frame counts, source audio, SDR/Log/Log 2, HDR and trim. The full simulator touch suite passed **7/7 tests**: immediate automatic-mask crop export and detail reset; automatic refinement and cancellation; corner resize/move/ratio/undo; shared slider reset/drag; editor undo/reset; tracking; and playback reveal/auto-hide. Refinement scrolls into view in the shorter control panel; accessibility exposes playback actions individually.

After a completed crop gesture, the full-image workspace animates into a fitted crop after **2 seconds**, then shows the final local adjustments. Adjust crop returns to the handles. Phone controls use at most 30% of the editor’s available height; Expand preview hides the control panel. Video playback controls appear on tap and hide after three seconds, with auto-hide suspended during scrubbing. Actual fitted/expanded photo and video screenshots were reviewed for control collisions. Export resolution remains independent of preview size.

Native 17 Pro crop check: **180 updates**, **0 image renders during dragging**, **1 fitted-result render**, **0 settled idle renders**, **0 additional players**, **0 GPU failures**, maximum main-actor wake interval **25.67 ms** including the requested 16 ms sleep, thermal **nominal → nominal**.

Texture and Clarity use luminance-only fine/broad contrast with two resolution-scaled Gaussian inputs; unused stages bypass their blur. Native/simulator references passed positive/negative effect direction, neutral bypass, uniform HDR headroom/alpha, preview/export scale, persistence, reset, defaults and adjustment copy/paste. The stages sit after LUT/noise reduction and before sharpening/film texture; they do not claim camera-profile correction or AI enhancement.

The native 17 Pro sustained photo test combined these detail controls with curves, color mixing, wheels, a 65-point LUT, grain, bloom and framing. **7,200 requested updates** across **128.86 seconds** produced **7,115 coalesced renders**, GPU completion p95 **13.91 ms**, **0 GPU failures** and **0 extra settled idle frames**. Thermal remained **nominal → nominal**. These are generated/owned-fixture checks and GPU scheduling measurements, not measured touch-to-display latency, device temperature or a guarantee about every large RAW/4K workload. Full export and video checks remain separate. The Release archive built and passed strict signature verification.

[Native correctness](Verification/0.18.0/iPhone17Pro-photo.json) · [Native crop fit](Verification/0.18.0/iPhone17Pro-crop-fit-ui.json) · [Sustained detail preview](Verification/0.18.0/iPhone17Pro-sustained-detail-preview.json) · [Native encoded video](Verification/0.18.0/iPhone17Pro-video.json) · [Simulator correctness](Verification/0.18.0/Simulator-photo.json) · [Seven touch tests](Verification/0.18.0/Simulator-gestures.json)

## 0.19.0, build 20 — Quicker crop fit, playback fade and Dehaze

Crop fitting now starts after a **700 ms** quiet period and uses a **400 ms** ease-out timing curve without bounce, with a later settled render handoff. Explicit Adjust crop holds the handles open until another adjustment starts. Pending fitting cancels on another crop, tool change, backgrounding or export. Reduce Motion disables the geometric zoom. Playback transport has an explicit **280 ms opacity transition** for showing and hiding, without moving the video or other controls; it still remains visible during scrubbing. Reduce Motion uses a shorter fade.

Native and simulator Dehaze references passed positive/negative veil correction, brighter washed-out tone separation, white/black protection, uniform HDR headroom, alpha, zero-value bypass, reset, migration, preset persistence and adjustment copy/paste. Full-source PNG export matched the rendered photo reference and preserved source bytes. Native Standard, Apple Log and Log 2 HEVC exports with Dehaze matched their preview references while preserving frame counts and original audio. Existing mask crop repair, trim/HDR and tracking checks passed.

The **7/7** simulator touch tests passed immediate cropped-mask export, all crop gestures/ratios/undo, Dehaze adjustment and double-tap reset, automatic refinement, shared slider gestures, tracking and playback reveal/auto-hide. The Dehaze screenshot was inspected with the larger preview and current panel layout. The Release archive built and passed strict code-signature verification.

The native faster crop check passed 180 updates with **0 drag image renders**, **1 fitted-result render**, **0 settled idle image renders**, **0 additional players** and nominal thermal state. Dehaze is a manual dark-channel-weighted GPU correction before creative looks/LUTs, with no CPU readback, extra blur, semantic inference or persistent analysis loop. It is not a camera lens profile or reconstruction of missing scene detail.

Native 17 Pro sustained grading included animated Dehaze, Texture/Clarity, a 65-point LUT, color curves/mixing/wheels, grain, bloom and framing. Across **130.04 seconds**, **7,200 updates** produced **6,598 coalesced renders**, GPU completion p95 **15.53 ms**, **0 GPU failures** and **0 extra idle frames**, with thermal state **0 → 0** (0 = nominal). These owned/generated-fixture checks do not measure touch-to-display latency, device temperature or performance on every RAW/4K workload.

[Native correctness](Verification/0.19.0/iPhone17Pro-photo.json) · [Native encoded video](Verification/0.19.0/iPhone17Pro-video.json) · [Faster crop fit](Verification/0.19.0/iPhone17Pro-crop-ui.json) · [Sustained Dehaze](Verification/0.19.0/iPhone17Pro-sustained-dehaze.json) · [Seven touch tests](Verification/0.19.0/Simulator-gestures.json) · [Simulator correctness](Verification/0.19.0/Simulator-photo.json)

## 0.20.0, build 21 — Levels and workspace organization

This larger release bundles Levels, favorites, 0–5-star ratings, project-name search, media/favorite/rating filters and persistent library sorting. All are functional and save locally; none writes organization back into the original Photos/Files item or exported media.

Native/simulator checks passed numeric Levels mapping, neutral bypass, white/black-point separation, invalid-number safety, HDR white headroom, alpha, legacy defaults, preset/clipboard persistence, reset and full-source PNG reference matching. Native HEVC exports with Levels active passed Standard/Apple Log/Log 2 preview-color references, frame counts, orientation, original audio and existing masked-crop/HDR/trim/tracking checks. The final foreground video rerun passed after an earlier interrupted tracking run.

Organization checks passed favorite/rating save and clearing, reopening from disk, case/diacritic-insensitive search, all media filters, rating/name sorting and a 2,000-project fixture. A stale recipe save preserves the latest organization. Metadata-only writes leave the render timestamp unchanged, so they retain thumbnail cache keys. Actor-cached organization avoids an extra full JSON decode on normal autosaves. Ten native queries over 2,000 project records took **0.0352 seconds** in total; this is metadata query time, not media import or grid presentation latency.

The final combined simulator suite passed **9/9 touch workflows**, covering Levels undo/redo/defaults/reopen; favorites/ratings/search/filter/sort persistence; masked crop export and Detail controls; crop gestures; automatic selection; shared slider reset; tracking; and video transport. A real thumbnail hit-testing overlap was fixed by matching the touch shape to the visible clipped image. The management menu is separate from opening a project. Actual UI screenshots were inspected; the Levels screenshot intentionally uses strong numeric stress settings, not a recommended grade or marketing reference.

Native sustained grading with Levels, Dehaze, Texture/Clarity, curves, wheels, mixer, 65-point LUT, grain, bloom and framing completed **7,200 updates** over **129.55 seconds**, with **6,863 coalesced renders**, GPU completion p95 **14.98 ms**, **0 GPU failures** and **0 extra idle frames**. Thermal state was **fair → fair** (1 → 1). The phone was already warm after preceding checks; this was not a cool-start energy test and does not establish zero heat or measured touch-to-display latency. Preview resolution remains bounded; full export dimensions are unchanged except for the chosen crop.

The signed Release archive built, passed strict signature verification, and was installed and launched normally on the iPhone 17 Pro.

[Native Levels/library references](Verification/0.20.0/iPhone17Pro-photo-library.json) · [Native encoded video](Verification/0.20.0/iPhone17Pro-video.json) · [Sustained Levels](Verification/0.20.0/iPhone17Pro-sustained-levels.json) · [Nine touch tests](Verification/0.20.0/Simulator-gestures.json) · [Simulator references](Verification/0.20.0/Simulator-photo-library.json) · [Levels stress screenshot](Verification/0.20.0/Screenshots/Levels-stress-values.png) · [Workspace screenshot](Verification/0.20.0/Screenshots/Workspace-rated-fixture.png)
