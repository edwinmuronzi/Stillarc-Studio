# Export metadata and privacy

The default policy omits identifying source metadata and retains video audio. Metadata preferences are stored in UserDefaults, separate from recipes, presets and project originals. Settings are captured before starting a worker export and cannot change a file midway through encoding.

Photo export renders the existing graded/framed source once to 8-bit sRGB, then uses ImageIO to encode JPEG at 0.96 or PNG losslessly. A metadata-only source read is skipped completely with all identifying fields off. Selected fields are explicitly whitelisted into fresh ImageIO properties; source orientation, pixel dimensions, EXIF thumbnails, maker notes, XMP, owner/serial/comment fields and arbitrary source dictionaries are not copied. Orientation is set to 1 because pixels are already oriented. GPS includes only coordinates and altitude, excluding source timestamps. No second decode, grading or recompression pass is introduced.

Video export reads QuickTime metadata only if a metadata option is selected, keeps at most one bounded UTF-8 string for each allowed creation-date, make, model or ISO 6709 location identifier, and assigns those tags to the existing writer. Disabling sound omits audio readers/writer inputs; frames still use their original timing. Timed metadata and arbitrary track/asset tags are not copied. Technical color/codec/container data and export-time file dates remain. Source metadata not available in the imported file or not in these supported namespaces cannot be restored.

Batch uses the exact same policy, serial export path and existing per-project grade/crop/trim. Filename disclosure is controlled separately. The policy affects the completed files supplied to Share and Photos, not preview images or originals. It does not guarantee what a receiving app subsequently adds or preserves.

Photo cancellation is checked before rendering, before encoding and after encoding. Failed/cancelled output is removed. Video and batch retain their existing cancellation and thermal-pacing paths. Changing options deletes the prior temporary output; closing the export sheet also cleans it up. There is no persistent cache of full-resolution exported files.

Primary API references: [ImageIO destinations](https://developer.apple.com/documentation/imageio/cgimagedestination), [adding image properties](https://developer.apple.com/documentation/imageio/cgimagedestinationaddimage(_:_:_:)), [AVMetadataIdentifier](https://developer.apple.com/documentation/avfoundation/avmetadataidentifier).
