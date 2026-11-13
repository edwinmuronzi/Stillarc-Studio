# Export planning — 0.43

Export now shows one rounded **Estimated size** figure next to the export button, remaining visible while you change formats or scroll. Format, longest-edge limit, compression quality, current crop, video trim, frame cadence and sound policy contribute to the estimate. A transparent photo uses its PNG estimate even if JPEG was selected before removing the background. PNG and ProRes do not change size estimates when a lossy quality control changes; their compression settings remain fixed.

The displayed figure is the middle of the internal compression allowance, rounded to at most one decimal place. It is approximate, not a promise of the exact encoded size. The photo estimate is a broad pixel-count/compression allowance, not an analysis of your picture. Video uses the exact HEVC/H.264 target bitrate calculation shared with the encoder. ProRes 422 uses Apple's approximate 147 Mbps reference at 1920×1080/29.97 fps, scaled for dimensions and cadence. File overhead and sound are included. New video imports retain small audio-rate/channel metadata for planning; older projects use an explicit broad audio allowance without re-reading the source on every control change.

Compression depends on picture detail, grain, transparency and motion. These ranges are planning estimates, not guaranteed bounds or reserved storage; very simple media can be much smaller. HDR/8-bit/10-bit HEVC use the same existing bitrate budget, so a bit-depth switch alone need not change the estimate. No second source decode, sample encode, image analysis or full-resolution render is performed to calculate it.

After exporting, **Actual file size** replaces the estimate, using measured file lengths. Batch/pool delivery shows the combined estimate, then the sum for successfully completed files. The queue shows per-job estimates/measured sizes and a combined pending-job estimate using each job's saved settings. Missing file sizes are shown as unavailable rather than guessed. Measurements run off the main UI thread and cancel when the view leaves; changing settings only runs arithmetic.

Original files and compression quality remain unchanged. New audio metadata is backward compatible and old projects remain readable. No new background analysis, preview pass, queue auto-start or storage-blocking gate was added.

Reference: [Apple ProRes white paper](https://www.apple.com/final-cut-pro/docs/Apple_ProRes.pdf). This is a target-rate planning model, not a guarantee of a particular final file size.
