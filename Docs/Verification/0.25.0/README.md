# Studio 0.25.0 (26) verification

12 November 2026. Simulator processing checks passed for complete Home revert, preservation of the pre-revert edit as a saved version, no-op repeated revert, and detected video Log/HDR source defaults. Existing batch paste, recovery, source preservation, grading, masks and output checks also passed.

Revert reads the current persisted project inside the vault actor. It writes the before-version first, then atomically saves the reset index, removing the unused version file on save failure. Existing 20-version histories are retained and a full history blocks revert with an explanation. Source bytes and Photos/Files originals are never rewritten.

Release archive and strict signature verification passed. Installed and launched on iPhone 17 Pro. Rendering and export pipelines are unchanged; no new sustained thermal claim is made.

Focused UI test passed: paste a copied light edit from Home, choose Revert to original from the project options, confirm, reopen the editor and verify Light is neutral. The fixture uses generated simulator media only.
