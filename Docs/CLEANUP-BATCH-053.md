# Photo cleanup and batch workflows · 0.53

## Photo cleanup
Open a photo → Detail → Heal & Clone. Heal borrows texture and blends it into the surrounding colour; Clone copies the source patch. Suggested source chooses nearby similar texture. Turn it off and Choose source when you want control. Brush with spaced dabs, zoom up to 6× and use Move view to inspect small areas. Undo/Redo handles a stroke together; Remove last dab and Clear offer finer control. The original media remains unchanged.

There is a 32-dab limit. This is local patch repair, not generative filling: a large missing object or complex background needs a suitable source. Export uses the same repair recipe as preview. Cleanup sampling runs once on opening; rendering runs when edits change.

## Subject selections
Masks → Add mask → Subject → Tap multiple subjects. Tap up to eight subjects, tap a marker to remove it, then Prepare & save. It selects distinct objects detected by the device; overlapping or tiny objects may not separate. Faces follows detected face contours. Facial skin uses cheek/forehead samples and excludes detected eyes, brows and lips; inspect facial hair, makeup and unusual lighting. Analysis runs on request and saved masks are reused in playback/export.

## Pool workflows
Hold Sync edits → Compare pool shots, or open Reference & Match → Compare pool shots. Browse targets and zoom both previews together. Cached comparison images are limited to 640 pixels and six items. Videos show the first kept frame, not synchronized playback; HDR is shown as an SDR proof.

Hold Sync edits → Select same media type / Select same input profile for quick targeting. In Sync edits, expand Saved section workflows, choose sections, enter a name and Save section choices. Choose a saved workflow to reuse those section choices. Delete workflow and Restore last deleted manage the list. A workflow stores choices, not frozen adjustment values; use Saved Looks for a reusable grade. Existing pool Undo/Redo applies to actual sync changes.

## Test on your media
- Heal a small blemish, manually choose a source, zoom/pan, Undo/Redo and export; check the saved photo against preview.
- Select two separated objects and check face/skin masks on different portraits.
- Sync only chosen sections across a pool, undo/redo the sync, reopen a saved workflow and compare shots.

Performance depends on media, device and other active adjustments. No claim of zero heat or perfect automatic selection is made.
