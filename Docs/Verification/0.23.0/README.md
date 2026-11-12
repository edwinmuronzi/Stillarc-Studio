# Studio 0.23.0 (24) verification

12 November 2026. Simulator processing checks passed, including batch paste section isolation, destination framing preservation, before-version restoration, unchanged-paste no-op, the 20-version guard, and countdown boundaries at 30/1/0 days. The existing processing, masks, crop, LUT, batch export and recovery groups also passed.

Release archive and strict code-signature verification passed. Installed and launched normally on iPhone 17 Pro. User Photos and projects were not deleted during device checks. The UI fixture uses two generated projects in the simulator only.

Bin previews use the shared bounded thumbnail cache and read from the owned trash media location; clips show poster frames. Batch paste changes saved recipe metadata serially, without media decoding or rendering. Cancellation finishes the current atomic save and stops before the next project. Each changed edit gets a Before batch paste version; existing version histories are never silently pruned.

Focused UI check passed: selected-thumbnail hold → Favourite selected; Export selected sheet; Paste adjustments → applied to two projects; Delete selected → two projects moved; 30-day labels; enlarged deleted-thumbnail preview opening and closing. An initial harness query matched both the paste toolbar button and menu item; targeting the menu item identifier fixed the test without production changes.
