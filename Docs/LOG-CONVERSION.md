# Log input conversion

Studio 0.6 separates the recording profile from the creative look. The input transform decodes Apple's published piecewise Log curve, converts the source primaries into linear sRGB, applies source exposure and optionally fits highlights into SDR. Creative adjustments and display-sRGB LUTs follow. Standard bypasses the Log transform; RAW is developed by Apple's decoder instead.

Apple Log uses BT.2020 primaries. Apple Log 2 uses Apple Wide Gamut with the same transfer curve. Studio uses independently derived D65 matrix transforms and its own luminance-based SDR shoulder/gamut compression. It does not bundle Apple's official conversion LUT or claim to reproduce its rendering.

References:

- [Apple: Apple Log capture color space](https://developer.apple.com/documentation/avfoundation/avcapturecolorspace/applelog)
- [Apple: Apple Log 2 capture color space](https://developer.apple.com/documentation/avfoundation/avcapturecolorspace/applelog2)
- [OpenColorIO primary implementation and published curve/primaries references](https://github.com/AcademySoftwareFoundation/OpenColorIO/blob/main/src/OpenColorIO/transforms/builtins/AppleCameras.cpp)
- [OpenColorIO's Apple transform generator](https://opencolorio.readthedocs.io/projects/config-aces/en/latest/_modules/opencolorio_config_aces/clf/transforms/apple/generate.html)

The application has no OpenColorIO runtime dependency. Native AVFoundation/Core Video APIs supply video decoding, metadata, playback and encoding. A recognized Log metadata tag selects the initial profile, but untagged inputs require explicit selection. Do not apply a second camera conversion LUT after selecting a Log input.

SDR video output is an HEVC movie, with Rec.709 primaries, sRGB transfer and Rec.709 YCbCr matrix. Default 10-bit encoding reduces additional quantization; it cannot restore precision missing from the source. Source frame presentation times and compressed audio tracks are retained. Studio 0.7 adds non-destructive start/end trimming and 10-bit HLG HDR video export (Rec.2020 primaries/HLG transfer/Rec.2020 matrix). HLG/PQ input is recognized and color-managed. HDR bypasses the SDR input shoulder and preserves scene headroom outside the display-referred creative stages. Output is plain HLG: original Dolby Vision/HDR10+ dynamic metadata is not retained after regrading. HDR still-photo export, multi-clip timelines and other camera manufacturers' Log transforms remain future work.

[Apple: Export HDR media with AVFoundation](https://developer.apple.com/videos/play/wwdc2020/10010/) · [Apple: Using color spaces to display HDR content](https://developer.apple.com/documentation/metal/using-color-spaces-to-display-hdr-content)
