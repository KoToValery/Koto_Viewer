# Wall operation axes

Fillet, Chamfer and Offset now calculate wall geometry on the core axis. The
saved `referenceLine` remains the placement reference; no project migration or
additional user setting is needed. Finished-face clearances keep their existing
meaning.

`ArchitectWallOperationAxis` converts straight and circular walls to core-axis
proxies and restores results to each wall's own reference. Arc conversion uses
parallel concentric arcs, preserving sweep and physical radius relationships.

## Corner edits

Both the second-wall pick and two-wall selection paths share
`ArchitectChamferFillet`. Setbacks and radii are exact core-axis values. Existing
straight walls keep their transverse position, far endpoints, reference choice
and properties. Hosted openings retain their physical stations. A cut through
an opening or a radius/setback that does not fit is refused atomically.

The connector inherits the first wall's composition, system and instance
properties, clears hosted openings, uses the core reference and follows the
physical material side even if the source direction is reversed. Different
thicknesses keep their actual cross-sections; the existing boolean wall network
owns their face/layer junctions. This does not introduce a tapered wall type.
Existing curved input walls remain outside the two-straight-wall Fillet/Chamfer
operation; Offset supports straight and circular chains.

## Offset

Connected core-axis endpoints are normalized to the existing physical junction
before chain offsetting, including bounded line/arc intersections. Offset is
measured between the old and new core axes. Each result is converted back to
its source reference, so a drawing-line choice cannot change the offset.
Detached endpoints remain separate and branched/ambiguous paths are refused.
Openings follow the transverse offset while retaining their longitudinal
stations; copied hosts receive independent opening identities. CAD lines,
polygons, slabs and other native kinds retain their own geometry rules.

## UI and validation

The existing dialogs show short wall-specific ARB labels in Bulgarian and
English. Tooltips explain the core-axis convention. Command entry points,
viewport gesture routing, confirmation/cancellation, Undo and save ownership
follow the existing workspace paths.

Regression coverage:

- `test/features/architect/architect_wall_operation_axis_test.dart`: reference
  combinations, unequal thicknesses, asymmetric finishes, reversed/rotated
  walls, circular offsets, physical chain junctions, detached ends, hosted
  openings, serialization and Undo.
- `test/features/architect/architect_wall_core_operations_phone_test.dart`:
  Bulgarian/English 360×800 second-wall picks, cancellation, Undo and axis labels.
- Existing Chamfer/Fillet, Offset, attach/detach and endpoint-angle suites.

The wider pre-existing Offset/CAD failures were reproduced with the original
workspace screen, Offset service and Offset dialog. The final targeted run
contains 132 passing tests and the same five existing Offset failures; logs are
in `scratch/architect_core_verified_tests.log`, with the wider baseline in
`scratch/architect_core_offset_baseline.log`.
