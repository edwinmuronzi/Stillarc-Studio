# Combined camera, colour and masking update · 0.49

## Share a colour look between the two apps

In **Stillarc Camera 1.3.7 → Look studio → Share colour with Studio**, prepare a `.cube`, then use Share/Save to Files or AirDrop. In **Studio → Film → Import LUT or save a look**, import it. It appears as one creative LUT; use a neutral built-in look and full LUT strength to avoid applying a grade twice.

For the other direction, use **Studio → Looks → Export current color as LUT** (33 or 65 points), save/share the `.cube`, then import it through **Camera → LUT → Import**. Camera exports its current style colour plus the enabled monitor LUT/strength into a 33³ table. Both routes are sampled SDR colour approximations. They exclude grain, halos, blur/sharpening, framing, local masks, HDR interpretation and camera exposure/focus settings. They do not synchronize native preset libraries or transfer complete project edits.

## Explicit input and photo output spaces

**Input conversion → Recorded profile** adds encoded sRGB, Display P3 and linear-sRGB manual overrides. Standard remains the correct default for ordinary correctly tagged images/video: Core Image already respects embedded colour metadata. Overrides reinterpret original RGB signal values; use them only when you know the intended encoding. Existing camera Log choices remain available. These controls do not turn Studio into an arbitrary ACES/working-space pipeline.

Delivery adds **SDR photo colour space → sRGB / Display P3**. The exported JPEG/PNG embeds the chosen profile. P3 preserves wider colour on compatible screens; sRGB is safer for broad sharing. HDR HEIF stays HLG Rec.2020, and video retains the selected SDR/HLG encoder colour settings. Queue snapshots and remembered preferences retain the photo choice. New queues use schema 10; source backups require reader build 54.

## Measure more mask motion

In **Masks → Track mask → Track movement**, choose the motion to analyse. Rectangle pose uses a visible rectangular card, sign or screen to estimate uniform size and rotation as well as position. This is rigid two-dimensional motion, not mesh or perspective deformation. Review the full clip and correct drift manually. Measured poses remain separate from manual correction points: clearing corrections restores the measured motion. Saved versions, source backups and direct/queued exports retain it.

## People video mattes and video background replacement

In a video, open **Masks → Add mask → People video matte** for a moving selection, or **Remove video background** for a cutout. The worker prepares a People matte for every kept source frame, using one sequential Vision request, then stores the results. No model inference runs during playback/export. All visible people are selected; arbitrary object video matting is not included.

Limits: up to **6 seconds, 180 source frames, 8 MB of saved probability masks, and 1536 pixels on the matte’s longest edge**. Frame rate determines how much duration fits; no source frames are skipped to meet the limit. Mattes are stored as 8-bit probabilities. The original video and its chosen export dimensions/frame timing are preserved; matte detail is not full-resolution sensor detail. Inspect hair, blur, low contrast, occlusions and transparency before delivery. This is a bounded tool, not a claim of perfect temporal roto.

Compatible crop/rotation/perspective changes project the saved full-frame mattes, and shortening a trim reuses source-time frames. Extending beyond analysed frames or changing input conversion requires rebuilding. A per-frame matte cannot also carry a separate rigid track. Existing static subject/sky selections keep their separate tracking workflow.

After removal, use **Replace background** for a colour, image or blurred original. Video export requires a composited background; transparent video-file export is not supported. The background sheet shows the first kept frame; return to the editor for moving playback. Processing cancels on dismissal/backgrounding and stops for serious thermal pressure. Failed/cancelled work leaves the previous edit unchanged. The preview/export worker decodes only the required saved mask, using the existing eight-image cache; it does not predecode an entire clip into memory.

## Photo finishing

**Subject → Selection method → Faces / Facial skin** creates soft face-guided starting selections. Facial skin excludes detected eyes, eyebrows and lips. It is not a pixel-perfect skin classifier; inspect and refine the guide. The selection method/name stays with the mask and is retained for compatible crop repair. A tapped-object selection will not silently become an all-subject selection after a framing change that needs new analysis.

**Detail → Photo development → Chroma noise cleanup** reduces coloured speckles while preserving original luminance detail. It uses bounded spatial filtering after input decoding, not generative denoising or multi-frame reconstruction. Fine colour edges can soften at high values. It is source-specific with the other optics controls; reusable colour presets do not carry it. RAW colour/luminance noise and calibrated lens correction remain dependent on the controls Apple’s decoder supplies for that camera/file. No unverified camera lens-calibration database has been added.

## Reliability and remaining validation

Export now checks estimated temporary storage before expensive work; actual encoder/disk failures still retain existing cleanup/error handling. Checks simulate low-space failure without filling the user’s disk. The disk-space preflight is declared in the privacy manifest for sufficient-space-before-writing use. Existing atomic import/restore, interrupted saves, large-library recovery, undo/redo and serial export paths remain under regression tests.

Native validation uses the available iPhone 17 Pro, the previously supplied camera-original DNG, generated HDR/audio/orientation fixtures, and a clearly attributed public NASA portrait animated into a short test clip. These do not cover real moving hair, all occlusions, every camera-original RAW/HDR variant or older physical phones. The 16 Pro is unavailable and no older physical device was supplied. Compact/iPad simulators can validate layouts and logic, not older-device battery, thermal behaviour or model performance. Those physical/real-footage gates remain open. No external beta or App Store preparation is included.

Measured results and screenshots are in `Verification/0.49.0` when the release checks complete.
