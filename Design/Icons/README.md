# Stillarc Studio identity

Approved 13 November 2026: a flat arc-based S, neutral-to-cobalt color split, and continuous before/after line with a small midpoint handle. Dark and light masters were created with built-in image generation and explicitly approved by the user. Prompt direction: professional geometric arc S, consistent stroke weight, neutral left/cobalt right, actual comparison line, flat restrained finish.

The master PNGs in Approved are the source of truth. scripts/render-icon.swift only resamples them to opaque sRGB 1024px app icons or 256px in-app artwork. StudioMark reuses this same artwork in the workspace header and About sheet. iOS supplies the Home Screen corner mask; the in-app mark applies a rounded-square clip. No rendering/editor behavior changes in 0.31.2 (35).

Regenerate from the repository root:

```
swift scripts/render-icon.swift StillarcStudio/Assets.xcassets/AppIcon.appiconset/AppIcon.png
swift scripts/render-icon.swift StillarcStudio/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png --dark
swift scripts/render-icon.swift StillarcStudio/Assets.xcassets/StudioBrand.imageset/Studio-Light.png --brand
swift scripts/render-icon.swift StillarcStudio/Assets.xcassets/StudioBrand.imageset/Studio-Dark.png --brand --dark
```
