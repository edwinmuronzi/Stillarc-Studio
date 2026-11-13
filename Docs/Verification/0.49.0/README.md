# Combined Studio 0.49.0 (54) / Camera 1.3.7 (24) validation

## Native functional checks

The available iPhone 17 Pro passed input sRGB/P3/linear interpretation, embedded Display P3 PNG output, legacy delivery defaults, source-specific chroma filtering after decoding, brightness-detail preservation, measured/manual mask-pose composition, source-time temporal mask selection and full-source-aspect crop projection. Low-storage preflight was checked with injected capacity values, without filling the user's disk.

Native Vision checks passed Faces/Facial skin coverage and orientation, 12/12 frames of sequential People matting, object-size tracking and rectangle scale/rotation on an animated textured target. Measured final scales were 1.2044 (object) and 1.2201 (rectangle); rectangle rotation was −8.164°. These bounded synthetic checks and a public portrait animated into a clip do not establish precision on real changing hair, occlusions, transparency, perspective deformation or arbitrary moving objects.

Native source/versions/backups, rendered time-varying video background replacement, HDR/SDR preview/export comparison, trim/orientation/audio, queued/direct export, manual corrections and broad core regression passed. Camera-generated colour was verified in Studio and Studio-generated colour in Camera using the actual exported .cube files. This is colour-only sampled exchange, not native recipe/library synchronization.

The previously supplied camera-original DNG (3024 × 4032) passed unmodified-source checks, JPEG/PNG exports and 120 sampled edits. Decoder open was about 0.317 s; sampled render p95 was 13.90 ms. This measures small sample rendering, not interactive display latency. Only this RAW camera/file was physically tested in this batch. The earlier HDR MOV is absent from the current explicit fixture folder; generated native HDR fixtures were tested instead.

## UI and sustained workload

Compact iPhone 13 mini simulator UI checks passed Chroma noise edits, explicit input choice/reset, face-selection method controls, tagged P3 PNG export, People video-matte preparation/cancel controls and preview layout. Vision model execution was checked on the physical 17 Pro; the simulator could not create its face-inference context. Final simulator broad regression, new finishing data/export checks and mask-pose checks passed.

Long native HDR preview with 180 changing saved matte frames, three LUT layers (including combined 4096-point shapers/65³ cubes), four flexible curve channels, four local selections, animated brush motion, zoom and split comparison: 198.84 seconds; render p95 30.06 ms; 5618 rendered / 5617 decoded frames; zero GPU failures, idle renders or additional inference. iOS thermal state remained nominal (0) throughout. Measured process footprint start/peak/end: 133.1/223.8/109.5 MB. This bounded workload is not a guaranteed frame rate, temperature or battery-life result for every phone/grade.

The native failure caught during development was Vision returning a 1512 × 2016 matte despite a reduced analysis input. The worker now normalizes saved probabilities to the declared 1536-pixel maximum before validation/encoding, while retaining every source frame. All model checks passed after the fix. Selection type/name is retained during persistence and compatible crop repair; tapped-subject selections no longer silently become all-subject selections when a new analysis is required.

Signed Release archives, embedded privacy manifests and version/build identifiers were verified. Studio declares disk-space preflight use under E174.1. No beta, App Store submission or public download setup was performed.

## Open gates

Older physical devices were unavailable; the 16 Pro is listed unavailable and no older phone was supplied. Simulator coverage is not older-phone thermal/energy/model evidence. Broader manufacturer RAW/HDR files, calibrated lens profiles beyond the RAW decoder's supported controls, real moving-person/hair/occlusion footage, and physical permission/low-storage/interruption scenarios remain validation gates. Do not advertise universal masking accuracy, all-device efficiency or complete competitor parity.

Portrait fixture: [NASA, astronaut candidate Victor Glover](https://www.nasa.gov/image-article/astronaut-candidate-victor-glover-3/), used only for internal verification/UI evidence, not app marketing artwork. The portrait/RAW/video source files are not bundled in this repository. [Apple's required-reason API documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) supports the sufficient-space-before-writing declaration.
