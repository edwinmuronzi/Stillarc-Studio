# Stillarc Studio · 0.40

A local, reversible photo and single-clip video editor for iPhone and iPad. Black-and-blue controls keep the image central.

Develop light and color with Levels, RGB curves, selective color, wheels and channel mixing. Convert supported Log sources before grading; import creative LUTs or save reusable Studio presets. Make targeted changes with gradients, brushes, color/brightness ranges and on-demand subject/sky selections. Position tracking follows a region through a short clip.

Natural grain gives an image fine texture; Halation adds warmth around bright edges; Bloom softens bright areas. Manual lens distortion correction helps straighten bowed lines. Each can be undone, reset or left off.

Trim video and export HEVC SDR or 10-bit HLG HDR, with explicit metadata/privacy choices. Photos export at full remaining source resolution as SDR JPEG/PNG or 10-bit HLG HEIF. Originals stay untouched. Favorites, ratings, batch actions, saved versions and Recently Deleted help organize local work.

<img src="Screenshots/FilmCompact.png" width="280" alt="Actual compact iPhone simulator Film controls"> <img src="Screenshots/FilmIPad.png" width="480" alt="Actual iPad simulator Film controls">

These are actual app UI screenshots using an owned illustrative sample, not camera-output claims. No timeline editing or unvalidated third-party camera-profile database is advertised. Supported RAW lens correction uses Apple’s decoder. Public distribution is not yet available; see the release checklist.


Edit a set in one place: select projects and open an editing pool, browse with a filmstrip, then synchronize chosen color settings across selected items or the whole pool. Refine each image independently afterward. Resume the pool later without duplicating originals.

Subject & Background creates two editable regions with one on-device analysis. Brighten a person while separately dimming or desaturating their surroundings. The red Guide is only a selection overlay. Paired controls edit the two regions separately. Remove background now creates a reversible photo cutout; full-size PNG export preserves transparency.

<img src="Screenshots/EditingPool.png" width="300" alt="Actual Studio editing pool with filmstrip and sync controls using the owned illustrative sample">

Pool sync now has grouped Undo/Redo across the changed items, alongside individual edits. Photo cutouts reuse saved selections and show a checkerboard preview, with edge refinement and alpha-preserving PNG export. Changing-pose video matting remains future work.


Replace a photo background with a color, your own image or a softened original scene. Move, scale, blur and grade the replacement separately. Duplicate/invert selections and adjust local tint, highlights, shadows, clarity and blur without repeating analysis. Existing saved-matte edge controls and brushes refine the boundary.

Develop supported RAW photos with native white balance, exposure, boost and available recovery/noise/lens switches. Reduce color fringing with manual optics controls. Heal/Clone repairs small spots from a clean source patch; full-resolution detail inspection loads a movable tile only when requested. HDR still development preserves available bright detail, while SDR proof shows the JPEG/PNG rendering. HLG HEIF exports require compatible HDR viewers for their full brightness.

Pool delivery now offers Export all or an individual selection. Each item retains its own framing, source settings and repairs. Matching blue arc/S light and dark app icons follow the Home Screen’s supported appearance.


Reference & Match puts a saved visual target beside the current edit. A requested statistical suggestion offers a bounded light/color starting point, with adjustable strength and Undo/Redo. Video uses its first kept frame; HDR is compared as an SDR proof. References remain individual while color corrections can transfer across a pool. The optional vectorscope skin-hue guide gives a visual direction, not a prescribed skin color. Empty Bin is available in Recently Deleted and from its Home long-press menu, with permanent-delete confirmation.


### 0.33 checkpoint
Color Warp adds up to four soft hue/richness controls in the fused GPU color pass, reversible direct-map and slider controls, Color-group sync, schema-5 presets and color-LUT export. Single/pool photo/video delivery adds remembered longest-edge size limits and compression choices, with full-source grading, alpha/HDR preservation and no upscaling. Video color-map editing uses the first kept frame; review playback in the editor. Advanced camera transforms, grade keyframes, portable project packages and an export queue remain later scope. No external beta/store preparation or timeline companion is included.


### 0.34 checkpoint
Portable .stillarc backups now package up to 20 projects with exact originals, source-specific edits/assets, LUTs, masks/tracking, organization and saved versions. Home offers labelled Home Backups button and single/selected-project entry points, separate Back up/Restore modes, persistent progress/cancel controls and safe new-copy restoration. Streaming integrity checks reject damaged/truncated/traversal/unsupported files before commit. Preset libraries, editing-pool membership, global preferences, cloud sync, an export queue, additional camera transforms and grade keyframes remain separate scope. No beta/store work or timeline companion is included.


### 0.35 checkpoint
Fixed backup asset paths across canonical/symlink directory aliases, with an aggregate-only read-only audit of actual device projects. The picker gains bounded photo/video thumbnails and fixed All/selected actions. Back up all writes complete numbered 20-project parts rather than omitting later projects. A persistent serial export queue snapshots per-delivery settings, supports explicit start, foreground pause/retry, ordering, retained completed files and safe removal, and is available from single/batch/pool delivery and Home. Queue work pauses while hidden or inactive; active unfinished work restarts at job boundaries. Additional camera transforms, grade keyframes, source relinking and Camera/Studio shared-look interchange remain separate scope.


### 0.36 checkpoint
Source-time video animation now covers exposure offsets and look/LUT/local-mask strength fades, with bounded points, Linear/Smooth interpolation, live slider preview, seek/add/update/delete/move, source/pool Undo/Redo and portrait/landscape layouts. Frame-time grading is shared by preview, direct/queued export, references and saved-source work. Animation stays out of reusable grades/LUTs; versions and backups retain it. New packages require reader build 40; queue schema 2 preserves animation while still loading earlier records. Additional camera transforms, source relinking, richer tracking correction and shared Camera/Studio look interchange remain separate scope.


**Tracking corrections:** pause a video and shift a drifting tracked mask with a preview handle or two sliders. Source-time points blend those nudges without another analysis; clear them to return to the measured path. Whole drags support Undo/Redo and the same path is used in exports. Position only; review the clip for changes in shape or scale.


**Precision masking:** zoom/pan the preview to work on small details, paint in the same source coordinates, then tap Done brushing to use video playback again. Subject choices isolate all foreground, one tapped object, or people with finer edge matting. Detailed tracking uses a more accurate position tracker, with an Efficient analysis option and a subject-based suggested target. These are on-request, on-device operations; changing-pose video matting remains future work.


**Look library:** find favourites quickly, group saved grades into collections, search/sort/reorder and back up all or selected looks. Portable .studiolooks files carry the LUT itself without including private source media; large libraries use numbered parts. Imports keep existing looks and skip exact duplicates. A small metadata index keeps organisation changes separate from LUT storage.


**Original media recovery:** save a fingerprint of an available original, verify it later, or repair a missing/changed source with an exact matching file. Wrong files are rejected before replacement; project edits and versions stay intact. It runs only on request and uses bounded, thermal-aware streaming. Keep a full project backup as well; a fingerprint cannot recover bytes by itself.
