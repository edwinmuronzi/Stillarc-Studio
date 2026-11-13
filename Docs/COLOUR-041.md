# Colour tools — Studio 0.41

## How to use them

**Input → Recorded profile** restores contrast and colour to flat Log footage before creative grading. Match both the gamma and gamut used by the camera. New manual choices:

- Canon Log 3 / Rec.2020 (not Cinema Gamut).
- Nikon N-Log / Rec.2020.
- Fujifilm F-Log2 / F-Gamut (not F-Log2 C).
- DJI D-Log / D-Gamut, X9 native EI (not D-Log M or D-Log 2).

Apple Log, Apple Log 2, Sony S-Log3 / S-Gamut3.Cine and Panasonic V-Log / V-Gamut remain available. Already-converted or ordinary HDR footage should stay on Standard. RAW photos use their separate RAW development path. Source exposure precedes the optional SDR highlight roll-off; HDR retains headroom. These are analytic transforms followed by Studio rendering, not manufacturers’ display LUTs or certification across every camera model.

**Film → LUT stack** combines up to three creative display-sRGB `.cube` LUTs. The existing LUT runs first, then the two additional layers in shown order. All layers have strength and On/off controls. Added layers also have Move up and Remove controls. Moving the first extra layer up exchanges it with the original LUT. Bypass preserves each layer’s saved strength, including after reordering. Turn off all LUTs clears the complete stack; Undo restores it. Use Input for technical Log conversion rather than stacking a Log-to-display LUT on an already converted image.

**Curves** supports up to twelve points per Master, Red, Green and Blue curve. Add point inserts into the largest input gap. Choose a point from the menu, adjust Input/Output or enable Edit curve points and drag in either direction. Endpoints stay at the left/right limits; internal points cannot cross. Swipe normally when editing is off; the right gutter always remains available for scrolling. Delete point removes an internal point. Reset restores that channel. Double-tap a slider to reset it (output returns to its input; input returns to the middle of its available gap).

Stacks and flexible curves participate in undo/redo, saved projects, complete versions, presets, copied/synced grades, backups, queue exports and exported colour LUTs. Animated LUT fades multiply every layer’s existing strength. Presets using these features require schema 6; new project/library backups require reader build 45, preventing older apps silently discarding the new edits. Existing backups remain readable.

## Efficiency

Log conversion remains one cached analytic GPU kernel. Curves use a cached 1024-sample RGB table, including nonuniform shape-preserving interpolation; no 3D cube is rebuilt while moving points. LUT cubes remain immutable/shared between history states. Disabled/zero-strength layers bypass rendering. Three LUTs maximum bounds GPU and memory cost; full-resolution exports use the same ordered operations. No background segmentation runs merely because colour sliders change.

## Primary technical references

- [Canon Log white paper](https://downloads.canon.com/nw/pdfs/camcorders/whitepapers/canon-log-gamma-curves-white-paper.pdf), full-range Log 3 equation, reflection normalized with the 90% reference; [Canon recording colour spaces](https://cam.start.canon/en/C010/manual/html/UG-03_Shooting-2_0090.html).
- [Nikon N-Log specification](https://download.nikonimglib.com/archive4/zMDhS00ZuoyY0502OFd16BeF1X67/N-Log_Specification_(En)01.pdf), 10-bit transfer and Rec.2020 primaries.
- [Fujifilm F-Log2 data sheet 1.1](https://dl.fujifilm-x.com/technical-data/F-Log2_DataSheet_E_Ver.1.1.pdf), reflection transfer and F-Gamut primaries (same primaries as Rec.2020).
- [DJI X9 D-Log / D-Gamut white paper](https://dl.djicdn.com/downloads/DJI_Ronin_4D/X9_D_Log_D_Gamut_Whitepaper.pdf), native-EI reflection transfer and D-Gamut-to-Rec.709 matrix. The inverse uses the exact forward coefficients to avoid rounding drift in the printed inverse.

Validation uses published black/gray/white references, CPU/GPU vectors and synthetic encoded video. Camera-original samples for these four new profiles have not been supplied; their full range of camera/codec metadata combinations has not been certified.
