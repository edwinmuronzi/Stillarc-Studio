# Studio 0.24.0 (25) verification

12 November 2026. Selection mode now recognizes one tap as its first gesture, removing the deliberate double-tap disambiguation wait. Outside selection mode the existing double-tap favourite gesture remains. This is a gesture change, not a measured end-to-end latency claim.

Home copy reads saved recipe metadata and uses the existing persisted section-based clipboard. Single-project Home paste uses the same guarded version-checkpoint batch path tested in 0.23. Copy/Apply are pinned below the adjustment list to remain accessible with all ten groups. Project ellipsis menus remain usable in selection mode and share the selected-project actions. Bulk rating/unfavourite use the existing organization saves without regrading thumbnails.

The focused tests use two owned generated simulator projects; device launch checks do not delete user projects or Photos. Image rendering, source decoding and output quality are unchanged. No new sustained thermal claim is made.

Final UI workflow checks passed for copying through both Home hold/options menus, single-project paste, consecutive select/deselect taps, selecting two projects, group rating, selection-aware ellipsis export, selected hold actions, batch paste, bulk deletion and bin countdown/previews. The prior favourite/delete-all-confirmation case also passed in the broader run. Initial copy/paste checks exposed offscreen action buttons with long group lists; the production fix pinned both actions before the successful final rerun.

Release archive and strict signature verification passed. The final build was installed and launched normally on iPhone 17 Pro.
