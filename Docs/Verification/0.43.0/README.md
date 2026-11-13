# 0.43.0 export planning validation

Completed:

- Estimate model checks for photo/video format, quality, crop, resize, trim, source cadence, sound, transparency, fixed ProRes/PNG compression, legacy audio fallbacks, pool/queue totals and unknown-item handling.
- Exact file-length summation, empty totals and missing-file failure checks. 5,000 diverse estimates with a consumed checksum completed on the simulator; this is not a phone touch-latency or thermal measurement.
- Representative HEVC bitrate settings match the pre-existing encoder calculation exactly. Video frame/render quality is unchanged by size planning.
- Normal simulator: photo/video estimates update with formats, reduced photo resolution changes the estimate, and successful exports show measured bytes.
- Compact iPhone 13 mini simulator: the estimate stays visible beside the export action; photo format/resolution changes and measured output size pass. This is a layout/correctness check, not older physical-device performance testing.
- Simulator HEVC SDR/HDR and H.264 exports retained colour, audio/trim, requested metadata, silent-export behavior and queue settings. ProRes hardware was unavailable in the simulator and its exports were not repeated there.
- Signed Release archive 0.43.0 build 47 and privacy-manifest checks passed.

Native iPhone 17 Pro completed:

- Estimate model checks, exact byte totals, transparent/legacy fallbacks, pool/queue sums and unchanged encoder budget passed. The 5,000-estimate workload consumed a checksum; it is not a UI touch-latency measurement.
- HEVC SDR/HLG, H.264/AAC and hardware ProRes 422 SDR/HLG export checks passed, including trim/orientation, audio, requested metadata, silent export and queued settings. Maximum sampled preview/export difference was 0.00342 in linear RGB.
- Full 3840×2160 ProRes SDR/HLG output retained dimensions, timing and HDR highlight headroom.
- Sustained preview: 68.1 seconds, 1,882 rendered frames, p95 GPU completion 22.4 ms, zero GPU failures, no interruption and no idle rendering. The workload used three 65³ LUTs, four flexible curves, four masks, HDR, animation and changing zoom. iOS thermal state start/peak/end remained nominal. This bounded test is not a guarantee of zero heat on every device/workload.
- Signed Release 0.43.0 build 47 installed and launched on the iPhone 17 Pro. No older physical device was available for thermal testing.
