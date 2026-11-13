# Studio 0.47.0 (52) verification

- Native iPhone 17 Pro combined-LUT checks passed: 33 analytic RGB vectors, separate stage domains, clamping, stage order, single strength blend, transparency, bypass, JSON persistence and distinct fingerprints. Maximum display-RGB sampled error: 0.001961.
- Dense 4096-sample combined .cube write/reimport preserves exact Float values and fingerprints. Preset schema 8, look-library round trip, selective LUT transfer and sampled colour-only export passed. Invalid sizes, duplicate/ambiguous headers, NaNs, incomplete/extra rows and unknown tags were rejected.
- Existing standalone 1D/3D compatibility, interpolation, domain, alpha and mixed-stack checks passed.
- Native combined-LUT video checks passed: HDR headroom, orientation/trim/audio, preview/export agreement, saved versions, source backups and queued/direct export agreement. Preview/export max sampled errors were 0.000539, 0.000664 and 0.001034.
- Simulator broad regression and LUT checks passed. Compact-screen UI test passed for combined type details, visible-slider edits, Undo/Redo and actual photo export. The first two UI attempts targeted an offscreen slider; the final test deliberately scrolls it fully into view and asserts an actual value change before Undo/Redo.

Combined files are display-sRGB creative transforms, not arbitrary Log/HDR/scene-linear input conversions. Film retains original 1D and 3D samples; baking a separate colour-only LUT still uses the existing sampled 3D output. Physical testing used the 17 Pro, not older devices.

Sustained native HDR preview with a 4096-sample shaper + 65³ cube, a standalone 4096-sample 1D layer, another combined LUT layer, flexible RGB curves and four animated/combined masks: 69.2 seconds, render p95 28.74 ms, 0 GPU failures, 0 idle frames and 0 additional inference calls. iOS thermal state start/peak/end: 0/0/0 (0 is nominal). This bounded synthetic check is not an all-device frame-rate or temperature guarantee. Signed Release archive and privacy manifest verified.
