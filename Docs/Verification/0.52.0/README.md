# Studio 0.52.0 (57) verification

**Final-source native checks and sustained preview have now passed after reconnection.** The resumed results below supersede the earlier disconnected-device gates for this tested workload. Real difficult footage and older-device coverage remain open.

## Final-source offline checks

Core, video/HDR/Log/audio/trim, queue retry/cancellation/restart, source backup/restore/interruption and current batch regression passed. New batch checks cover: numeric timed Add/Subtract, Smooth fade and empty end point; full-source crop projection; invalid repair decoding; interval replacement preserving outside frame IDs and refreshing review hints; encoded video pixels matching the repair; repair backup roundtrip; protected per-shot settings and prior effective match balance; Before pool match version; whole-pool Undo/Redo; cancelled matching; and atomic preflight rejection of a stale second destination before the first changes.

The controlled contour-flash fixture had an erroneous single-frame white outline on an unchanged image. At the sampled affected edge, probability dropped from **1.0 to 0.15**, while the stable centre stayed white. A separate genuinely changing image-detail case retained its current mask. This is a synthetic regression, not an 85% accuracy claim for arbitrary real cutouts. Translation alignment intentionally does not interpret single-frame contour-size jitter as true object scale. Image changes, fast motion, gaps and low overlap reduce/bypass consensus.

The supplied camera-original DNG (3024 × 4032) passed simulator source preservation and JPEG/PNG preview/export comparison. This is decoder/colour regression, not physical-device interactive latency or temperature evidence. No real camera HDR MOV is present at the previously supplied path, so generated HDR/video fixtures remain the video regression input.

## UI and responsiveness

Compact iPhone 13 mini simulator checks passed protected pool controls, People preparation controls, Add/Subtract brushing, whole-stroke Undo/Redo, marker navigation, opening/cancelling a short reanalysis sheet and returning to the editor. The final brush test also samples the actual paused preview's changed pixel, rather than only checking stored stroke counts. An issue found during this work was async repair raster completion not redrawing a paused preview; both photo and video preview listeners now recognize repair drawing IDs while still ignoring hidden/inactive views. Controls retain a large preview, collapse longer help and use distinct modal accessibility IDs. Test-navigation failures (an off-screen nested marker scroller and ambiguous Done locator) were corrected and rerun.

The encoded-video test also caught repair rasters being omitted by the ordinary brush export TaskLocal cache. Repair rasters now build through their own bounded cache and ignore that unrelated prepared-brush lookup. Export/render/persistence regression passed after the fix. The repair cache is capped at 32 entries / 48 MB and deep repair-data validation runs on decode/export rather than traversing all vertices each render.

## Native checks and pending physical gate

Before the 17 Pro disconnected, the pre-polish 0.52 diagnostic passed the new numeric/integration batch, encoded timed repairs, source backups, protected pool matching and native Object matting/export with stabilization (24/24 source frames, 202,465 saved bytes). Those reports recorded nominal iOS thermal state at completion. The 15-second People attempt reached a progress checkpoint of 360 frames / 16,624,467 saved bytes, then stopped reporting progress; it is **not** counted as a completed run. Native tests occurred before the final UI notification/pool-protection polish, so final-source native and sustained repaired-mask thermal checks remain pending.

Xcode/CoreDevice subsequently reported the 17 Pro unavailable. Final Release installation/launch cannot be claimed until reconnection. The reconnect/foreground request was left with the user. Simulator workload evidence, if present, does not close that physical gate or establish phone temperature, energy use or sustained frame rate.

## Scope

Existing saved mattes need an explicit rebuild with Stabilize moving edges enabled to receive the new preparation pass. First/last analysis frames are unfiltered. Actual difficult user footage was not supplied for this complaint; fine hair, low contrast, transparency, occlusion and fast movement still require review, and the optional pass can be disabled/rebuilt if it softens an important edge. Manual repairs are source-time fields, not automatically tracked mesh deformation. Only short compatible intervals merge; invalid/cancelled analysis leaves the original intact. Older physical devices remain unavailable. No external beta or App Store submission.

## Offline repaired-mask playback workload

The simulator workload passed: 68.80 seconds, 1,800 requested updates, 300 changing saved matte frames, three LUT layers, four curve channels, four masks, HDR and animated brush repair fields. It recorded zero GPU failures, idle renders, hidden scope jobs or additional automatic-selection analysis calls. Four brush raster jobs were needed and the queue ended empty. Render p95 was 32.53 ms on the host simulator. This is **not** a 17 Pro or older-phone frame-rate, energy or thermal result. The final physical repaired-mask workload remains pending reconnection.

The final UI rerun includes visible paused-preview pixel change, opposing-repair clearing and stroke Undo/Redo. Full Release archive/signature/version validation passed. The signed artifact is locally ready; phone installation has not been verified while the 17 Pro is unavailable.

## Resumed final-source native checks

After reconnection, final-source 0.52.0 (57) passed the complete native batch: numeric contour suppression with changing image-detail preservation; encoded timed repair output and backup; protected pool settings including prior effective match balance; whole-pool Undo/Redo and version checkpoints; cancelled matching and atomic stale-target rejection. Native Object matting/export processed 24/24 frames with 202,465 saved bytes. The stabilized People run completed **450/450 frames over 15 seconds**, saving **20,737,007 bytes**. Face/skin, measured/manual tracking and loss recovery passed too. These functional reports recorded nominal thermal status at completion. The earlier incomplete attempts above are retained as session history, superseded for these checks.

The supplied 3024 × 4032 DNG passed source preservation and JPEG/PNG exports on the physical 17 Pro. Open: 0.331 s; JPEG/PNG mean preview/export errors: 0.00870/0.00794; 120 small-sample renders p95: 4.90 ms. This is sampled rendering, not touch-to-display latency. RAW check thermal start/peak were nominal.

## Completed final-source native repaired-mask workload

The final physical 17 Pro run passed **198.56 seconds** with **5,400 requested updates**, **5,681 rendered / decoded frames**, 300 changing saved matte frames, HDR, three LUT layers including 4,096-point shapers, four flexible curve channels, four masks and animated repair fields. Render p95: **28.67 ms**. GPU failures, extra automatic-selection analysis, idle renders and hidden scope jobs were zero. Four brush raster jobs were needed, ending with an empty queue; raster p95 was 2.48 ms. iOS thermal start/peak/end were **0/0/0 (nominal)**. Process footprint start/sampled peak/end: **135.2/227.1/125.4 MB**. Scopes and live brush painting were off in this particular workload. These bounded measurements are not guarantees of zero warmth, battery use or frame rate for every device/edit.

The signed 0.52.0 (57) Release application was restored after diagnostics. No production code changed during the resumed checks.
