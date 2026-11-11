# Stillarc Studio

**Your light. Your color.** A native photo and single-clip video editor for iPhone and iPad, with a black-and-blue interface and reversible, local edits.

This is the **0.12 brush masks milestone**, not a finished PeekLUT/Lightroom replacement. The long-term scope is in [the roadmap](Docs/ROADMAP.md), with [research and source links](Docs/RESEARCH.md). The separate camera companion is [Stillarc Camera](https://github.com/edwinmuronzi/Stillarc-Camera).

<p><img src="Docs/Screenshots/Workspace.png" alt="Stillarc Studio workspace" width="280"> <img src="Docs/Screenshots/ColorWheels.png" alt="Stillarc Studio color wheels" width="280"></p>

[LUTs, wheels, channel mixer, curves and color-mix screenshots](Docs/Screenshots)

## What works in this milestone

- Choose **Masks → + Brush**, then paint directly on the fitted image. **Eraser** removes selected areas; **View** restores preview controls and video scrubbing. Painting pauses video and hides preview overlays so the image is unobstructed. Guide shows the selected region in red; change Exposure or the other local controls to affect it.
- Expand **Brush size & soft edge** to set the radius and softness of new strokes. Existing strokes keep the tip they were painted with. Layer Strength blends the complete painted mask. Undo/redo works by whole stroke; Clear painted area is also undoable. Paint/Eraser add/remove the final selected area even with Invert enabled.
- Brush vectors save with the project and complete versions; they stay out of reusable grades and copied adjustments. Each brush layer supports up to 64 strokes and 2,048 points per stroke, within the existing four-layer mask limit. Lift and start another stroke at the point limit. Masks remain fixed across video; there are no tracking/keyframes or AI subject masks yet.

- Open **Masks**, add **Linear** for a gradual adjustment across the frame or **Radial** for an oval area. Drag the center in the fitted preview; expand **Shape, position & feather** to resize, rotate or soften the edge. Adjust local exposure, warmth, saturation and contrast, blend with Strength, invert the area, or switch the adjustment off. Keep up to four layers; overlapping layers apply in order.
- The **Guide** eye button shows the selected area in red; the red guide never appears in exports and scopes read the actual grade. Masks work with photos and video, save with the project and complete versions, and support undo/redo. They are anchored to the current cropped frame—not tracked subjects—so reframing changes their relationship to the scene. Creative presets and copied grades exclude spatial masks; applying either preserves destination masks. Video masks are static across the clip, without keyframes. Subject/sky AI selection and motion tracking are not available yet.

- Open **Looks → Copy adjustments** and choose sections to copy. On another photo or clip, open **Looks → Paste adjustments**, choose which copied sections to apply, and paste. Options include Light, White balance, Color & color mix, Curves, Color wheels, Channel mixer, Built-in look, LUT, Film texture and Detail. Selected sections replace existing values, including neutral/Off settings; unselected adjustments stay unchanged.
- Paste preserves each destination’s crop, flips, perspective, input profile/exposure, video trim, HDR choice, masks and saved versions. It is one undoable change and works between photos and video clips. The LUT travels with the internal clipboard; no media is duplicated or placed on the system clipboard. Copied settings survive app restarts until replaced or cleared from the Paste panel.

- Tap the **split comparison icon** beside Hold to compare, then drag the round divider. Original is on the left, your edit on the right, with matching framing. Comparison returns to a fitted view; turn it off to zoom normally. Photo and video share one decoded source/frame. The divider is a preview tool and never appears in exports. Scopes follow the displayed comparison.
- Open **Looks → Saved versions**, enter a name and save the complete current edit. Keep up to 20 named versions per photo/clip, including input conversion, framing, trim, HDR choice and LUT. Restore returns to the preview; Undo recovers the edit you had before restoring. Delete removes that saved snapshot, not the source. Versions stay with this project; Looks presets are for reusing grades on other media. No media files are duplicated.

- Tap **Scopes** in the preview for an RGB histogram, RGB waveform or color vectorscope. The histogram shows where dark/bright tones sit; the waveform shows brightness across the image; the vectorscope shows color direction and saturation. These are sampled preview guides, not full-resolution or RAW sensor measurements.
- In Crop, choose **Free** to change width and height independently, then drag the image or use framing sliders to position it. Flip horizontally/vertically, correct leaning buildings with horizontal/vertical perspective, rotate, or straighten a horizon. Perspective correction trims edges to avoid empty corners. Crop reset and undo restore the earlier framing; saved creative presets keep each source’s geometry intact.

- Open a photo or video from Photos or Files. Videos up to 4K can be played, scrubbed, graded with the same tools, and exported as a new HEVC movie with original audio tracks and frame timing. Trim the start/end without changing the original. This is a single-clip workflow, without a multi-clip timeline.
- Export video as SDR or **10-bit HLG HDR**. HDR preserves brighter highlights on compatible displays; SDR gives the widest sharing compatibility. HLG/PQ-tagged HDR input is recognized automatically and starts with HDR output enabled. HDR video uses extended-range live previews on compatible screens. Photo exports remain SDR JPEG/PNG.
- Convert Apple Log (BT.2020) or Apple Log 2 (Apple Wide Gamut) into the linear grading pipeline before creative looks/LUTs. Recognized video Log metadata selects the input automatically; use **INPUT** to override it for untagged clips or imported Log still frames. Input exposure and optional soft highlights help fit bright scenes into SDR. This is Studio’s own rendering, not Apple’s official conversion LUT. RAW photos use Apple’s RAW development instead.
- Supported photo originals: JPEG, HEIF, PNG, TIFF and RAW originals are copied into the local Studio workspace. RAW support depends on Apple's decoder and the source camera.
- Adjust exposure, contrast, highlights, shadows, whites, blacks, warmth, tint, saturation and vibrance. Controls update the preview while dragging, without a debounce wait.
- Choose Original, Daylight, Blue Hour, Silver, Ember or Soft Print. These are original creative treatments, not measured film-stock emulations.
- Add grain, bloom, fade or vignette; adjust sharpening and conventional noise reduction. Bloom softly spreads bright light; grain adds texture.
- Shape brightness and color with draggable five-point Master, Red, Green and Blue curves. Choose any point for exact numeric entry, reset an individual point/channel, or reset the Curves section. Shape-preserving interpolation avoids unintended overshoot. The earlier three tone controls remain under Additional tone shaping.
- Refine Reds, Oranges, Yellows, Greens, Aquas, Blues, Purples and Magentas independently, with hue (±30°), saturation and brightness controls. Neighboring ranges blend softly; neutral grays are excluded from selective hue edits.
- Grade Shadows, Midtones, Highlights and Global with a draggable color wheel, hue/strength controls and independent brightness in EV. Balance and Blend shape the three tonal regions; Keep brightness limits tint-driven brightness changes and protects neutral black/white endpoints.
- Mix red, green and blue inputs for each output channel, with negative coefficients, per-channel offsets, a red/blue swap action and monochrome conversion. Mixing is performed in linear light.
- Import display-sRGB 3D `.cube` LUTs from Files, with 2–65 points per side, `DOMAIN_MIN`/`DOMAIN_MAX` support and a 20 MB input limit. A LUT remaps colors for a consistent finish. Adjust LUT strength live under Film, turn it off at zero, or remove it. The imported LUT is also saved as a reusable look; import keeps your current adjustments. Applying a saved look replaces the color/film recipe while preserving framing.
- In Looks, save your complete current grade, including its LUT, as a named preset. Export/import the self-contained Studio JSON to reuse it without the original `.cube` file. LUT presets use schema 2 and require Studio 0.5 or later; earlier schema-1 presets remain supported.
- Use Show range to inspect affected colors before wheels, mixer, LUT and film effects. Unselected colors dim. This temporary view is never saved in presets or exported.
- Choose an aspect ratio, drag the fitted photo to reposition the crop, rotate 90 degrees, or straighten up to 15 degrees. Straightening trims the edges to avoid black corners. Framing sliders provide another way to position the crop. Pinch/double-tap to inspect; a zoomed preview pans for inspection.
- A blue dot beneath each editing tab shows that the section has active adjustments. Dots follow undo/redo, presets, reopening and reset. Returning a section to neutral clears its dot.
- Tap an adjustment number to enter an exact value; double-tap the slider row to reset that value. Reset one section or the entire photo, with undo. Whites shapes the brightest tones; Blacks shapes the darkest.
- Hold Compare to see the original with the current framing. Undo/redo adjustment gestures without altering the source.
- Autosave adjustments, reopen projects, create/delete presets, and import/export versioned Studio JSON presets. Presets exclude crop, rotation and straightening. Existing 0.1/0.2/0.3/0.4 projects and presets load with neutral defaults for new controls; RGB curves, selective colors, wheels, mixer and LUT settings are included in project/preset saves. Use a current Studio version when sharing presets that use newer tools.
- Export a full-resolution JPEG (96% quality) or lossless 8-bit PNG in sRGB/SDR; share to Files or save a new copy to Photos. Location and other original metadata are omitted in this initial export path.
- Delete a Studio project without deleting the source in Photos/Files.

No sign-in, server processing, analytics SDK or upload is required. Imported project copies use local application storage. System device backups and iCloud-sourced imports remain subject to the user's Apple settings. Uninstalling Studio removes its local workspace; export important work first.

## Try a LUT

1. Save [Studio Cool.cube](Docs/Examples/Studio-Cool.cube) to Files on your iPhone, or use your own display-sRGB creative LUT.
2. Open a photo, tap **Looks → Looks & presets → Import .cube LUT**, and choose the file. It is applied to the current edit and saved in Your presets for later use.
3. Open **Film → LUT strength** and drag to blend the effect. Zero leaves the other adjustments active; Remove detaches the LUT.
4. Use **Looks → Looks & presets → Save current adjustments** to keep the LUT together with your other edits. Use a preset's menu to export the portable Studio JSON or delete it. Exporting a preset does not produce a new `.cube` file.

The included Studio Cool LUT is a subtle original demonstration, not a camera conversion or measured film emulation.

[Conversion design and primary references](Docs/LOG-CONVERSION.md)

## Convert and grade a Log clip

1. Use **Open photo or video** or the Files button. Studio copies the original into its local workspace.
2. Tap the **INPUT** badge. Choose Apple Log or Apple Log 2 if the source metadata did not identify it. Standard leaves normal footage color-managed without a Log transform. Do not guess the input profile from how flat a clip looks.
3. Adjust input exposure/soft highlights, then grade with Light, Color, Curves, Mix, Wheels and Film. Play/pause or scrub beneath the preview; hold Compare for the unconverted original.
4. Tap **scissors** beside Play to choose start/end points. The trim sheet previews the retained range; adjust an endpoint to inspect it. Undo or **Use entire clip** restores the previous/full range.
5. Choose **HDR preview & export** in INPUT, or **HDR video · HLG** in Export. HDR always uses 10-bit HEVC, Rec.2020 primaries and HLG transfer. SDR offers 10-bit or 8-bit HEVC, Rec.709 primaries and sRGB transfer. Share/save to Files or add a new copy to Photos. Frame cadence and audio are retained within the chosen range, with a zero-based exported timeline. Source dimensions stay full-size unless framing changes them, with even pixel dimensions for HEVC.

Only Apple Log and Log 2 camera Log conversion are supported currently; HLG/PQ video is color-managed automatically. Videos larger than 4K are rejected with an explanation. HDR output is HLG, not Dolby Vision, HDR10+ or Log. Source conversion, trim and HDR choice are saved with the project and excluded from creative presets. A source that was already SDR does not gain missing highlight detail simply by choosing HDR.

HDR grading keeps per-pixel highlight headroom outside the display-referred creative tools and restores it after grading. The SDR input shoulder is bypassed for HDR output. Curves, creative looks and LUTs can still intentionally alter/compress highlight appearance. HDR display brightness depends on the device, display settings and available headroom. Choosing SDR contains output to SDR; it is not a Dolby Vision tone-map match.

The editor header owns its window-safe insets, including after foregrounding, rotation and export-sheet presentation, so Back/Undo/Export stay below the status bar and away from the camera cutout.

## Designed for responsiveness

Brush preview rasterization uses a serial background worker with newest-request coalescing, incremental drawing and at most eight cached raster contexts. Preview mask resolution is capped at 768 pixels on its long edge; a completed raster wakes a paused preview without reopening media. Full exports replay the vectors at the full framed-source size with 16-bit grayscale coverage. Video export prepares each brush mask once for the entire clip. No per-frame stroke replay or permanent low-resolution export mask is used. The original media stays untouched.

Linear/radial masks use native Core Image gradients and GPU blending, capped at four layers. Neutral/disabled/zero-strength layers bypass their processing. Filter warm-up runs on the decode worker before editing. Masks share the existing bounded preview, one GPU submission in flight and full-source export path; the guide is a separate preview-only composition in that same submission. Masks are applied after global grading and framing. HDR uses the existing normalized creative pipeline and restores headroom afterward.

Copy builds a small immutable instruction snapshot; LUT data shares immutable storage in memory. Clipboard encoding/decoding and atomic file writes run on the storage actor, once per explicit copy, rather than on slider changes. The clipboard file is excluded from media-project indexing. Paste changes the existing recipe in one transaction; it does not reopen the original, create a new player or process/export media. Preview playback and scope sampling pause while either copy/paste panel is open.

Split comparison composites two graphs from the same source/frame into one Metal command; it does not create a second player. With comparison off, the extra graph is skipped. Saved versions are immutable recipe files created only on explicit Save. Ordinary autosave updates a small version index instead of re-encoding every saved LUT/recipe. Restoring decodes the chosen snapshot on the storage actor. Versions are local app data; deleting the project or uninstalling Studio removes them.

Scopes sample a 128×72 graded image on a utility worker, at most five times per second with one analysis in flight. They stop when hidden, covered by a sheet or inactive. Waveform/vector rasters are built away from the UI actor. RGB histogram density uses a log-height display; SDR levels use sRGB 0–100%, while HDR levels use linear 0–8× SDR white. Vectorscope chroma is normalized for super-white pixels. Small details may be missed by sampling. Scope display never changes the exported pixels.

RGB curves use bounded cached 1024-sample float tables. Selective color, wheels and channel mixing share one Core Image color kernel, using Metal stitchable functions on compatible GPUs and the portable Core Image kernel path on older hardware. Compilation and a small warm-up render happen on the decode worker before editing; no 3D LUT is rebuilt for each slider move. Neutral settings bypass the color stages. A mixer-only edit takes a simpler linear-light path without hue/tone calculations.

The preview is decoded once, capped at 1600 pixels on its long edge and rendered directly with Core Image/Metal. The view draws on changes, with one GPU submission in flight and newest-state coalescing; it has no perpetual display loop. Import and full-resolution export run away from the main actor. The preview pauses behind export/preset sheets and when the scene is inactive. Photo export reopens the original, so preview sizing does not reduce exported dimensions.

LUT files are parsed and validated away from the UI actor. Immutable float tables are shared by undo states, not rebuilt or hashed during slider moves. LUTs run after built-in looks and before texture/detail; zero strength skips the LUT stage. Input/output numbers are interpreted as display sRGB, with explicit transfer curves around the cube in the linear working pipeline. Non-default input domains are normalized, and inputs outside the domain clamp to its edges. One LUT can be active at a time. Camera input conversion is separate and happens before creative grading. Creative LUTs still need to target display sRGB; a camera conversion LUT would double-convert an input already set to Apple Log/Log 2. 1D shapers, combined shaper/3D files, LUT stacking and LUT-file export are not supported yet.

Video playback runs up to 30 preview frames per second and grades a bounded 1280-pixel preview with at most one GPU submission in flight. Playback pauses when covered/inactive; paused settled frames stop rendering. Export processes the full source, uses progress/cancellation, yields more at fair thermal state and pauses at serious/critical state without reducing output resolution or skipping frames. Backgrounding cancels an active export safely.

This architecture reduces unnecessary work; it is not a guarantee of zero heat, battery use or lag. Physical-device thermal and large-RAW behavior need continued measurement. See [validation](Docs/VALIDATION.md).

## Build and install

Requires a Mac with Xcode supporting the project's `project.xcproj` format, currently Xcode 27, and iOS/iPadOS 17 or later. Actual RAW decoding support varies by OS. Older devices are a compatibility target, not yet certified for performance.

1. Clone or download this repository and open `StillarcStudio.xcodeproj`.
2. Select the StillarcStudio scheme and your connected iPhone/iPad.
3. In Signing & Capabilities choose your own development team. Change the bundle identifier if needed.
4. Enable Developer Mode on the device if Xcode asks, then Run.

A free Apple Personal Team is suitable for development installation; it is not a public App Store or TestFlight distribution channel. No public download is available yet.

```sh
xcodebuild -project StillarcStudio.xcodeproj -scheme StillarcStudio \
  -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

Debug verification instructions are in [Docs/VALIDATION.md](Docs/VALIDATION.md). The sample scene is an owned AI-generated illustration reused from the Stillarc Camera marketing library; it is not presented as a photograph captured with either app. The blue arc/S icon is an original provisional Studio mark rendered by `scripts/render-icon.swift`.

## Important boundaries

AI masks, motion tracking, healing, HDR photo export, batch work, metadata controls, multi-clip video timelines and Camera/Studio preset exchange are **planned**, not available in this build. Studio presets are not yet compatible with Camera presets. A LUT can encode compatible color transformations, but cannot encode grain, bloom, sharpening, masks or geometry.
