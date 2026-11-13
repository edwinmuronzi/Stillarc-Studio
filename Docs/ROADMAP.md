# Studio roadmap

The destination is a coherent photo/video development and grading app informed by PeekLUT, Lightroom and selected specialist tools. The current source spans the photo, selective-edit and single-clip video milestones below. Later items are not exposed as nonfunctional buttons.

## 1 — Working photo foundation (0.1)

Local project copies and original preservation; Photos/Files import; Apple-supported RAW decode; immediate GPU previews; light/white balance/color; six original creative looks; simplified tone curves; grain, bloom and fade; sharpening/noise reduction; centered crop/rotation; compare; undo/redo/reset; atomic autosave; Studio presets; full-size SDR JPEG/PNG exports. Complete correctness checks and initial device performance measurements.

## 2 — Precise photo development

Implemented in 0.4: Shadows/Midtones/Highlights/Global wheels, balance/blend and tint-brightness protection, plus a 3×3 linear-light channel mixer with offsets, monochrome and red/blue swapping. Per-wheel/output reset, presets, edit dots and undo/redo use the existing reversible model.

Implemented in 0.3: five-point Master/R/G/B curves, exact point values, eight-range HSL-style color controls, per-range reset and a preview-only color-range inspector. Old recipes remain neutral in the new stages.

Implemented in 0.2: active-adjustment indicators, section resets, exact numeric entry, repositioned aspect-ratio crops, straightening and Whites/Blacks. Existing 0.1 recipes migrate with neutral defaults.

Implemented in 0.8: independent free-crop width/height, horizontal/vertical flips, perspective correction and on-demand RGB histogram/waveform/vectorscope for photo/video previews.

Implemented in 0.17: direct corner resizing, locked aspect ratios, free resizing and frame dragging in a full-image workspace, with one-step gesture undo and retained numeric controls. Crop-only drags reuse the graded image; exports preserve full remaining source resolution.

Implemented in 0.18: background crop repair for automatic selections and their subject motion, delayed fitted crop preview, larger/collapsible editor previews, tap-to-reveal playback, and signed Texture/Clarity controls with resolution-scaled luminance processing.

Implemented in 0.19: a signed live Dehaze control before creative looks/LUTs, quicker crop settling with gentler easing, explicit playback opacity transitions and Reduce Motion support.

Implemented in 0.20: input/output Levels and midtone gamma; favorites, star ratings, name search, media/favorite/rating filters and persistent sorting, with metadata-safe autosave and stable thumbnail cache keys.

Next: lens corrections and freely placed extra curve points. Numeric inputs, accessible adjustable controls and iPad keyboard shortcuts. Validate RAW camera fixtures, wide-gamut/HDR interpretation and export matching before adding HDR photo output.

## 3 — Reusable grades and film

Implemented in 0.5: one display-sRGB 3D .cube LUT, strict size/domain/value validation, live strength, self-contained schema-2 Studio look presets, preserved framing, reset/undo and full-resolution export matching. Immutable imported tables are shared by history; parsing and saving run away from the UI actor.

Implemented in 0.6: explicit Apple Log/Log 2 input conversion, per-source exposure and an optional SDR shoulder before creative grading.

Implemented in 0.27: manual Sony S-Log3/S-Gamut3.Cine and Panasonic V-Log/V-Gamut input transforms; display-sRGB color-only 33/65-point .cube export with explicit exclusions; preset/LUT preset search, rename and duplicate.

Next: more camera Log and wide-gamut input/output transforms, 1D shapers and LUT stacking. Continue testing full-recipe export for effects that LUTs cannot carry. Build film density/print response, luminance-aware grain and physically motivated halation independently of bloom. Measure effect scale consistency across preview/export. Define a versioned Camera/Studio shared-look contract before either app claims exchange compatibility.

## 4 — Selective edits and workflow

Implemented in 0.9: fitted draggable split before/after and up to 20 complete source-specific edit versions, with restore/undo/delete. Snapshots are separate immutable recipe files, not duplicated media.

Implemented in 0.10: persistent internal adjustment copy/paste with ten selectable sections, included LUT data, single-step undo/redo and destination-specific input/framing/trim/HDR preservation.

Implemented in 0.11: up to four linear/radial local adjustments with exposure, warmth, saturation, contrast, feather, inversion, strength and preview-only overlays. Source-specific masks survive project/complete-version saves and remain excluded from reusable presets/clipboard grades. They are anchored to the current frame, without tracking.

