# Stillarc Studio: research and product decisions

Research date: 11 November 2026. This is a desk-research brief based on official feature descriptions plus a small convenience sample of public user discussions. It is not a usability study, a representative survey, or a hands-on benchmark of competitors. Competitor feature claims below are attributed to their publishers; their performance claims are not independently verified. No competitor code, artwork, UI assets, film profiles or copy are incorporated.

## Reference applications

| Reference | Useful precedent | Studio decision |
| --- | --- | --- |
| [PeekLUT](https://peeklut.app/) | Photo/video grading, LUT workflows, film treatment, masks and technical color conversion | Long-term grading scope; first prove the photo renderer and export path |
| [Lightroom mobile](https://helpx.adobe.com/in/lightroom/mobile.html) | RAW workflow and local adjustments | Make dependable development and reversible edits the foundation |
| [Lightroom masks](https://helpx.adobe.com/lightroom/mobile/masks-and-selective-adjustments/manage-masks-in-lightroom.html) | Refinable local selections | Prioritize brush/gradient masks before automated selection |
| [Lightroom gestures](https://helpx.adobe.com/lightroom/mobile/get-started/gesture-controls-in-lightroom-for-mobile.html) | Direct comparison and inspection | Hold to compare; pinch/double-tap the preview |
| [Lightroom optics](https://helpx.adobe.com/lightroom/mobile/adjust-light-and-color/correct-lens-distortions.html) | Profile-based distortion/fringing correction | Add explicit optics tools after reliable crop/rotation |
| [Darkroom](https://darkroom.co/) | Apple-focused, reversible editing and a library-oriented workflow | Keep Studio native and avoid mandatory account setup; initial project copies make file ownership explicit |
| [Photomator](https://apps.apple.com/us/app/photomator-photo-editor/id1444636541) | Broad RAW adjustments, color tools, masks and batch workflows | Add color precision and batch work after core correctness |
| [Capture One Color Editor](https://support.captureone.com/hc/en-us/articles/360002601358-The-Color-Editor-overview) | Targeted color ranges and skin-tone consistency | Later selected-color controls should show which pixels are affected |
| [DaVinci Resolve Color](https://www.blackmagicdesign.com/products/davinciresolve/color) | Professional grading and color inspection | Later managed grading order, wheels and scopes; no desktop node graph in the initial phone UI |
| [Dehancer](https://www.dehancer.com/features) | Separate film response, grain and highlight effects | Develop our own film system; don't label generic filters as measured stock emulation |
| [Snapseed Brush](https://support.google.com/snapseed/answer/6157715?hl=en) | Local light/color manipulation directly on the image | Build touch-first local adjustment tools after the global pipeline |

## What users appear to need

Several people report [slow Lightroom exports](https://www.reddit.com/r/Lightroom/comments/1jgs38z/) and [Darkroom performance trouble](https://www.reddit.com/r/darkroomapp/comments/1kufn0v/). A separate discussion describes [confusing Lightroom local/cloud ownership](https://www.reddit.com/r/Lightroom/comments/1nqamto/lightrooms_mobile_workflow_is_unusable/). Another reports [exports looking different from the editor](https://www.reddit.com/r/Lightroom/comments/1cx6253/). These are individual experiences on varying devices/versions; they do not establish how common the issues are or diagnose their causes.

Our resulting hypotheses, to validate with actual users:

1. A visible response during a drag matters more than a giant menu of unproven tools.
2. People need to know where originals, edits and exports live, especially offline.
3. An export should match the intended grade and preserve expected dimensions; export status must be understandable.
4. Reversible adjustments, reset, before/after and dependable autosave make experimentation safe.
5. Presets should reduce repeat work without forcing a complex professional workflow.
6. A clean phone interface should explain advanced tools in normal language and remain usable with larger text and assistive technology.

## Technical direction

Apple documents [event-driven MTKView drawing](https://developer.apple.com/documentation/metalkit/mtkview/enablesetneedsdisplay) and recommends control-driven rendering for image editing in [its Core Image/Metal session](https://developer.apple.com/videos/play/wwdc2022/10114/). Studio uses that pattern instead of a continuous render loop. The display path shares its adjustment graph and sRGB output transform with export. Preview size is bounded; export starts from the original. Import/decode/export are separate from UI state, and saved recipes are atomic versioned documents.

## Next research, before claiming parity

Conduct task-based sessions with photographers and casual users: import a RAW, correct a portrait, create a film look, reuse it, compare, reopen and export. Record time-to-first-preview, slider-to-display timing, preview/export differences, peak memory, thermal state, energy and recovery after interruption. Include a compact older iPhone and iPad. Add feedback about missing tools to the roadmap, without interpreting a few online comments as market-wide demand.

## Expanded workflow evaluation (12 November 2026)

[Studio and timeline product direction](PRODUCT-DIRECTION.md) compares the current implemented tools with publisher-described photo, grading and timeline workflows. It proposes editing pools and subject/background improvements first, and a separate timeline companion later. These are proposals, not implemented feature or competitor-parity claims. External beta and App Store work are explicitly deferred.
