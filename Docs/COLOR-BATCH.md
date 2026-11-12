# Log conversion and color LUTs — 0.27

## Source transforms

Sony S-Log3 with S-Gamut3.Cine and Panasonic V-Log with V-Gamut are manual input choices. Apple metadata detection remains unchanged. Studio does not guess a camera profile from image appearance or claim support for different Sony gamuts, S-Log2 or camera RAW through these choices. Inputs are interpreted as normalized decoded RGB code values; the decoder handles the file’s range/YCbCr tags first.

The CPU reference and GPU shader implement the published inverse transfer functions. D65 gamut matrices map scene-linear RGB into Studio’s extended linear sRGB working space. The Sony matrix is derived from published S-Gamut3.Cine primaries R(0.766,0.275), G(0.225,0.800), B(0.089,-0.087) and D65(0.3127,0.3290). Panasonic uses its published V-Gamut matrix to Rec.709 primaries. Source exposure and the existing optional luminance-preserving SDR shoulder follow conversion; HDR bypasses the SDR shoulder. One cached kernel handles the selected uniform profile, without per-slider compilation or a generated conversion cube.

Primary references: [Sony technical summary, transfer curve and primaries](https://www.sony.jp/ls-camera/knowledge/pdf/TechnicalSummary_for_S-Gamut3Cine_S-Gamut3_S-Log3_V1_00.pdf), [Panasonic V-Log/V-Gamut reference](https://pro-av.panasonic.net/en/cinema_camera_varicam_eva/support/pdf/VARICAM_V-Log_V-Gamut.pdf). These are analytic input transforms with Studio’s display rendering, not manufacturer look LUTs or camera certification.

## Color LUT export

Exports sample a 33³ or 65³ display-sRGB lattice through the compatible, pointwise creative grade, then write a standard red-fastest .cube. Input and output use display sRGB, domain 0–1; output is clipped to that SDR domain. The result approximates a color function, not every part of a finished image. Precision between samples depends on the receiving app’s interpolation and the complexity of the grade.

Excluded: source conversion, Highlights/Shadows, dehaze, texture/clarity, sharpening/noise reduction, grain, bloom, vignette, masks, framing, trim/audio and HDR output. Highlights/Shadows is conservatively excluded rather than assuming its implementation is independent of image content. The sheet always explains exclusions and lists active excluded edit groups. JSON presets retain reusable edit instructions; saved versions retain source-specific masks, framing and clip settings. The user’s recipe is never modified by LUT generation.

Creation is on demand on a utility worker. Lattice arrays and output strings reserve bounded capacity; there is one lattice render, no source-image decode, and no idle processing loop. File formatting checks cancellation periodically, writes atomically and removes incomplete owned folders. The share folder is cleaned when the sheet closes. Imported LUTs retain the existing immutable data/fingerprint behavior; editing strength does not rebuild the table.

Preset search is local. Rename and duplicate use the existing atomic saved-look path; rename retains the ID/recipe, and duplicate creates a new ID. Library writes are guarded against overlapping mutations.

## Validation limits

Reference vectors include published black/middle-gray values, inverse round trips, gamut multiplication, negative/bright signal values, alpha/exposure and SDR shoulder behavior. LUT checks include identity/order/gamma at 33/65, file round trip, direct-grade comparison, source immutability and excluded effects. Synthetic encoded video checks cover new-profile preview/export color, audio, duration and geometry. These are mathematical and generated-fixture checks; real camera-file, range-tag and scene coverage remains necessary before describing support as camera-certified.