Implemented in 0.12: editable soft brush/eraser strokes, Paint/Eraser/View modes, whole-stroke undo/redo and exact full-resolution 16-bit export masks. Preview masks rasterize incrementally off the UI actor; video export reuses static brush maps.

Implemented in 0.13: GPU color and luminance masks with soft transitions, hue swatches, brightness shortcuts, preview guides, source-specific persistence and per-frame video selection.

Implemented in 0.14: previous-mask intersection/addition/subtraction with soft GPU coverage, source-specific persistence and full-resolution export; undoable double-tap reset across slider controls with per-control defaults.

Implemented in 0.15: cancellable forward region tracking for Radial/Brush masks, with normalized timestamped translation, background analysis, persistent/undoable tracks and full-resolution export. No deformation, scale/rotation tracking or manual motion-keyframe editor.

Implemented in 0.16: on-request foreground Subject and Sky selection, saved 16-bit mattes, GPU edge refinement, first-kept-frame video masks and Subject position tracking. No per-frame semantic video segmentation.

Implemented in 0.21: serial multi-item import, per-project batch export, 30-day Recently Deleted with restore, and local project/settings and saved-look recovery. Curves requires an explicit edit mode so scrolling does not alter points; workspace keyboard dismissal and a floating import dock improve navigation.

Implemented in 0.22: thumbnail hold previews with project actions, double-tap favourites, visibly labelled Recently Deleted, selected-project deletion and confirmed delete-all using recoverable local copies.

Implemented in 0.23: bin thumbnails/enlarged poster previews and days remaining; selection-aware hold actions; serial batch paste of chosen copied adjustment groups with per-project before versions.

Implemented in 0.24: immediate selection taps, Home copy/paste with section choices, and selection-aware ellipsis actions including bulk ratings and unfavourite.

Implemented in 0.25: confirmed Home revert to imported source defaults, with a before-revert version and retained detected video input/HDR settings.

Next: more robust tracking, changing-pose segmentation, healing and carefully bounded advanced noise reduction. Additional file-management options. Preserve offline ownership and avoid mandatory cloud setup.

## 5 — Video grading

Implemented in 0.6: single-clip Photos/Files import, playback/scrubbing, shared reversible grading, Apple Log/Log 2 conversion, full-size 10/8-bit HEVC SDR export with original audio/frame timing, progress/cancellation and thermal pacing.

Implemented in 0.7: reversible video trimming with live endpoint inspection, HLG/PQ input, 10-bit HLG HDR export and extended-range video previews. Header safe-area placement now uses the current window insets.

Implemented in 0.26: private-by-default source metadata allowlists, optional date/camera/location, optional silent video, anonymous batch filenames, remembered shared preferences and export-option retry.

Next: HDR still-photo export, improved HDR creative-tool modeling, scopes and H.264/ProRes exports subject to hardware. Stress thermal/memory behavior before release. A mobile grading workflow, not a full video timeline editor.

## Performance release gates

- No expensive image decode, file encode or original-size render on the UI actor.
- Newest-slider-state wins; bounded GPU work; no rendering after settling or behind inactive views.
- Document measured p50/p95 response, memory and dropped/stale frames on device. Do not equate render duration alone with touch-to-display latency.
- Keep output quality independent of preview resolution. Validate geometry, orientation, color space and metadata policy with fixtures.
- Test 12/24/48MP photos, multiple supported RAW cameras, interrupted imports/exports, low storage and limited/denied permissions.
- Sustained editing and export tests from a cool device; compare energy/thermal behavior across devices, not just a simulator.
- No guarantee of zero heat or lag; measurements determine supported performance claims.

## Remaining delivery batches

1. Finish Home workflow: copy/paste/revert, selection actions and recovery regression checks.
2. Export controls (0.26 implemented): metadata/privacy policy, format clarity and interruption/failure handling; continue broader real-world source testing.
3. Color tools (0.27 implemented): two additional Log transforms, LUT/preset management and compatible color-LUT export; broader camera-file validation continues.
4. Photo refinement (0.28 implemented): manual radial lens correction, natural grain with legacy compatibility, and highlight-edge halation; preview/export verification. Automatic calibrated lens profiles remain future work.
5. Release preparation (0.28 candidate): compact/iPad/large-text layout review, regression tests, sustained device performance, privacy manifest, documentation and listing drafts. Broader real-world camera files, older physical devices and public beta remain release gates.

