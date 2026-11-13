# Stable contours, video-mask repair and pool matching · 0.52

## Reduce background-removal outline flashes

For an existing video matte, choose **Rebuild People/Object video matte** and leave **Stabilize moving edges** on. Existing saved mattes are not silently rewritten on opening a project. New preparation uses one-frame lookahead: neighbouring probability masks are aligned by translation, then image-detail agreement controls a temporal median. This suppresses isolated contour flashes without averaging an old outline along a moving subject. Large movements, time gaps, missing subjects and changing image detail bypass or reduce the correction. The first and last analysed frames retain their original probabilities.

The pass runs during requested preparation only. Playback/export use the saved masks and the decoded frame's source timestamp, as before; no new model inference or smoothing job runs during playback. Source footage/export dimensions and frame timing stay intact. The pass can soften a difficult low-contrast or fast-moving edge; disable it and rebuild if it harms fine detail. It is not a promise of perfect cutouts on every object, hair strand or occlusion. Review the actual clip over the replacement background.

## Repair at source-time moments

**Masks → Review & repair matte** opens a large full-frame preview. Use Play/Pause and the review-position slider, then choose **Add** or **Subtract** and brush. Zoom/Fit and panning in View mode help with small detail. **Done brushing** restores playback/navigation. One complete stroke is one Undo/Redo transaction.

Each repair moment stores separate positive and negative brush fields. **Smooth**, **Linear** or **Hold** controls how the fields blend between moments. Before the first moment, the correction fades from zero at the analysed start; after the final moment it holds. Use **Empty repair here** before/after an affected interval to bound it, or delete a moment. New strokes clear the opposing repair along their path, and the brush directions respect Invert. Repairs are not automatically motion-tracked; add enough moments to follow the outline. Up to 16 moments, 16 strokes per positive/negative field and 32,768 total brush points are supported. Repair raster detail is bounded to the matte's 1536-pixel longest-edge canvas; source and export dimensions are unchanged.

Repairs use full-source coordinates and source time. Compatible crops, perspective/rotation and shorter trims project the saved brush fields; source-specific masks and repairs stay out of reusable colour presets and copy/paste. Backups, versions, direct exports and queued exports retain them. A bounded repair-raster cache avoids rebuilding brush images every playback frame. Deep validation runs on decode/export, not repeatedly over all brush vertices during rendering.

## Review uncertainty and reanalyse only a section

Object mattes record hints for weaker accepted location/shape continuity. **Previous/Next marker** and the marker strip jump to those source times. Add or clear your own review markers. A hint is not proof of a bad edge, and no hints is not proof of accuracy. Existing/People mattes may have no automated hints; inspect the whole clip.

**Reanalyse one-second section here** prepares a short interval around the current moment, with a small context margin for stable boundary frames. For Object masks, tap the object again on the first analysis preview. Only the listed interval is merged into the saved matte. Frames outside it, the existing manual repairs and background settings are preserved. A failed/cancelled analysis or incompatible source/input does not replace anything. Disappearing/ambiguous objects still stop preparation; this does not reconstruct hidden objects. Extending outside the original analysed range or changing source interpretation needs a full rebuild.

## Match an editing pool without flattening each shot

Hold **Sync edits → Match pool to this edit**, or open **Reference & Match → Match pool to this edit**. Choose selected items or the whole pool; the reference is excluded. Studio copies creative colour/mix, curves, wheels, channel mixer, looks, LUTs and film texture, then calculates a gentle richness match separately for each target.

**Keep individual brightness** and **Keep individual white balance** are on by default. Exposure, warmth and tint sliders are never copied; the protections also retain effective brightness/colour-balance corrections from an existing match and prevent the new calculated match from adding more. Common creative curves/looks still affect appearance. Disable protection only if you want additional automatic brightness/colour balancing. Masks/repairs, crop, RAW/input interpretation, detail and video settings remain individual. Video statistics use the first kept frame, so review the rest of each clip.

Targets are analysed serially with bounded previews before any edit is saved. Cancellation or failed analysis applies no matching changes. Commit checks every target for concurrent changes and version capacity; write failure/cancellation rolls back the attempted batch. Each changed item gets **Before pool match** in Versions. One pool Undo/Redo reverses/restores the complete matching operation, with the existing history compatibility checks. No-op matches do not create an undo step.

## Verification and limits

Tests include numeric contour-flash suppression without destroying the stable centre, brush add/subtract/fade/empty points, full-source crop projection, section isolation, encoded repair output, backup roundtrip, protected per-shot settings, version checkpoints, whole-pool undo/redo, cancellation and the existing queue/archive/RAW/HDR regression. The export regression caught and fixed an interaction with the ordinary brush export cache that could omit the new repairs; repair rasters now use their own bounded cache.

Reader build 57 is required for new backups; queue schema 12 protects the new repair metadata from older readers. Current-build native and UI evidence is retained in `Verification/0.52.0`. Simulators do not establish older-device temperature or battery performance. No external beta or App Store submission is performed.
