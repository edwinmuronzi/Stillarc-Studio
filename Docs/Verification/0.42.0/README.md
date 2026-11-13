# Delivery validation — 0.42.0

Native iPhone 17 Pro checks passed:

- Actual H.264/AAC MP4, HEVC SDR/HLG and ProRes 422 SDR/HLG encoding, with output codec inspection, rotated dimensions, trim duration, audio tracks and matching graded pixels. Maximum sampled colour error: 0.00342 in linear RGB.
- Hardware ProRes encoder reported available. Full 3840×2160 ProRes SDR and HLG outputs retained dimensions/timing and finite image data; HDR retained above-white highlight headroom.
- Requested date/location retained in MOV/MP4 (MP4 uses ISO metadata); camera make/model retained in MOV. MP4 camera-detail requests explicitly rejected, with format guidance.
- Legacy HEVC defaults, remembered preferences, queue codec persistence, batch output format and silent H.264 delivery passed. H.264/HDR mismatch rejected instead of silently dropping HDR.
- Sustained preview: 68.8 seconds, 1,859 frames rendered, p95 GPU completion 28.8 ms, no GPU failures or idle rendering. Three active 65³ LUTs, four flexible curves, four masks, HDR, animation and changing zoom. iOS thermal state remained nominal. No continuous work was added to the preview for these export controls.

The codec fixtures are generated technical images/audio. The 4K checks are short output correctness tests, not a long-duration 4K export endurance claim. The preview stress test is a bounded test on this phone, not a guarantee of zero heat on every workload or older device. No older physical phone was available.

Simulator interface check passed: choose H.264, create MP4, save it successfully to Photos, change export options, then enable HDR and verify the format returns to HEVC. Signing and privacy-manifest validation passed for the release archive.