Later tools remain subject to fixture validation and device performance checks; unavailable features should not be advertised as working.


## 0.29 — Editing pool and paired regions

Implemented: persistent pools of up to 20 existing projects, filmstrip/swipe/arrow browsing, per-item editing, selected/all-pool selective sync with recovery versions, safe preview retirement and 160px filmstrip thumbnails. Subject & Background creates two independently adjustable layers from one inference/shared matte, with existing refinement, undo, persistence and export. Video remains first-kept-frame selection plus independent position tracking.

Next: background cutout/removal and clean alpha export; richer local controls and deeper RAW/photo finishing. A live inherited master-grade model, timeline companion and video matting remain separate future work. Beta and App Store preparation remain deferred.


## 0.30 — Photo cutouts and pool history

Implemented: photo background removal reusing an existing foreground selection or one requested analysis; checkerboard preview; reversible cutout selection, edge refinement/strength/invert; alpha-preserving full-size PNG and mixed-batch export. Sync is one pool-wide Undo/Redo step, ordered with normal edits and retained across navigation during the open pool. Saved sync checkpoints remain available after closing it. Crop repair merges repaired geometry without losing live controls; history operations pause deferred/stale saves.

Next: background replacement/compositing and richer local photo tools. Video background removal needs separate temporal matting work. An inherited master-grade model, persistent cross-launch Undo, timeline editing and public distribution remain separate scope.


### 0.31 checkpoint
Static-photo backgrounds and development from proposed batches 2–3 are implemented: solid/image/blurred-original replacement, richer local controls and duplicate, supported RAW decoder settings, manual color-fringe corrections, spot heal/clone, full-resolution tile inspection, HDR still preview/SDR proof and 10-bit HLG HEIF. Pool delivery supports all/selected items. Face/skin masks, advanced denoise and temporally stable video matting remain deferred; native RAW lens profiles appear only when the decoder reports support. See PRODUCT-DIRECTION.md for the next proposed color-workflow batch.


### 0.32 checkpoint
Implemented the first color-workflow tranche: reference comparison/import/project snapshots, one-tap bounded statistical light/color matching with strength/reset/Undo, schema-4 matched presets and Color transfer, first-kept-frame video comparison, plus an optional SDR vectorscope skin-hue guide. Empty Bin is available within Recently Deleted and its Home hold menu, with confirmed-snapshot deletion. Next proposed color work remains flexible color warping and explicit output choices; additional camera transforms and motion keyframes require fixture validation. No timeline app or external beta/store preparation is included.


### 0.33 checkpoint
Color Warp adds up to four soft hue/richness controls in the fused GPU color pass, reversible direct-map and slider controls, Color-group sync, schema-5 presets and color-LUT export. Single/pool photo/video delivery adds remembered longest-edge size limits and compression choices, with full-source grading, alpha/HDR preservation and no upscaling. Video color-map editing uses the first kept frame; review playback in the editor. Advanced camera transforms, grade keyframes, portable project packages and an export queue remain later scope. No external beta/store preparation or timeline companion is included.


### 0.34 checkpoint
Portable .stillarc backups now package up to 20 projects with exact originals, source-specific edits/assets, LUTs, masks/tracking, organization and saved versions. Home offers labelled Home Backups button and single/selected-project entry points, separate Back up/Restore modes, persistent progress/cancel controls and safe new-copy restoration. Streaming integrity checks reject damaged/truncated/traversal/unsupported files before commit. Preset libraries, editing-pool membership, global preferences, cloud sync, an export queue, additional camera transforms and grade keyframes remain separate scope. No beta/store work or timeline companion is included.


### 0.35 checkpoint
Fixed backup asset paths across canonical/symlink directory aliases, with an aggregate-only read-only audit of actual device projects. The picker gains bounded photo/video thumbnails and fixed All/selected actions. Back up all writes complete numbered 20-project parts rather than omitting later projects. A persistent serial export queue snapshots per-delivery settings, supports explicit start, foreground pause/retry, ordering, retained completed files and safe removal, and is available from single/batch/pool delivery and Home. Queue work pauses while hidden or inactive; active unfinished work restarts at job boundaries. Additional camera transforms, grade keyframes, source relinking and Camera/Studio shared-look interchange remain separate scope.


