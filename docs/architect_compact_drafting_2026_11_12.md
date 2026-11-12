# Compact drafting and corner commands

Walls, CAD lines/arcs/polylines and manual Hatch segments use the same pending
segment panel, regardless of object snaps, angular guides or free placement.
The distance is always visible and editable. The initially collapsed panel
opens the local numeric keypad on tap; exact-value dialogs may open it directly.
Continue, End and Cancel keep their original mutation, Undo and save ownership.
Arc drawing retains the chord -> shaping -> rise -> commit sequence.

The common panel has a 44 px action row, short localized captions on phone
widths, low elevation, a compact value field and an immediate keypad drawer.
Narrow host widgets use a two-row fallback. Cancel has one owner while the
checkpoint is shown; the floating first-point cancel remains before it.

Chamfer and Fillet use dedicated bevel/round SVGs. Curve retains a distinct icon.
Duplicate wall/segment menu entries are removed; other contours retain the
localized Corners group and canonical command IDs. Landscape controls use the
same icons. All new UI words are in BG/EN ARB.

Validation covers 320/360 px phone layouts in BG/EN, light/dark themes, numeric
validation, physical keyboard input, exact entry after each snap class,
Continue/End/Undo, duplicate menu entries and SVG rendering. Snapshot captures
are in `.dart_tool/compact-drafting-*.png`.
The broader CAD/polygon baseline is recorded in
`scratch/compact_drafting_baseline.log`; final results are in
`scratch/compact_drafting_final.log`.

Final verification: 109 tests passed, with four existing CAD/polygon failures
also reproduced against the unchanged baseline (endpoint editing, held line
placement, and selected contour-handle pulling for Hatch and slabs). All 21
new compact-panel/menu cases and the command-icon checks pass. Targeted Dart
analysis reports no issues; the installed Dart CLI uses nonfatal infos by
default and does not support the `--no-fatal-infos` option.
