# Studio roadmap

The destination is a coherent photo/video development and grading app informed by PeekLUT, Lightroom and selected specialist tools. The current source implements milestone 1 and the first part of milestone 2. Later items are not exposed as nonfunctional buttons.

## 1 — Working photo foundation (0.1)

Local project copies and original preservation; Photos/Files import; Apple-supported RAW decode; immediate GPU previews; light/white balance/color; six original creative looks; simplified tone curves; grain, bloom and fade; sharpening/noise reduction; centered crop/rotation; compare; undo/redo/reset; atomic autosave; Studio presets; full-size SDR JPEG/PNG exports. Complete correctness checks and initial device performance measurements.

## 2 — Precise photo development

Implemented in 0.4: Shadows/Midtones/Highlights/Global wheels, balance/blend and tint-brightness protection, plus a 3×3 linear-light channel mixer with offsets, monochrome and red/blue swapping. Per-wheel/output reset, presets, edit dots and undo/redo use the existing reversible model.

Implemented in 0.3: five-point Master/R/G/B curves, exact point values, eight-range HSL-style color controls, per-range reset and a preview-only color-range inspector. Old recipes remain neutral in the new stages.

Implemented in 0.2: active-adjustment indicators, section resets, exact numeric entry, repositioned aspect-ratio crops, straightening and Whites/Blacks. Existing 0.1 recipes migrate with neutral defaults.

Implemented in 0.8: independent free-crop width/height, horizontal/vertical flips, perspective correction and on-demand RGB histogram/waveform/vectorscope for photo/video previews.

Next: draggable crop corner handles and lens corrections; texture/clarity/dehaze with predictable processing order. Levels and freely placed extra curve points. Numeric inputs, accessible adjustable controls and iPad keyboard shortcuts. Validate RAW camera fixtures, wide-gamut/HDR interpretation and export matching before adding HDR photo output.

## 3 — Reusable grades and film

Implemented in 0.5: one display-sRGB 3D .cube LUT, strict size/domain/value validation, live strength, self-contained schema-2 Studio look presets, preserved framing, reset/undo and full-resolution export matching. Immutable imported tables are shared by history; parsing and saving run away from the UI actor.

Implemented in 0.6: explicit Apple Log/Log 2 input conversion, per-source exposure and an optional SDR shoulder before creative grading.

Next: other camera Log and wide-gamut input/output transforms, 1D shapers, LUT stacking, LUT export for compatible global color operations, and separate full-recipe export for effects that LUTs cannot carry. Build film density/print response, luminance-aware grain and physically motivated halation independently of bloom. Measure effect scale consistency across preview/export. Define a versioned Camera/Studio shared-look contract before either app claims exchange compatibility.

## 4 — Selective edits and workflow

Implemented in 0.9: fitted draggable split before/after and up to 20 complete source-specific edit versions, with restore/undo/delete. Snapshots are separate immutable recipe files, not duplicated media.

Implemented in 0.10: persistent internal adjustment copy/paste with ten selectable sections, included LUT data, single-step undo/redo and destination-specific input/framing/trim/HDR preservation.

Implemented in 0.11: up to four linear/radial local adjustments with exposure, warmth, saturation, contrast, feather, inversion, strength and preview-only overlays. Source-specific masks survive project/complete-version saves and remain excluded from reusable presets/clipboard grades. They are anchored to the current frame, without tracking.

Implemented in 0.12: editable soft brush/eraser strokes, Paint/Eraser/View modes, whole-stroke undo/redo and exact full-resolution 16-bit export masks. Preview masks rasterize incrementally off the UI actor; video export reuses static brush maps.

Implemented in 0.13: GPU color and luminance masks with soft transitions, hue swatches, brightness shortcuts, preview guides, source-specific persistence and per-frame video selection.

Implemented in 0.14: previous-mask intersection/addition/subtraction with soft GPU coverage, source-specific persistence and full-resolution export; undoable double-tap reset across slider controls with per-control defaults.

Implemented in 0.15: cancellable forward region tracking for Radial/Brush masks, with normalized timestamped translation, background analysis, persistent/undoable tracks and full-resolution export. No deformation, scale/rotation tracking or manual motion-keyframe editor.

Next: more robust tracking/recovery and on-device subject/sky selection, healing and carefully bounded advanced noise reduction. Multiple versions, favorites/ratings, project recovery, batch copy/paste, batch export and explicit file-management/export-metadata settings. Preserve offline ownership and avoid mandatory cloud setup.

## 5 — Video grading

Implemented in 0.6: single-clip Photos/Files import, playback/scrubbing, shared reversible grading, Apple Log/Log 2 conversion, full-size 10/8-bit HEVC SDR export with original audio/frame timing, progress/cancellation and thermal pacing.

Implemented in 0.7: reversible video trimming with live endpoint inspection, HLG/PQ input, 10-bit HLG HDR export and extended-range video previews. Header safe-area placement now uses the current window insets.

Next: HDR still-photo export, improved HDR creative-tool modeling, scopes and H.264/ProRes exports subject to hardware. Stress thermal/memory behavior before release. A mobile grading workflow, not a full video timeline editor.

## Performance release gates

- No expensive image decode, file encode or original-size render on the UI actor.
- Newest-slider-state wins; bounded GPU work; no rendering after settling or behind inactive views.
- Document measured p50/p95 response, memory and dropped/stale frames on device. Do not equate render duration alone with touch-to-display latency.
- Keep output quality independent of preview resolution. Validate geometry, orientation, color space and metadata policy with fixtures.
- Test 12/24/48MP photos, multiple supported RAW cameras, interrupted imports/exports, low storage and limited/denied permissions.
- Sustained editing and export tests from a cool device; compare energy/thermal behavior across devices, not just a simulator.
- No guarantee of zero heat or lag; measurements determine supported performance claims.
