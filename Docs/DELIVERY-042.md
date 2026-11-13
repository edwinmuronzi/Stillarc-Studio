# Delivery formats — 0.42

Open Export and choose **Video format**. Pool and Home batch delivery offer the same choices; queued jobs retain a snapshot. The choice is remembered on this device. Photos retain their photo format/quality controls.

- **HEVC:** default; smaller MOV files, SDR at 8/10-bit or HLG HDR at 10-bit. Existing output is unchanged.
- **H.264:** 8-bit SDR MP4, with mono/stereo sound encoded to AAC (96/192 kbps). Useful for broad playback compatibility. MP4 retains requested date/location in ISO metadata. Camera make/model requires MOV; a request to include those with MP4 reports an error instead of silently discarding them. Audio timing and track count stay with the source; unsupported channel configurations report an error instead of dropping sound. Choose HEVC/ProRes to retain unusual original audio formats, or explicitly turn sound off. Maximum/Balanced/Compact adjust target video bitrate.
- **ProRes 422:** 10-bit MOV for an editing handoff, offered when VideoToolbox reports a hardware ProRes 422 encoder. Uses 10-bit 4:2:2 YUV output and fixed ProRes compression, in SDR or Rec.2020 HLG HDR. Files are much larger. Quality does not change ProRes compression; size remains selectable. Save to Files for transfer to another editor; Photos support can vary by device/file.

Turning HDR on while H.264 is selected returns the format to HEVC. Mixed HDR pools also use HDR-capable choices; source HDR decisions stay intact. An incompatible stored/manual H.264+HDR request produces a clear error rather than silently changing output. Unsupported encoder/size combinations are checked before rendering.

All formats share full-source grading, crop/resize, original frame timing, trimming, requested metadata and cancellation cleanup. H.264 converts audio during this same export, without a second video render. HEVC/ProRes retain original audio tracks. No encoding starts until Create export or an explicit queue start. The existing serial worker waits for encoder readiness and pauses at serious/critical thermal state; the live editor preview remains paused behind delivery. No new preview processing pass or continuous analysis was added.

New queue records use schema 5 so older builds cannot silently ignore the selected format. Older queue records load as their original HEVC behaviour. Codec choices are delivery preferences, not creative presets or edits to originals.

Technical references: [Apple AVAssetWriter settings validation](https://developer.apple.com/documentation/avfoundation/avassetwriter/canapply%28outputsettings%3Aformediatype%3A%29), [Apple ProRes recording guidance](https://developer.apple.com/documentation/technotes/tn3104-recording-video-in-apple-prores), and VideoToolbox encoder-list capability keys in the installed Apple SDK. File size and export speed depend on the source; these formats cannot guarantee zero device heat.
