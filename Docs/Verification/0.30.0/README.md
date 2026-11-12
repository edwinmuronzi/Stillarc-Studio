# 0.30 cutouts and grouped pool history — validation

## Completed checks

- Simulator and physical iPhone 17 Pro: soft alpha/transparent RGB, strength/invert/zero bypass, full-size PNG decode/alpha metadata, JPEG rejection, original-byte preservation, crop repair and merging repaired geometry without overwriting live controls, recipe persistence, preset isolation, mixed JPEG/transparent-PNG batch naming and output.
- Native foreground inference on the owned illustrative sample: actual transparent PNG export leaves sampled sky transparent; the selection is reused without inference during grading/export.
- Pool history: a sync changing two destinations is undone/redone as one operation while its already-graded source stays unchanged. Ordinary source edits and syncs undo/redo in chronological order; new edits clear Redo; crop/input/masks and organization remain source-specific. Missing-project preflight fails before writes. Saved before-sync versions remain intact.
- The full 25-case UI suite passed with zero failures. The final source also passed three focused UI cases for crop/export repair, whole-sync Undo/Redo across item navigation, and cutout toggling/transparent export. These exercise the shipping save-order/crop safeguards. Actual cutout UI was visually inspected with a deterministic half-frame matte fixture; that screenshot is not a claim about AI quality.
- Broad processing regression passed on the final source. Full native video/Log/trim/HDR/SDR/mask/tracking regression passed; transparency is deliberately photo-only and HEVC cutout export is rejected rather than silently flattened.
- Native cutout performance check: 1,800 requested and rendered heavy-grade updates, p95 render completion 22.87ms, zero GPU failures, zero extra idle frames over 15 seconds, one foreground analysis, cutout active throughout the run. iOS thermal state began, peaked and ended nominal (0). This approximately 81-second fixture run is not a Celsius/battery measurement or a guarantee for every file/device. Older physical iPhones were not available.
- Signed Release 0.30.0 (32) built; signature and bundled privacy manifest verified. Final installation/launch is checked separately before delivery. No beta or App Store preparation.

## Implementation limits and recovery

Cutout uses the existing finite-resolution selection and cached bitmap. Fine hair, glass, complex backgrounds and multiple foreground objects may need manual refinement. The checkerboard is preview-only; PNG contains alpha. No per-frame video matting or background replacement is implemented. A photo cutout remains an editable recipe on its original, not a destructive source change.

Pool history is bounded to 40 actions during the open pool, survives navigating between its items and is released when the pool closes. Saved Before batch paste versions are the durable fallback afterward. Sync history stores selected-field before/after settings and excludes unchanged/failed destinations. History preflights all destinations, preserves project versions/organization, and attempts rollback on write errors; this is not a crash-atomic multi-file database. Current image pixels stay loaded when undoing; no media is re-encoded. Autosaves and crop repair are paused while history applies, and repaired bitmap geometry merges into current controls by mask identity.

No customer media or private metadata is committed. All pixel fixtures and screenshots use synthetic/owned illustrative content; diagnostics operate in isolated temporary vaults and do not overwrite the saved pool preferences.

Editor snapshot writes reject canceled tasks before committing, intentional cancellation stays silent, and older save completions cannot replace a newer in-memory project. The isolated history regression also verifies that a canceled stale snapshot leaves the stored result unchanged. These guards leave normal import/rollback saves on their existing path.

The delivery source passed an additional two-case UI run for sync Undo/Redo and transparent export after the final snapshot guards. Signed Release 0.30.0 (32) was installed and launched successfully on the iPhone 17 Pro.
