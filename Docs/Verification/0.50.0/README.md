# Studio 0.50.0 (55) verification

## Completed checks

Simulator colour delivery passed after correcting remembered sRGB default normalization (explicit persisted sRGB is canonicalized to the same nil/default representation used by UI settings). Tagged Display P3 PNG/JPEG reopened into the same linear working space matched the neutral preview within the 0.02 test tolerance. RAW/Log, HDR/SDR video, audio/trim/orientation, queue, project archive, pool sync undo/redo, cutout history and broad core regressions passed. Some historical suites retain their original hard-coded report version; these were rerun from the current build.

The supplied camera-original DNG passed on the physical 17 Pro: 3024 × 4032, source preserved, JPEG/PNG mean preview/export errors 0.00870 / 0.00794. 120 small-sample renders had p95 5.21 ms. This is sampled rendering, not touch-to-display latency. iOS thermal state was fair (1) for that check; do not label all native tests nominal or claim zero warmth.

Compact iPhone 13 mini simulator UI checks passed People-matte preparation/dismissal, photo-development/input/P3 export, mask size/rotation corrections with undo/export, tracking-recovery toggle/dismissal, and actual edge-preset Undo/Redo/reset. The initial new tracking UI test incorrectly attempted to add a radial mask to an already prepared diagnostic scene; its navigation was corrected and the rerun passed. The observed layout retains a large preview and fits edge shortcuts without horizontal overlap. Simulator layout checks are not evidence of older-phone native performance.

The extended saved-matte regression roundtrips 360 frames, checks late source-time lookup and rejects 361. Partial tracking metadata persists, holds the last reliable pose, combines manual corrections and decodes old tracks without a loss marker. Existing frame dimensions, source-time crop/trim projection and bounded decode caching remain covered.

## Native extended analysis and sustained preview

Native extended People analysis and sustained-preview attempts did not produce fresh completed reports during this session. Old 0.49 results were rejected rather than counted as passes. A request to keep Studio visible/unlocked was left with the user. These checks remain open; do not infer a new nominal-temperature or sustained-frame-rate result from the simulator passes.

An isolated simulator Vision-model check passed actual target-loss recovery, held last reliable pose and bounded rectangle/object scale/rotation tracking. Its report explicitly sets face/person checks false/zero because those were skipped; it is not evidence for extended People analysis.

## Remaining limits

Only the iPhone 17 Pro is available. More physical devices, difficult real moving-hair/occlusion footage and additional camera-original RAW/HDR files remain open gates. People matte detail is bounded, no automatic target reacquisition is advertised, and no transparent video-file export is added. No external beta or App Store submission.

Native 17 Pro colour-delivery and mask-pose reports subsequently passed on 0.50.0. The attempted People-model run returned “No clear person was found, or reading was interrupted”; it is not a pass and is retained as a validation gap. The longer preview produced no current-version report before the isolated retry.

A later isolated native tracking-recovery diagnostic was attempted with People inference skipped, but no completed report was available before final installation. The corresponding simulator Vision check passed; physical loss-recovery remains unverified in this session.
