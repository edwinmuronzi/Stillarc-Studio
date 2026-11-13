# 0.41.0 validation

- Native iPhone 17 Pro: all eight Log curves checked against CPU references, published black/gray/white values and GPU output (64 vectors).
- Six manual-profile encoded video fixtures: preview/export matching, retained audio, size and duration passed.
- Three-layer LUT rendering, bypass, flexible spline bounds, preset schema 6, saved-look round-trip and adjustment transfer passed.
- Native animated LUT stack + flexible curve export, HDR headroom, trim/orientation/audio, saved versions, project backup and queued export passed. Maximum sampled preview/export error: 0.00118 in linear RGB.
- Native sustained preview: 68.8 seconds, 1,905 rendered frames, p95 GPU completion 29.3 ms, zero failures, zero idle renders, zero repeated segmentation analyses. Three active 65³ LUTs, four flexible curve channels, four masks, HDR, fades and changing zoom. iOS thermal state start/peak/end: nominal. This is a bounded test, not a guarantee of temperature on every device or workload.
- Simulator interaction tests passed: LUT clearing/undo, flexible point addition, slider editing, undo/redo and graph scrolling without accidental edits.
- Compact iPhone 13 mini simulator regression suite passed. This checks correctness/layout compatibility, not physical older-device thermal performance.

Reports and screenshots accompany this file. New camera profiles were tested with published equations and generated clips; camera-original fixtures for these four profiles were not available.
