# Moving-mask finishing and reliability · 0.50

## Longer People video mattes

Open **Masks → Add mask → People video matte** or **Remove video background**. The kept range can now contain up to **12 seconds, 360 source frames and 16 MB of saved probability masks**. At 60 fps the frame budget permits six seconds. Every kept source frame is processed once; source frames are not skipped to fit a longer clip. The original video/export dimensions are unchanged. Saved matte detail remains bounded to 1536 pixels on the longest edge, not original sensor detail.

Preparation checks temporary storage, runs on the existing utility worker, reuses a sequential People model and stops for cancellation, backgrounding or serious thermal pressure. An explicit Cancel processing button remains available. Failed or interrupted work does not replace the existing edit. Restart preparation after returning to Studio; this release does not resume an incomplete matte. Playback/export decode only the currently needed saved masks through the bounded cache, without model inference.

In **Refine automatic selection**, **Fine detail** retains more soft probabilities (such as hair), while **Clean edge** tightens/shrinks the border to reduce spill. **Reset edges** restores defaults. These reversible shortcuts use the existing refinement engine, not a new semantic model or guaranteed hair reconstruction. Undo/Redo works; threshold, transition, grow/shrink and softness remain individually adjustable. Inspect moving hair, transparency, blur and occlusion over your actual replacement background.

## Recover a lost track deliberately

**Track mask → Keep reliable tracking if target is lost** retains a usable path only after at least two reliable samples. If tracking loses confidence, leaves the image or makes an implausible jump, a confirmation offers **Save reliable path for correction** or **Discard attempted track**. Discard preserves the previous track. Reader/render errors, cancellation and thermal stops do not produce partial successful updates.

A saved partial track holds its last reliable position/size/rotation through the remainder; Studio does not silently guess where the person/object went. Open **Correct tracking → Jump to tracking loss**, scrub to the returning subject, and adjust position, size and rotation. Manual corrections blend with the measured path and support Undo/Redo. The loss marker persists in versions/backups. Review the whole clip before exporting. Automatic reacquisition, optical-flow deformation and seamless occlusion reconstruction are not included.

## Colour and control checks

The existing managed preview/export pipeline is retained. This batch adds tagged P3 JPEG/PNG comparisons in a common linear working space, alongside existing RAW, Log, HDR, LUT-stack, trim/audio and direct/queued delivery regression. Standard remains the default for correctly tagged input. Changes to input interpretation invalidate a prepared matte rather than silently reusing the wrong analysis.

Edge shortcuts use one undo transaction. Buttons adapt to narrower layouts. Cancellation remains explicit, the main preview stays paused behind analysis sheets, and current feature help explains bounds in plain English. Backups written by this version require reader build 55 to preserve the larger mattes and tracking-loss marker.

## Performance and scope

The sustained preview workload now cycles 300 changing saved matte frames alongside three LUT layers, four flexible curve channels, four masks, HDR and animated corrections. Verification reports record device, timing, memory, inference and iOS thermal state; nominal thermal state is not a promise of zero warmth or universal battery performance.

Only the connected iPhone 17 Pro is available for native testing. Compact-device simulators check layout/logic, not older-phone energy or thermal performance. The supplied DNG and generated HDR fixtures are regression inputs; broader camera-original files and difficult real moving-hair/occlusion footage remain open gates. No App Store or external beta preparation is performed.
