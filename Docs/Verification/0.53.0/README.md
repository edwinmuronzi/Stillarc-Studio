# 0.53.0 (58) verification status

## Passed
- Simulator integration: ring-based Heal, suggested source, PNG preview/export, alpha preservation, original bytes unchanged, section workflow validation/persistence, bounded comparison cache and archive roundtrip.
- Photo development: real 3024×4032 DNG preview/export mean error 0.00168, Heal/Clone, replacement backgrounds, pool export. Simulator HEIF is explicitly excluded as physical HDR proof.
- Studio, video, queue, archive and 0.52 regression suites passed on this version.
- Simulator UI: saved workflow choose/delete/restore, comparison browsing/shared zoom; cleanup stroke Undo/Redo, source control, zoom, detail inspection; multiple-subject tap/clear validation; whole-pool sync Undo/Redo.

## Pending physical-device verification
The iPhone 17 Pro is unavailable to CoreDevice (4016). Installation and native multi-object/Face/Skin tests have not completed. Do not treat the candidate as a device-validated release.

A maximum 32-Heal-dab + heavy grading simulator run completed 1,800 requested updates, 713 renders in 73.85 seconds, p95 150.60 ms, zero GPU failures, zero idle renders and no inference. This is a correctness/idle check, not a smoothness pass or phone temperature evidence. A patch-region experiment was slower (p95 558.79 ms) and was removed. Physical profiling remains necessary before declaring the maximum workload responsive.

No older physical iPhone was available. Simulator thermal values do not verify physical thermal behaviour. Internal generated/owned fixtures are not proof of general subject-detection accuracy or complex real-world object removal.
