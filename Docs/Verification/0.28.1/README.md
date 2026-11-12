# Real-media validation and SDR correction — 12 November 2026

No user media, thumbnails, original filenames, hashes, camera serial numbers or GPS metadata are included. Supplied DNG/MOV originals were read only; isolated fixture copies were used on the phone. Fixture media must never be committed.

## Results

- Physical iPhone 17 Pro, supplied 12MP DNG: RAW detection, bounded 1600px preview, visible edits, full oriented 3024×4032 JPEG/PNG exports, finite sampled output and original-byte preservation passed. Preview opened in about 0.367 seconds. Sampled normalized preview/export mean channel errors: JPEG 0.00870, PNG 0.00794 (includes alpha). These are downsampled comparisons, not pixel-perfect RAW decoder equivalence. Reduced-resolution development can differ slightly from full decode. This RAW baseline ran on 0.28.0; the correction below changes only video encoding.
- 120 small-sample RAW edit renders passed, with iOS thermal status nominal at sampled points. The 64px sample-render timing is diagnostic only, not interactive display latency or a sustained energy benchmark. See the earlier sustained 1600px preview check separately.
- Supplied real 4K/30 HLG/Rec.2020 clip on 0.28.1: SDR and HLG exports passed. Both retain oriented 2160×3840 resolution, all 132 decoded frames, original presentation timestamps within 3ms, both audio tracks and duration within tolerance. Source bytes were unchanged. Sampled normalized mean channel errors: SDR 0.003981, HLG 0.004823 (includes alpha). Thermal status was nominal at export boundaries. This short test is not an independent HDR display calibration, long-session energy benchmark or proof for every file/device.
- Full native video suite passed on 0.28.1: Standard/Apple Log/Log 2, masks/tracking, trim/audio, HDR headroom, HLG/PQ and the new HDR-to-SDR mixed-channel regression. See machine-readable report.
- Fresh full processing regression passed on compact iPhone 13 mini simulator. It is a correctness/layout platform, not older-chip speed, memory or thermal emulation. No older physical iPhone is available; no older-device performance claim is made. Real files from additional RAW cameras, 24/48MP sources, PQ originals and long clips remain future validation.

## Actual bug found and fixed

Rendering an HDR-derived graded graph into an SDR YUV pixel buffer using standard sRGB introduced an additional range conversion and darkened the result. The supplied clip exposed approximately 0.123 mean normalized channel error before correction. Clamping alone did not fix it. Controlled first-frame probes showed extended-sRGB output preserves the expected values without an intermediate rasterization pass. Export now explicitly clamps SDR to the preview range and renders with extended sRGB; encoded SDR primaries/transfer tags remain sRGB/Rec.709. HLG output remains on the existing path.

The generated regression uses HLG [4, 0.25, 0.0625] linear RGB, requiring red to clip to SDR white while valid green/blue midtones remain intact. It failed before the correction and passes afterward. This detects range compression without relying on private fixture media.

## Harness corrections and foreground requirements

Initial test references omitted the existing SDR preview clamp and counted non-image container markers. Final checks match the actual preview and compare decoded presentation frames. These corrections did not erase the real SDR mismatch: it still measured over 0.13 after clamping alone and fell below 0.004 after the output-space correction. The true HDR test passed separately.

Earlier runs lost foreground access; explicit app-state logs confirmed Backgrounded. They are excluded. The final run stayed active and completed. The Debug-only harness removes stale HDR reports at start and records progress, app state and cooling. No incomplete report is treated as passing.

## Scope and delivery

Signed Release 0.28.1 (30) was built and its signature/privacy manifest verified. No external beta or App Store preparation was performed. New diagnostics read only explicit files in Documents/RealMediaQA, not the Photos library or user projects. `--verify-real-media` checks RAW; `--verify-real-video` checks source.mov. Public product direction is a proposal in PRODUCT-DIRECTION.md, not a claim that future tools have shipped.
