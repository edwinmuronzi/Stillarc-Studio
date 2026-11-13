# 0.44 native LUT workflow validation

- iPhone 17 Pro: 33 independently calculated channel/interpolation vectors, per-channel domains, scalar input-range headers, quoted # titles, endpoint clamping, premultiplied alpha and linear-light strength blending passed. Maximum sampled display-RGB error: 0.000391.
- Supported endpoints of the 1D size range (2 and 4096), malformed/truncated/combined file rejection, legacy 3D decoding/fingerprints, 1D text and preset/library round trips, colour transfer, mixed 1D/3D ordering and colour-LUT export passed.
- Native mixed-stack video checks passed for animated strength, trim/orientation/audio, HDR headroom, direct/queued exports, saved versions and source backups. Maximum sampled preview/export difference: 0.00144 linear RGB.
- Native sustained preview passed: 68.9 seconds with two 65³ 3D LUTs, a 4096-point/channel 1D LUT, four flexible curves, four masks, HDR, animation and changing zoom. p95 GPU completion 28.7 ms, zero GPU failures, no interruption/idle rendering, nominal iOS thermal state at start/peak/end. This bounded run is not a promise of zero heat for every device/workload.
- Simulator interface check passed for visible 1D details, strength changes, undo/redo and full-resolution photo export. Sample input and generated technical fixtures were used; arbitrary third-party camera conversion/shaper LUTs are not certified.

New presets require schema 7; new source/library packages require reader build 49; queue schema 6 protects the 1D table type. Existing 3D fingerprints and older supported files remain readable.
