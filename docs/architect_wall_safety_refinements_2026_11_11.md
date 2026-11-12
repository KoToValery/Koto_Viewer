# Wall, Mirror and Hatch refinements

- Dynamic wall clearances and numeric adjustment share core-face geometry.
- Existing walls keep their physical placement when changing the leading line,
  including arcs and hosted openings. Keep position defaults on and can be disabled.
- Attach validates finite physical contacts and changes only connection flags.
  It never searches for a common remote vertex. CAD vertex joining is separate.
- Detach has one confirmation and one history step. `autoAttachAfterMove` is
  persisted (missing means false); the next actual translation/endpoint move
  restores automatic connection at real contact without carrying the old neighbours.
  A free wall continues waiting until a later movement brings it into contact.
  Cut ends remain independently detached. Cancellation and zero movement do not
  release a temporary Detach.
- One Mirror command covers existing supported element types. Axis placement
  opens review with Keep original off. Toggle previews share the original model
  and stable copy IDs. Applying publishes one history step.
- Chamfer/Fillet use the standard distance keypad and project units/precision.
  Connector exterior sides follow both input tangents; conflicting manual sides
  and values that cannot fit are refused.
- Hatch editing starts in Pull, retaining useful old corners. Dedicated SVGs
  distinguish Pull, Move and Extend adjacent sides. Other contour defaults remain.

All new UI labels and tooltips use BG/EN ARB messages. Navigation maps describe
the affected command ownership and mutation paths.

Validation is recorded in `scratch/wall_safety_baseline_verified.log` and the
final verification log. The baseline uses source and tests from HEAD; the icon
asset-count check additionally sees the three newly created SVGs absent from
that baseline catalogue and is therefore excluded from baseline comparison.

Final targeted verification: 176 passing geometry, interaction, localization and
arc-dimension tests (`scratch/wall_safety_complete_tests.log`). The targeted Dart
analysis completed with no errors or warnings; 39 non-fatal information messages
cover brace style and existing deprecated form-field APIs. The installed Dart
CLI leaves infos non-fatal by default and does not accept `--no-fatal-infos`.

Visual/SVG verification: 14 further passing checks, including Bulgarian/English
phone layouts in light/dark themes, Mirror review, catalogue localization and
SVG painting at command sizes. Review captures are in
`scratch/command_mirror_aim_bg.png`, `scratch/command_mirror_review_bg.png` and
`.dart_tool/hatch-edit-light.png`.

An additional passing regression checks the prepared Chamfer/Fillet exterior
normal at both connector ends in a resolved closed contour, with swapped input
order and reversed stored directions. There are 191 distinct passing targeted
checks across the geometry/interaction and visual/SVG runs. The final Move SVG
also passed decode/paint and phone-layout rechecks after visual refinement.
