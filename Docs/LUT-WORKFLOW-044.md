# LUT workflow — 0.44

**Import .cube LUT** now accepts standalone 1D tables with 2–4096 points per channel, alongside existing 3D cubes with 2–65 points per side. Import from Looks & presets or add a layer under Film → LUT stack. A 1D LUT shapes red, green and blue independently, like imported channel curves; a 3D LUT can mix channels to reshape colours together. Film shows the type and point count so you can tell what you imported.

[Try the gentle 1D example](Examples/Stillarc-1D-Gentle.cube): save it to Files, then import it in Studio. It is a creative display-sRGB curve, not a camera Log conversion. Strength is adjustable and zero bypasses the layer. You can mix 1D and 3D LUTs within the existing three-layer stack, bypass/reorder layers, undo/redo, copy/sync the grade and save a preset.

Both types expect display-sRGB creative input/output after Input conversion. Standard DOMAIN_MIN/DOMAIN_MAX per-channel domains and matching LUT_1D_INPUT_RANGE/LUT_3D_INPUT_RANGE scalar headers are supported. Inputs outside the declared domain clamp to its endpoints. Quoted titles may contain #; trailing # comments remain supported. Mixed/duplicate domain declarations, malformed data and files combining 1D and 3D tables are rejected rather than guessed. Standalone 1D does not establish support for technical Log/HDR shapers or combined shaper/cube files.

The original 1D samples are retained and sent to a cached, small GPU table without resampling into a 3D cube. Import/validation and cache creation run off the UI actor. Tables remain immutable and shared by undo states. No per-frame image readback, new analysis loop or table rebuild while changing strength is added. Full-resolution photo/video export and colour-only 33/65-point LUT baking use the same grade. Exporting the current grade as a colour LUT still produces a 3D approximation and excludes spatial/source-specific edits.

1D grades use preset schema 7. New source and saved-look backups require reader build 49 (0.44), and new queue records use schema 6. Current Studio still reads older presets/backups/queue records. Older 3D LUT fingerprints stay unchanged, preserving duplicate detection and existing looks. Camera/Studio preset interchange remains separate work.

Validation covers independent-channel interpolation, domains/endpoints, premultiplied alpha, linear-light strength blending, mixed stack ordering, malformed files, old 3D decoding/fingerprints, preset/library/transfer round trips, colour-LUT baking and animated HDR/direct/queued video output. Native sustained results are in Verification/0.44.0.

Technical references: [Apple CIColorCurves](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/colorcurves()), [FFmpeg reference .cube reader](https://www.ffmpeg.org/doxygen/8.0/vf__lut3d_8c_source.html), and the Adobe Cube LUT Specification 1.0 format. Studio deliberately supports a bounded subset; it does not claim every .cube variant or arbitrary input colour space.
