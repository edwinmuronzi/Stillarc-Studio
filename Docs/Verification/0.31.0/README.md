# 0.31.0 (33) — Background replacement and photo development

The signed Release archive was built and installed on the connected iPhone 17 Pro. Native application launch succeeded. Personal Team signing remains the distribution constraint; no external beta or App Store submission was performed.

## Results

- Native feature checks passed: solid/image background pixels, alpha/color handling, preview/export agreement, immutable stored replacement assets, reopen/preset isolation, missing-asset errors, active-background cache retention, selected/all pool export, richer local controls, spot Clone/Heal color matching, neutral optics and HDR proof/background separation.
- The supplied 3024 × 4032 DNG passed native RAW white-balance/exposure development and original preservation. Full-size JPEG export matched the bounded developed preview with normalized mean error **0.001794**. This fixture reports highlight recovery supported and lens correction unsupported; the latter toggle is therefore hidden. This is not multi-camera lens calibration coverage.
- Native HDR still encoding/roundtrip passed: **10-bit**, **Rec.2100 HLG**, decoded red-channel value approximately **3.024** in extended linear space; SDR proof stays within SDR range. The file metadata contains no GPS by default. This is HLG HEIF, not an adaptive gain-map claim.
- Native full photo/color/mask/storage/history regression passed, including source-preserving selective sync and whole-sync Undo/Redo. Generated native video regression passed for timing, orientation, grading, HDR/audio and tracking checks.
- Sustained native preview: **1,800 updates**, graded cutout plus blurred-original background and 65³ LUT; **23.94 ms p95**, **0 GPU failures**, **0 additional idle frames**, one initial foreground inference. iOS thermal state stayed **0 (nominal)** through the run and 15-second idle check. These are bounded measurements on this 17 Pro, not temperature/battery guarantees for every workload or older phone.
- **29 distinct UI cases passed** across a full regression and focused rerun. The first run had one ambiguous nested Done selector; the corrected automation targeted the visible button, and the delivery test passed. The final four-case run also covers sticky background/development previews, Heal/Clone, detail inspection and selected/all pool delivery.
- Final core checks also passed on the compact iPhone 13 mini simulator, including the real DNG fixture. Simulator checks do not establish older physical-device thermal/performance behavior.
- Light and dark app-icon PNGs are opaque 1024² assets with luminosity appearance registration. Code signature verification, privacy-manifest lint and Git whitespace checks passed.

Photo RAW settings, optics, repairs, HDR choice and replacement assets remain individual to each source. Face/skin segmentation, advanced denoise, changing-pose video matting and an unvalidated camera-profile catalog are not claimed complete.

Reports and actual UI screenshots are in this folder. Screenshot imagery is an owned illustrative sample; the rectangular matte in the replacement UI fixture is deliberately synthetic. UI captures precede the final plain-English helper-copy polish; rendering/layout are unchanged. Temporary original DNG/video sources are not committed.
