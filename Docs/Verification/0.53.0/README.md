# 0.53.0 (58) verification status

## Passed
- Simulator integration: ring-based Heal, suggested source, PNG preview/export, alpha preservation, original bytes unchanged, section workflow validation/persistence, bounded comparison cache and archive roundtrip.
- Photo development: real 3024×4032 DNG preview/export mean error 0.00168, Heal/Clone, replacement backgrounds, pool export. Simulator HEIF is explicitly excluded as physical HDR proof.
- Studio, video, queue, archive and 0.52 regression suites passed on this version.
- Simulator UI: saved workflow choose/delete/restore, comparison browsing/shared zoom; cleanup stroke Undo/Redo, source control, zoom, detail inspection; multiple-subject tap/clear validation; whole-pool sync Undo/Redo.

## iPhone 17 Pro native validation completed
- Multi-subject selection includes two distinct camera instances; single tap excludes the second. This is a public Smithsonian camera fixture, not a general accuracy benchmark.
- Face/Facial skin masks, 12-frame People matte regression, tracking/cancellation and saved-mask playback/export passed with a public NASA portrait/generated motion fixtures.
- Cleanup/export, alpha preservation, workflow persistence, comparison cache and backups passed.
- Real 3024×4032 DNG export/source preservation passed; photo development preview/export mean error 0.00179. Native generated HDR HEIF export passed.
- Heavy 32-Heal-dab grading: 1,800 requested/rendered frames, p95 39.67 ms, 95.72 seconds including 30 idle seconds; zero GPU failures, idle renders or inference calls. iOS thermal state stayed nominal (0). This does not guarantee every frame meets 30 fps or zero heat with all real media.

The simulator maximum workload was slower (p95 150.60 ms); a patch-region experiment was slower still and was removed. Native results use Metal stitchable kernels. No older physical iPhone was available. Results are bounded fixture checks, not proof of perfect object removal or all-device thermal behaviour.
