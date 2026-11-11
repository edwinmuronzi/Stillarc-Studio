# Stillarc Studio

**Your light. Your color.** A native photo editor for iPhone and iPad, with a black-and-blue interface and reversible, local edits.

This is the **0.4 color-grading milestone**, not a finished PeekLUT/Lightroom replacement. The long-term scope is in [the roadmap](Docs/ROADMAP.md), with [research and source links](Docs/RESEARCH.md). The separate camera companion is [Stillarc Camera](https://github.com/edwinmuronzi/Stillarc-Camera).

<p><img src="Docs/Screenshots/Workspace.png" alt="Stillarc Studio workspace" width="280"> <img src="Docs/Screenshots/ColorWheels.png" alt="Stillarc Studio color wheels" width="280"></p>

[Wheels, channel mixer, curves and color-mix screenshots](Docs/Screenshots)

## What works in this milestone

- Open a photo from Photos or Files. Supported JPEG, HEIF, PNG, TIFF and RAW originals are copied into the local Studio workspace. RAW support depends on Apple's decoder and the source camera.
- Adjust exposure, contrast, highlights, shadows, whites, blacks, warmth, tint, saturation and vibrance. Controls update the preview while dragging, without a debounce wait.
- Choose Original, Daylight, Blue Hour, Silver, Ember or Soft Print. These are original creative treatments, not measured film-stock emulations.
- Add grain, bloom, fade or vignette; adjust sharpening and conventional noise reduction. Bloom softly spreads bright light; grain adds texture.
- Shape brightness and color with draggable five-point Master, Red, Green and Blue curves. Choose any point for exact numeric entry, reset an individual point/channel, or reset the Curves section. Shape-preserving interpolation avoids unintended overshoot. The earlier three tone controls remain under Additional tone shaping.
- Refine Reds, Oranges, Yellows, Greens, Aquas, Blues, Purples and Magentas independently, with hue (±30°), saturation and brightness controls. Neighboring ranges blend softly; neutral grays are excluded from selective hue edits.
- Grade Shadows, Midtones, Highlights and Global with a draggable color wheel, hue/strength controls and independent brightness in EV. Balance and Blend shape the three tonal regions; Keep brightness limits tint-driven brightness changes and protects neutral black/white endpoints.
- Mix red, green and blue inputs for each output channel, with negative coefficients, per-channel offsets, a red/blue swap action and monochrome conversion. Mixing is performed in linear light.
- Use Show range to inspect affected colors before wheels, mixer and film effects. Unselected colors dim. This temporary view is never saved in presets or exported.
- Choose an aspect ratio, drag the fitted photo to reposition the crop, rotate 90 degrees, or straighten up to 15 degrees. Straightening trims the edges to avoid black corners. Framing sliders provide another way to position the crop. Pinch/double-tap to inspect; a zoomed preview pans for inspection.
- A blue dot beneath each editing tab shows that the section has active adjustments. Dots follow undo/redo, presets, reopening and reset. Returning a section to neutral clears its dot.
- Tap an adjustment number to enter an exact value; double-tap the slider row to reset that value. Reset one section or the entire photo, with undo. Whites shapes the brightest tones; Blacks shapes the darkest.
- Hold Compare to see the original with the current framing. Undo/redo adjustment gestures without altering the source.
- Autosave adjustments, reopen projects, create/delete presets, and import/export versioned Studio JSON presets. Presets exclude crop, rotation and straightening. Existing 0.1/0.2/0.3 projects and presets load with neutral defaults for new controls; RGB curves, selective colors, wheels and mixer settings are included in project/preset saves. Use a current Studio version when sharing presets that use newer tools.
- Export a full-resolution JPEG (96% quality) or lossless 8-bit PNG in sRGB/SDR; share to Files or save a new copy to Photos. Location and other original metadata are omitted in this initial export path.
- Delete a Studio project without deleting the source in Photos/Files.

No sign-in, server processing, analytics SDK or upload is required. Imported project copies use local application storage. System device backups and iCloud-sourced imports remain subject to the user's Apple settings. Uninstalling Studio removes its local workspace; export important work first.

## Designed for responsiveness

RGB curves use bounded cached 1024-sample float tables. Selective color, wheels and channel mixing share one Core Image color kernel, using Metal stitchable functions on compatible GPUs and the portable Core Image kernel path on older hardware. Compilation and a small warm-up render happen on the decode worker before editing; no 3D LUT is rebuilt for each slider move. Neutral settings bypass the color stages. A mixer-only edit takes a simpler linear-light path without hue/tone calculations.

The preview is decoded once, capped at 1600 pixels on its long edge and rendered directly with Core Image/Metal. The view draws on changes, with one GPU submission in flight and newest-state coalescing; it has no perpetual display loop. Import and full-resolution export run away from the main actor. The preview pauses behind export/preset sheets and when the scene is inactive. Photo export reopens the original, so preview sizing does not reduce exported dimensions.

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

Masks, healing, LUTs, Log conversion, HDR export, batch work, metadata controls, video and Camera/Studio preset exchange are **planned**, not available in this build. Studio presets are not yet compatible with Camera presets. A LUT can encode compatible color transformations, but cannot encode grain, bloom, sharpening, masks or geometry.
