# Stillarc Studio 0.21.0 (22) verification

Tested 12 November 2026 on iPhone 17 Pro and the iPhone 18 Pro simulator. Release archive built and passed strict code-signature verification; installed and launched normally on the 17 Pro.

## Device processing and preview

- `iPhone17Pro-processing.json`: all processing groups passed, including original import filenames, mixed photo/video batch export, full remaining crop dimensions, per-project grading, partial failure, safe unique output names, cancellation, metadata recovery/throttling, saved-look recovery, interrupted delete/restore reconciliation, restoration of media/versions/ratings, trash expiry and unchanged original bytes. QA uses generated media and an isolated temporary vault; it does not delete user Photos.
- The shared processing regression ran 120 stress renders in 5.40 seconds. iOS thermal status was nominal at report time.
- `iPhone17Pro-preview.json`: 180 requested edits, 164 completed newest-state preview renders, 15.37 ms p95 GPU/render duration, zero GPU failures and zero extra idle frames. The short 7.28-second run stayed nominal → nominal. Render duration is not end-to-end touch latency; this is not a sustained battery/thermal guarantee.

## Interaction coverage

All 12 UI cases passed across the full regression and corrected curves rerun: the full run passed 11/12; its curves test scrolled through the editable graph while positioning the test gesture, creating an extra edit before Undo. After correcting that harness gesture to use the scroll gutter, the curves case passed without a production-code change. Summaries are retained beside this file.

The simulator UI checks cover curves scrolling without changing values, explicit point editing and undo, Home keyboard dismissal and continued typing, multi-item import → select → export, delete/restore, and the existing crop, sliders, Levels, organization, automatic selection and tracking workflows. The curves harness uses the right gutter when point editing is enabled; scrolling inside an unlocked graph intentionally edits it.

## Practical limits

Batch import/export is serial and capped at 20 items. Output resolution is independent of preview resolution. Export waits at serious thermal pressure and can be cancelled. Recently Deleted expires after 30 days when checked on opening, not by a timer. Settings recovery can omit recent changes since its last throttled backup (up to 30 seconds of saved edits); media is not duplicated. Limited/denied Photos permissions, low disk space, unsupported files and larger real-world camera libraries still need broader device coverage before public distribution.
