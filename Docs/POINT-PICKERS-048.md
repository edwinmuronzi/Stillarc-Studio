# Preview pickers · 0.48

## White balance
In **Color → All colors**, open **White balance picker**. Tap a grey or white surface that should have no colour cast. Studio averages a small patch and sets the existing Warmth and Tint controls together. Review the result, because mixed lighting and coloured surfaces can need manual adjustment. Clipped highlights, deep shadows, transparent patches and colours outside the supported slider range are rejected without changing the edit. This is a bounded neutral-colour adjustment, not automatic scene understanding or a calibrated RAW white-balance measurement.

## Levels
Open **Curves → Levels → Pick black point** or **Pick white point**. Tap the tone you want to become black or white. The picker sets the corresponding input control, preserving gamma and output limits. It uses the patch's linear luminance, not three independent RGB endpoints. Black remains below white; invalid crossing choices leave the existing edit intact. **Reset Levels** restores all five Levels controls. Undo/Redo restores each complete action.

Both pickers keep a large preview and adapt to landscape. A ring marks the chosen patch. Samples are taken from the underlying image before the relevant adjustment stage, after input conversion/exposure and framing. Looks, LUTs, masks, repairs and replacement backgrounds do not bias the measurement; they remain visible in the preview, so creative colour changes can still tint a neutral surface afterward. Choose an original, unretouched foreground area. HDR uses the same normalized grading input as the renderer.

Video freezes the current editor position for sampling, rather than analyzing every frame. One selection adjusts the whole clip. The editor preview/scopes pause behind the sheet. Patch averaging and bounded white-balance solving run off the UI actor only on tap, with one worker context per solve. Work is cancelled when leaving or backgrounding the picker, and stale results cannot overwrite a changed recipe. No polling, background inference, new image-rendering pass or extra per-frame adjustment is added.

These pickers write existing Warmth/Tint and Levels values, so existing slider resets, adjustment dots, pool history/sync, versions, presets, source backups and direct/queued photo/video exports keep working. No new recipe schema is required. Physical validation and test limits are recorded in `Verification/0.48.0`.
