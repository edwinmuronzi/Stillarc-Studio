# Combined LUTs · 0.47

A combined `.cube` file contains two colour tables. The first reshapes each red, green and blue channel; the second mixes those colours into the final look. Studio now imports both as one Film layer, keeping their original samples and stage order. You do not need to split the file into two layers.

Use **Film → Import .cube LUT** and choose a display-sRGB creative LUT. The details show **1D + 3D** and both table sizes. Use LUT strength or bypass as usual. Additional layers, reordering, Undo/Redo, saved looks, selective colour sync, photo/video exports and queued exports use the complete combined result. [Try the small example](Samples/Stillarc-Combined-Example.cube).

Supported: Resolve-style files with 2–4096 1D samples, 2–65 samples per 3D axis, up to 20 MB. The file stores all 1D rows first, followed by red-fastest 3D rows. Each stage accepts its own scalar `LUT_1D_INPUT_RANGE` / `LUT_3D_INPUT_RANGE`; omitted ranges default to 0–1. Combined files with ambiguous `DOMAIN_MIN/MAX` are rejected with guidance. Standalone tables retain their existing per-channel domain support. This does not automatically identify a LUT's colour space: arbitrary Log/HDR/scene-linear technical LUTs remain unsupported in Film; use the matching **Input** profile before creative display-sRGB grading.

Both stages run in display-sRGB inside the existing linear working pipeline, with one input and output transfer around the complete pair. Strength blends the whole result once in linear light. Original small 1D tables are cached; they are not resampled into the 3D cube. Parsing, validation and fingerprints happen during import, not slider moves. Zero strength bypasses both stages. There is no ongoing analysis job.

Presets containing a combined LUT use schema 8. New look-library and project packages require reader build 52; delivery queue schema 9 protects combined assets while reading earlier supported queues. Legacy standalone LUT fingerprints remain unchanged. Colour-only LUT export can bake the full creative stack into the existing 33³/65³ output, which is a sampled approximation; source projects and backups keep the original separate tables.

Format reference: [OpenColorIO's Resolve Cube implementation](https://github.com/AcademySoftwareFoundation/OpenColorIO/blob/main/src/OpenColorIO/fileformats/FileFormatResolveCube.cpp). This feature supports that two-stage layout, not an arbitrary colour-management graph.
