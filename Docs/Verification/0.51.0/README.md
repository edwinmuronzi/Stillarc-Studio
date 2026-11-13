# Studio 0.51.0 (56) verification

## Functional regression

Simulator object-association checks passed tap/label-map vertical coordinates, Vision rectangle conversion, frame-local instance renumbering, and rejection of missing or equally plausible split candidates. These isolate association rules; they do not measure semantic segmentation accuracy on arbitrary objects.

The 900-frame temporal-matte roundtrip/source-time lookup and 901-frame rejection passed. Existing colour interpretation/P3 export, source-time crop/trim, encoded background replacement, source archives, broad core, HDR/Log video/audio/trim, queue and archive suites passed on 0.51.0. Compact iPhone 13 mini simulator interaction tests passed: object preparation is disabled until a valid preview tap, enables after selection, remains dismissible in landscape, and existing People/edge controls remain responsive. Simulator layout/logic checks do not prove older-device performance.

## Native People

The physical 17 Pro passed **450/450 source frames at 30 fps (15 seconds)**, saving **20,792,378 bytes** of probability masks. Existing face/skin, cancellation, measured/manual tracking, target-loss recovery, colour interpretation, encoded temporal background replacement and backup checks passed in the same run. Thermal status at report completion was nominal (0). Native 60 fps / 900-frame People inference is not claimed as tested; the frame/storage budget and persistence path permit it, while detailed masks can reach the 48 MiB bound sooner.

## Native object

The final 17 Pro object test uses a public **Smithsonian Hasselblad camera photograph**, animated with small translation, scale and rotation over 24 source frames. It verifies a newly generated silhouette per source frame, persistence, crop/shorter-trim reuse, input-change invalidation, cancellation, and actual encoded solid-background replacement at original clip dimensions/timing. Its source is [National Air and Space Museum, Camera, Hasselblad, 70mm, with Lens](https://airandspace.si.edu/collection-objects/camera-hasselblad-70mm-lens/nasm_A19770574000), image identifier `NASM-A19770574000cp01`. The source image is used locally for internal verification and is not bundled in the app/repository or used as marketing artwork.

A preliminary animated [NASA Hubble photograph](https://science.nasa.gov/image-detail/hubble-space-telescope-hst-6/) was rejected with a no-safe-selection/identity-loss result. No matte was committed. This is an important capability limit: the foreground model does not reliably detect every visible object. The object path also gained conservative fresh-mask continuity when a box prediction is unreliable: only a stronger, unambiguous overlap with the previous visible silhouette may continue. It never saves an unverified predicted box as the actual silhouette. The final camera-object test, not the rejected telescope attempt, is the passing native object evidence.

## Performance

The physical 17 Pro final-source playback check passed: **68.37 seconds**, 1,800 requested updates, 300 changing saved matte frames, HDR, three LUT layers, four flexible curve channels and four masks. Render p95 was **28.90 ms**, peak process memory **223.5 MB**. GPU failures, additional playback inference, hidden scope jobs and idle renders were zero; iOS thermal start/peak/end were **0/0/0 (nominal)**. This is a bounded workload with scopes and live painting disabled, not a guarantee of zero warmth, frame rate or battery use for every edit/device. Playback/export use the same bounded temporal mask decoder/cache, not the segmentation models. Preparation can take time because every source frame is analysed. Neither the models nor association logic run in playback/export.

## Remaining scope

This is a foreground instance-segmentation/association implementation, not an identity-embedding or occlusion-reconstruction model. Synthetic association tests and an animated still do not establish precision on real deformation, fast motion, overlapping lookalike objects, long occlusion, transparency, hair/fur or every object category. Inspect the full output. Older physical devices and more real footage remain open gates. No App Store or external beta preparation.
