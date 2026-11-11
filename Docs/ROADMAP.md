# Studio roadmap

The destination is a coherent photo/video development and grading app informed by PeekLUT, Lightroom and selected specialist tools. The current source implements milestone 1 only. Later items are not exposed as nonfunctional buttons.

## 1 — Working photo foundation (0.1)

Local project copies and original preservation; Photos/Files import; Apple-supported RAW decode; immediate GPU previews; light/white balance/color; six original creative looks; simplified tone curves; grain, bloom and fade; sharpening/noise reduction; centered crop/rotation; compare; undo/redo/reset; atomic autosave; Studio presets; full-size SDR JPEG/PNG exports. Complete correctness checks and initial device performance measurements.

## 2 — Precise photo development

Free-position crop, straighten/perspective and lens corrections. Whites/blacks, texture/clarity/dehaze with predictable processing order. RGB curves and levels, HSL ranges, selected-color preview, color wheels and channel mixer. RGB histogram, waveform and vectorscope that update at a bounded rate only while visible. Numeric inputs, accessible adjustable controls and iPad keyboard shortcuts. Validate RAW camera fixtures, wide-gamut/HDR interpretation and export matching before adding HDR output.

## 3 — Reusable grades and film

Strict .cube parsing (domains, ranges, sizes), managed input/working/output transforms, LUT stacking with strength, LUT export for compatible global color operations, and separate full-recipe export for effects that LUTs cannot carry. Build film density/print response, luminance-aware grain and physically motivated halation independently of bloom. Measure effect scale consistency across preview/export. Define a versioned Camera/Studio shared-look contract before either app claims exchange compatibility.

## 4 — Selective edits and workflow

Brush/linear/radial and color/luminance masks with invert, feather, add/subtract and overlays. Then on-device subject/sky selection, healing and carefully bounded advanced noise reduction. Multiple versions, favorites/ratings, project recovery, batch copy/paste, batch export and explicit file-management/export-metadata settings. Preserve offline ownership and avoid mandatory cloud setup.

## 5 — Video grading

Apply the validated grading model to photo and video with managed Log transforms, 10-bit fidelity where supported, temporal stability, trimmed clips, efficient playback, cancellation/progress and HEVC/H.264/ProRes exports subject to hardware. Stress thermal/memory behavior before release. A mobile grading workflow, not a full video timeline editor.

## Performance release gates

- No expensive image decode, file encode or original-size render on the UI actor.
- Newest-slider-state wins; bounded GPU work; no rendering after settling or behind inactive views.
- Document measured p50/p95 response, memory and dropped/stale frames on device. Do not equate render duration alone with touch-to-display latency.
- Keep output quality independent of preview resolution. Validate geometry, orientation, color space and metadata policy with fixtures.
- Test 12/24/48MP photos, multiple supported RAW cameras, interrupted imports/exports, low storage and limited/denied permissions.
- Sustained editing and export tests from a cool device; compare energy/thermal behavior across devices, not just a simulator.
- No guarantee of zero heat or lag; measurements determine supported performance claims.
