# Automatic selection models

Subject selection uses Apple's iOS 17+ `VNGenerateForegroundInstanceMaskRequest` and its combined foreground-instance mask. It is performed once on the bounded, framed input. Sky uses a bundled Core ML model; no remote service receives images.

## SkySegSmall

- Task: soft sky segmentation, not subject segmentation or sky replacement.
- Original author/model: [xiongzhu666/Sky-Segmentation-and-Post-processing](https://github.com/xiongzhu666/Sky-Segmentation-and-Post-processing).
- Core ML conversion: [twistlabs/fotometis-sky](https://huggingface.co/twistlabs/fotometis-sky).
- Pinned revision: `97dfe50bf3fe4dc02badea287512afaf4ce857c2`.
- Bundled payload: 2,525,584 bytes; U²-Net-small, fixed 384×384 RGB input and 384×384 single-channel image output. ImageNet preprocessing is embedded in the graph; callers supply normal RGB pixels, without a second normalization.
- License: MIT. Original copyright/permission text and attribution are bundled in `StillarcStudio/ModelNotices.txt`, accessible under About → Sky model acknowledgements.
- The conversion provider describes failure cases including building detail and heavily textured clouds. The app treats predictions as editable estimates and preserves soft probabilities rather than stretching each frame to force a nonempty mask.
- Runtime: lazy request-only loading; CPU/Neural Engine on device, CPU on simulator. Models are released after selection. Saved coverage/refinements, not inference, drive ordinary preview and export.

## Reproduction and integrity

The model was downloaded from the pinned revision above without executing external Python code or deserializing a Python pickle. Core ML compiles the package through Xcode. Original payload SHA-256 values:

```json
{
  "Data/com.apple.CoreML/model.mlmodel": "f12a39fe104d0a5d2285820d322d9697de5a5011ee355132cbc01822e9d1a06f",
  "Data/com.apple.CoreML/weights/weight.bin": "5df3feebcc15a77480fabb9896b96036e5acc38dc043af414f09dc5b1d296efb",
  "Manifest.json": "2ef47fc3ea776f1f11b8870284fe15974e6d8be96515d071851df0d407791677"
}
```

Testing covers the bundled illustrative sample and synthetic matte fixtures; it is not a broad segmentation accuracy benchmark. More representative photos, fine hair, transparent materials, reflection-heavy buildings, difficult skies and changing-pose video remain validation work.

Apple reference: [foreground-instance mask requests](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest).
