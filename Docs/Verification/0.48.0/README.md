# Studio 0.48.0 (53) verification

Two batches: preview-based White balance and Levels black/white-point pickers.

- Native iPhone 17 Pro sampling checks passed: neutral patches, linear patch averages, top-origin coordinates, source-stage sampling, framing, HDR normalization, Levels endpoint rendering and preservation of unrelated controls. Maximum neutral channel-spread error: 0.007803. The complete small correctness fixture took 124.7 ms on the phone; this is not a touch-to-display latency measurement.
- Clipped, very dark, transparent, nonfinite and crossed-endpoint samples were rejected. Existing Recipe values round-trip without a schema change.
- Simulator broad regression and sampling checks passed. Compact-screen UI checks exercised white balance, black and white point taps, Undo/Redo, Levels reset, portrait/landscape navigation and actual photo export.
- Native video checks with Warmth/Tint and Levels active passed: HDR headroom, preview/export agreement, trim, orientation/audio, versions, backups and queued/direct export agreement. Maximum sampled preview/export errors were 0.000289, 0.001283 and 0.000805.

Sampling happens only when requested. The neutral solver uses bounded central differences large enough for Core Image temperature-matrix quantization, one worker CIContext per solve, cancellation checks and a final residual check. The first test caught and corrected an unreliable tiny forward difference; no failing build was shipped. This is a bounded Warmth/Tint adjustment, not calibrated RAW white balance or automatic scene recognition. Physical testing used the 17 Pro, not older devices.

Sustained HDR preview: 69.1 seconds, render p95 29.11 ms, 0 GPU failures, 0 idle frames and 0 additional inference calls. iOS thermal state start/peak/end: 0/0/0 (0 is nominal). This bounded synthetic test is not an all-device frame-rate or temperature guarantee. Signed Release archive and privacy manifest verified.