### 0.36 checkpoint
Source-time video animation now covers exposure offsets and look/LUT/local-mask strength fades, with bounded points, Linear/Smooth interpolation, live slider preview, seek/add/update/delete/move, source/pool Undo/Redo and portrait/landscape layouts. Frame-time grading is shared by preview, direct/queued export, references and saved-source work. Animation stays out of reusable grades/LUTs; versions and backups retain it. New packages require reader build 40; queue schema 2 preserves animation while still loading earlier records. Additional camera transforms, source relinking, richer tracking correction and shared Camera/Studio look interchange remain separate scope.


### 0.37 checkpoint
Tracked video masks gain up to 32 manual source-time position corrections, a live preview handle, horizontal/vertical sliders, point deletion/clear and source/pool Undo/Redo. Linear correction offsets preserve the original measured path and travel with versions, backups and direct/queued exports. Compatible automatic-mask crop repair scales corrections with the base track. Adaptive portrait/landscape preview pauses behind sheets and when inactive. New archives require reader build 41; queue schema 3 still reads schemas 1–2. Shape/scale/rotation tracking, video matting, source relinking and shared Camera/Studio look interchange remain later scope. No timeline, beta or App Store work.


### 0.38 checkpoint
Masks gains preview-only 1–6× zoom/pan, fitted source-coordinate painting/shape positioning, fixed-size video transport and a visible Done brushing return to View/playback. Subject analysis adds one tapped instance and accurate People matting; stored masks remain the existing format. Detailed Vision tracking is the default, with Efficient available and a subject-matte suggested target box. Inference remains request-only; no new per-frame model runs or image grading pass. Position tracking does not deform a changing subject. Shape/scale tracking, temporally stable video matting, source relinking and shared Camera/Studio look interchange remain later work.


### 0.39 checkpoint
Reusable look management gains favourites, named collections, search/filter/sort and manual library order, available from Home and the editor. A separate small metadata index avoids rewriting LUTs for organisation changes. Bounded, cancelable .studiolooks library backup/import includes self-contained presets and organisation, splits by count/bytes into numbered parts, preserves existing records and skips exact duplicates. It is separate from source/project backups and does not establish Camera/Studio look interchange. Source relinking, additional camera transforms and temporally stable video matting remain later work; no timeline/beta/store work is included.


### 0.40 checkpoint
Home project menus add source information, request-only fingerprint creation/verification and exact-byte original repair. SHA-256/size matching precedes atomic source publication; non-empty changed copies are retained. Bounded streaming, cancellation cleanup and thermal pacing avoid background/rendering work. Saved edits/versions, video interpretation and audio remain unchanged, and project backups carry fingerprints into restored copies. Legacy projects are not automatically scanned; missing sources without fingerprints require a project backup. This is verified repair, not arbitrary source replacement or timeline conforming. Additional camera transforms, temporal video matting and shared Camera/Studio interchange remain later scope.


### 0.41–0.42 checkpoints
0.41 adds explicit Canon Log 3/Rec.2020, Nikon N-Log/Rec.2020, Fujifilm F-Log2/F-Gamut and DJI X9 native-EI D-Log/D-Gamut; three creative LUT layers with independent strength/bypass/reordering; and nonuniform Master/RGB curves with up to twelve points.

0.42 adds remembered delivery codec choices: H.264 SDR MP4 with mono/stereo AAC, existing HEVC MOV and hardware-supported ProRes 422 10-bit MOV. HEVC/ProRes retain HLG HDR; the interface keeps mixed HDR batches on HDR-capable choices and the engine rejects incompatible stale H.264/HDR requests. Queue schema 5 snapshots codec choices while reading older queues. ProRes uses fixed compression; JPEG/HEIF quality remains available for mixed photo/video deliveries. Export grading, audio timestamps, metadata policy and serial thermal pacing stay shared.

Remaining candidate work: Camera/Studio shared-look interchange, supported 1D shapers, additional validated input/output spaces and richer mask motion. Temporal video matting and a multi-clip timeline remain separate substantial projects. No external beta or App Store work in this batch.


### 0.43 checkpoint
Delivery planning now shows approximate photo/video sizes, shared encoder bitrate budgets, crop/quality/trim/audio-aware estimates, pool totals and per-job/pending queue totals. Finished delivery measures exact file lengths asynchronously. Audio metadata is captured once during new imports, with safe legacy fallbacks. No preview rendering or trial encoding is added. Shared Camera/Studio look interchange, supported 1D shapers and richer mask motion remain later candidates.


