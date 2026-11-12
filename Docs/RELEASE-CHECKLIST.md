# 0.28 combined refinement / release candidate

12 November 2026. Batches 4 and 5 are delivered together. This is a signed development release candidate, not an App Store submission or guarantee of zero heat/lag.

## Completed

- Manual lens distortion correction, natural luminance-aware grain, legacy grain preservation and highlight-edge halation. Neutral controls bypass new effects; kernels are cached and prepared away from UI interaction. Export resolution is unchanged.
- Rendering verification passed on simulator and iPhone 17 Pro: neutral bypass, coordinate/edge fixtures, deterministic photo grain, video grain evolution, alpha, migration/preset/copy/reset, mask geometry safety and preview/export matching. Native generated video retained all 12 frames, size, duration, sound and original source. Maximum photo normalized-channel error was about 0.0046; video mean RGB error about 0.0015 after compression.
- Full processing regression passed freshly, including 12/24/48MP synthetic image fixtures, masks, crop repair, LUTs, curves, project persistence/recovery and a 2,000-item metadata library. Synthetic fixtures do not replace real camera-file tests.
- All 21 UI cases passed across the full suite and targeted rerun. The initial new-case failure was a test launch flag deliberately resetting edits on reopen; the corrected persistence test passed. Other 20 cases passed in the full run. An initial video test counted compressed B-frame samples in decode order; the corrected test checks decoded presentation order and passed. No failures are hidden as production fixes.
- Actual compact iPhone and iPad simulator layouts reviewed, including larger accessibility text. Slider accessible reset actions and iPad keyboard shortcuts retained. This is not a full VoiceOver audit or proof of performance on older physical devices.
- Sustained iPhone 17 Pro check: 2,700 requested / 2,700 rendered edits at approximately 30 updates/sec, heavy grade plus grain, halation and lens correction. Render p95 22.02ms, zero GPU failures, zero extra idle renders over 30 seconds. iOS thermal status began, peaked and ended at **nominal (0)**. Render time is not end-to-end touch latency; thermal status is not a Celsius measurement or an all-workloads promise.
- Signed Release archive and bundled privacy manifest validated; final Release installed and launched on iPhone 17 Pro. Privacy manifest declares app preferences CA92.1, owned/user-selected file timestamps C617.1/3B52.1, elapsed timing 35F9.1; no tracking or collected data. Review against final submission requirements.
- README, product overview, screenshots, privacy policy and listing drafts updated.

[Machine-readable verification reports](Verification/0.28.0)

## Before public distribution

1. Test real supported RAW/Log/HDR sources, long clips, low storage, permission denial and interrupted operations on more physical devices, particularly the oldest supported iOS 17 hardware. Review HDR displays and output in independent viewers.
2. Complete VoiceOver, landscape, larger-text and localization review with users. Keep important source/export backups.
3. Enroll in Apple Developer Program if public TestFlight/App Store distribution is desired; the current free Personal Team is development-only. Supply public support/privacy URLs, App Store privacy answers, age rating and final screenshots; validate distribution signing and App Store Connect checks.
4. Run an external beta before publishing. Advanced lens profiles, extra free curve points, HDR still exports, changing-pose segmentation and healing remain future scope, not promised release features.
