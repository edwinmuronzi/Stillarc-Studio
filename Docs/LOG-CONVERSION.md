# Log input conversion

Studio 0.6 separates the recording profile from the creative look. The input transform decodes Apple's published piecewise Log curve, converts the source primaries into linear sRGB, applies source exposure and optionally fits highlights into SDR. Creative adjustments and display-sRGB LUTs follow. Standard bypasses the Log transform; RAW is developed by Apple's decoder instead.

Apple Log uses BT.2020 primaries. Apple Log 2 uses Apple Wide Gamut with the same transfer curve. Studio uses independently derived D65 matrix transforms and its own luminance-based SDR shoulder/gamut compression. It does not bundle Apple's official conversion LUT or claim to reproduce its rendering.

References:

- [Apple: Apple Log capture color space](https://developer.apple.com/documentation/avfoundation/avcapturecolorspace/applelog)
- [Apple: Apple Log 2 capture color space](https://developer.apple.com/documentation/avfoundation/avcapturecolorspace/applelog2)
- [OpenColorIO primary implementation and published curve/primaries references](https://github.com/AcademySoftwareFoundation/OpenColorIO/blob/main/src/OpenColorIO/transforms/builtins/AppleCameras.cpp)
- [OpenColorIO's Apple transform generator](https://opencolorio.readthedocs.io/projects/config-aces/en/latest/_modules/opencolorio_config_aces/clf/transforms/apple/generate.html)

The application has no OpenColorIO runtime dependency. Native AVFoundation/Core Video APIs supply video decoding, metadata, playback and encoding. A recognized Log metadata tag selects the initial profile, but untagged inputs require explicit selection. Do not apply a second camera conversion LUT after selecting a Log input.

Video output is an SDR HEVC movie, with Rec.709 primaries, sRGB transfer and Rec.709 YCbCr matrix. Default 10-bit encoding reduces additional quantization; it cannot restore precision missing from the source. Source frame presentation times and compressed audio tracks are retained. The initial release supports a single full clip up to 4K; it does not trim, merge clips, output HDR/Log or support other manufacturers' Log transforms.