### 0.44 checkpoint
Standalone 1D creative .cube imports (2–4096 points/channel) now join existing 3D LUTs, with visible type/size details and matching scalar or per-channel domain headers. Small cached GPU tables retain original samples without 3D expansion. Mixed stacks participate in presets, colour transfer, colour-LUT baking and photo/video/direct/queued export. Schema-7 presets and reader-build-49 packages protect the new data while retaining old 3D fingerprints. Combined technical shaper+cube files, arbitrary working/output spaces and shared Camera/Studio presets remain later candidates.


### 0.45 checkpoint
Tracking correction points now optionally carry uniform size and clockwise rotation as well as translation. New tracks retain the measured target centre and source dimensions. Cached GPU affine transforms reuse the base matte/brush map; compatible automatic-mask crop repairs preserve original off-crop pixels, pivots and pose values without new inference. Undo/redo, deletion/reset, versions, HDR/direct/queued exports and reader-build-50 source backups retain the changes. Queue schema 7 protects the added motion fields. This is manual pose correction, not automatic scale/rotation tracking, mesh deformation or temporal matting.


### 0.46 checkpoint
Manual mask corrections gain a per-mask Linear/Smooth/Hold transition across position, size and rotation. Measured tracking remains linear and separate. Exact nominal-frame stepping and previous/next correction navigation pause playback, retain coalesced seek requests and leave ordinary scrubbing unchanged. Source-time interpolation remains shared by preview, HDR/direct/queued export, versions and reader-build-51 backups; queue schema 8 protects the new transition while reading older records. Automatic silhouette deformation, temporal matting and shared Camera/Studio look interchange remain separate candidate work.


### 0.47 checkpoint
Combined Resolve-style creative .cube files retain original 1D shaper and red-fastest 3D samples as one Film asset. Separate stage ranges, one strength/bypass blend and display-sRGB transfer around the complete pair are shared by photo/video/queued exports, versions, presets and colour-LUT baking. Standalone identities remain compatible. Schema-8 presets, reader-build-52 packages and queue schema 9 protect older readers. Arbitrary technical working/output spaces, Camera/Studio shared presets and temporal matting remain separate candidates. No timeline/beta/store work.


### 0.48 checkpoint — two workflow batches
White-balance patch sampling solves the existing bounded Warmth/Tint controls; Levels black/white-point sampling writes the existing input endpoints. Large adaptive preview sheets freeze the selected video frame, average a small source patch before the appropriate stage, validate unreliable/crossed samples, and support normal source/pool history. Request-only worker sampling cancels on disappearance/inactivity and rejects stale recipes. The main preview and scopes pause behind the picker. Existing persisted field formats and source/colour export paths are unchanged. Arbitrary working/output spaces, Camera/Studio shared looks and temporal matting remain separate candidates.


### 0.49 checkpoint — combined remaining-work release
Colour-only Camera/Studio .cube exchange is implemented in Camera 1.3.7 and Studio 0.49; native recipe/library sync is not included. Explicit sRGB/P3/linear input overrides and tagged sRGB/P3 photo delivery retain a linear-sRGB working pipeline and existing HLG/video output choices. Object-size and rectangular-target rotation tracking preserve separate measured/manual poses. Short People video mattes prepare each source frame once (6 s / 180 frames / 8 MB / 1536 px mask limits), with crop-safe source-time projection and composited video background export. Face/skin landmark-guided starting masks and edge-protected chroma cleanup extend photo finishing. Native RAW lens controls remain decoder/camera dependent; no unvalidated calibration database was added. Source packages require reader build 54; queues use schema 10.

Native 17 Pro, supplied RAW, generated HDR/audio/export, source/queue/backup/history, compact UI, low-space preflight and a 199-second thermal/memory workload passed; exact results and open gates are in Verification/0.49.0. Older physical-device testing, additional real camera files/lens calibrations and difficult real moving-person footage remain open, not marked complete. General object temporal matting, mesh/perspective deformation, arbitrary ACES working/output pipelines and native cross-app preset synchronization remain separate future scope.

## 0.50 checkpoint

Longer bounded People mattes, reversible edge shortcuts, reviewed partial tracking recovery and persisted loss markers. See [the 0.50 workflow guide](FINISHING-050.md). Physical older-device and difficult real occlusion/hair gates remain open; no universal thermal or segmentation claims.
