# Studio 0.45.0 (50) verification

- iPhone 17 Pro: mask pose math, actual GPU rotation, crop/pose pixel agreement (maximum sampled error 0), legacy persistence and invalid-data checks passed.
- Native animated-video checks passed: HDR, preview/export agreement, audio/trim, source versions, backups and queued exports.
- Sustained native HDR preview passed for 69 seconds with four masks, animated brush and saved automatic-matte poses, three LUT layers and four flexible curve channels. Render p95 was 29.08 ms, with zero GPU failures, idle frames or additional analysis calls. iOS thermal state remained nominal (0). This bounded synthetic check is not a guarantee of all-device frame rate or temperature.
- Simulator regression checks and slider UI test passed, including size/rotation edits, Undo/Redo and export. Screenshot retained here.
- Signed Release archive and embedded privacy manifest verified before device installation.

Manual size/rotation corrections blend between source-time points; automatic tracking still measures position, not changing silhouette or pose. Physical testing used the 17 Pro, not older phones.
