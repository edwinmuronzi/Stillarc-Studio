# Brush masks verification — 0.12.0 (13)

Tested on the black iPhone 16 Pro and iOS Simulator. Native photo, encoded-video, brush interaction, and simulator suites passed. Tests cover paint/erase coverage, soft edges, orientation, incremental/full-raster agreement, persistence, whole-stroke undo/redo, versions, original preservation and full-size 16-bit export masks. The 48MP brush check verifies mask allocation/dimensions, not a complete 48MP RAW export.

The sustained synthetic 1080p HDR playback test ran 128.7 seconds with 7,200 updates, four masks, a LUT, scopes and comparison: zero GPU errors; nominal iOS thermal state at both endpoints. GPU completion p95 was 14.4 ms. This run predates the final duplicate-request removal; its report is labeled accordingly. The final shorter playback check passed with 178 raster jobs for 180 updates, zero GPU errors and nominal thermal endpoints.

The final rendered-view brush check passed 180 updates with zero raster jobs during its idle interval, no new players, and a maximum main-actor interval of 90.8 ms (including the requested sleep). It drives editing methods while rendering the actual view; it is not automated finger/pressure testing. Actual Paint/Eraser mode pauses video and hides transport overlays; View restores playback controls.

These are generated fixtures and diagnostic measurements, not a guarantee of zero heat, battery use, or presentation frame rate on all source media/devices. GPU completion time is not end-to-end touch latency. No Pencil pressure, motion tracking or mask keyframes are implemented.
