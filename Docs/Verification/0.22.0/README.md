# Studio 0.22.0 (23) verification

12 November 2026. Focused simulator checks passed for double-tap favourite without opening the editor, hold preview/actions, selection, deleting two owned test projects, opening Recently Deleted, and delete-all confirmation without executing it. The unchanged batch import/export/delete/restore test also passed. The initial new test expected a Cancel button; iOS presents a popover dismissed by tapping outside instead. The corrected gesture test passed without production changes.

Release archive and strict signature verification passed. Installed and launched the release on iPhone 17 Pro. No user projects or Photos were deleted during device checks. Rendering/export math and the recovery implementation are unchanged from the 0.21 device processing checks; this release changes library interactions and labels. No new sustained thermal claim is made.
