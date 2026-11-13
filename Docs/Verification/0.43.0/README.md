# 0.43.0 export planning validation

Completed:

- Estimate model checks for photo/video format, quality, crop, resize, trim, source cadence, sound, transparency, fixed ProRes/PNG compression, legacy audio fallbacks, pool/queue totals and unknown-item handling.
- Exact file-length summation, empty totals and missing-file failure checks. 5,000 diverse estimates with a consumed checksum completed on the simulator; this is not a phone touch-latency or thermal measurement.
- Representative HEVC bitrate settings match the pre-existing encoder calculation exactly. Video frame/render quality is unchanged by size planning.
- Normal simulator: photo/video estimates update with formats, reduced photo resolution changes the estimate, and successful exports show measured bytes.
- Compact iPhone 13 mini simulator: the estimate stays visible beside the export action; photo format/resolution changes and measured output size pass. This is a layout/correctness check, not older physical-device performance testing.
- Simulator HEVC SDR/HDR and H.264 exports retained colour, audio/trim, requested metadata, silent-export behavior and queue settings. ProRes hardware was unavailable in the simulator and its exports were not repeated there.
- Signed Release archive 0.43.0 build 47 and privacy-manifest checks passed.

Pending physical device work:

The diagnostic build installed on the iPhone 17 Pro, but iOS refused its launch because the phone was locked. The phone subsequently became unavailable/disconnected. Native 0.43 checks, sustained thermal testing and installation/launch of the final signed release remain pending. No older native thermal report is presented as a 0.43 result. Reconnect and unlock the 17 Pro to finish those checks.
