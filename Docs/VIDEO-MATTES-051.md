# Fifteen-second People and tap-selected Object video mattes · 0.51

## Follow an object, not just a fixed shape

Open a video and choose **Masks → Add mask → Object video matte**. Tap inside the object in the first **full-frame** preview, away from its border, then choose **Prepare & save video matte**. Your output still uses the project crop. Studio creates a fresh soft outline for each kept source frame and associates it with the selected object using tracked location and mask overlap. Frame-local instance numbers are not treated as permanent object identities.

The result is a saved changing silhouette, rather than a fixed cutout translated across the picture. You can adjust just that selection with the usual local controls. Enable **Remove background outside mask**, then **Replace background** to composite a colour, image or blurred original. Switch background removal off to return to local adjustments. Existing edge refinement, Fine detail / Clean edge, inversion, strength and undo/redo remain available. Video export requires a composited background; transparent video-file export is not added.

Choose **Rebuild Object video matte** to select again on the current first kept frame. A separate rigid track is unnecessary and hidden for these per-frame masks. Rebuild and static Recreate are kept separate so a moving mask is not silently replaced by one fixed shape.

## Fifteen seconds at 30 or 60 fps

People and Object video mattes allow up to **15 seconds, 900 source frames and 48 MiB of saved masks**. At 30 fps a full clip uses 450 frames; at 60 fps it uses 900. Higher source rates or unusually detailed masks can reach the frame/storage budget sooner. No source frames are skipped to fit the budget. People retains the existing accurate People model, with saved probability detail bounded to 1536 pixels. Object analysis uses a bounded 1024-pixel longest edge and the foreground instance model; object edge quality is not guaranteed to equal person-specific hair matting. Original footage and chosen export dimensions/frame timing remain unchanged.

Preparation runs only on request, on the utility worker with thermal pacing and storage preflight. It can take time because every source frame is analysed. Playback/export reuse saved masks through the bounded cache, without additional segmentation inference. Cancellation, leaving Studio, read errors, ambiguous identity or serious thermal pressure prevent a partial update from replacing existing edits. Return and prepare again; incomplete analysis is not resumed.

## Accuracy and identity limits

Use a distinct, visible foreground object. If the box tracker loses confidence but the fresh silhouette strongly agrees with the previous shape, Studio can retain visible continuity. If the object disappears, becomes uncertain, splits/merges ambiguously or moves too far to match, preparation stops rather than knowingly selecting a different object. Shorten the kept range before an obstruction, or start another selection after the object returns. This is conservative association, not an identity embedding, automatic occlusion reconstruction or a guarantee against every identity switch.

Review the full clip, especially fast motion, similar overlapping subjects, shadows, reflections, transparency, fur and thin detail. Segmentation can miss an object or produce an imperfect border. Crop changes and shorter trims reuse full-frame saved masks; input-conversion changes or extending outside the analysed time require preparation again. All-or-nothing saving preserves previous edits on failure, and source backups retain the masks. New source backups require reader build 56; queues use schema 11 (older schemas remain readable).

Implementation uses Apple's [foreground instance-mask request](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest) and [instance-mask observation](https://developer.apple.com/documentation/vision/vninstancemaskobservation), alongside the existing object tracker and People segmentation. No remote inference, new downloaded model or new third-party dependency is added.
