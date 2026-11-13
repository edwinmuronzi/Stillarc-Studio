# Studio 0.46.0 (51) verification

- Native iPhone 17 Pro correctness passed: Smooth interpolation, Hold boundaries, unchanged measured tracking, legacy Linear defaults, pose persistence, invalid data, crop/pose pixels (maximum sampled error 0), and GPU mask rotation.
- Native animated-video export passed with Smooth mask corrections: HDR headroom, preview/export agreement, source-time trim, audio/orientation, versions, backups and queued/direct output agreement.
- Simulator regression and mask-pose checks passed.
- Compact-screen UI test passed: transition selection, Undo/Redo, frame-step bounds, previous/next correction navigation and actual video export. Screenshot retained.
- Signed Release archive and privacy manifest verified.

The arrow controls step one nominal frame interval with zero seek tolerance; variable-frame-rate footage can have uneven recorded presentation timestamps. Automatic tracking continues to measure position only. No new Vision requests or image-rendering passes are introduced by interpolation. Physical testing used the 17 Pro, not older devices.

Sustained native HDR playback: 69.2 seconds, render p95 29.26 ms, 0 GPU failures, 0 idle frames and 0 additional inference calls. iOS thermal state start/peak/end: 0/0/0 (0 is nominal). This bounded synthetic workload is not an all-device temperature or frame-rate guarantee.
