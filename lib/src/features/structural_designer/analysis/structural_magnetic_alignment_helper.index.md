# Structural Magnetic Alignment Helper — Reference & Navigation Map
> **Path**: `lib/src/features/structural_designer/analysis/structural_magnetic_alignment_helper.dart`
> **Primary class**: `StructuralMagneticAlignmentHelper`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete class or method names with `rg -n`.

## 1. How to use this map

1. Use this map to identify the element alignment routine or result type you need.
2. Search the current Dart source, for example: `rg -n "alignColumn|alignShearWall|alignBeamEndpoint" lib/src/features/structural_designer/analysis/structural_magnetic_alignment_helper.dart`.
3. Inspect both the helper and its callers in `structural_designer_screen.dart` before changing snap tolerances or guideline behavior.

## 2. Key alignment routines & result types

| Target | Concrete symbols | Responsibility |
| --- | --- | --- |
| Helper & results | `StructuralMagneticAlignmentHelper`, `ColumnMagneticAlignmentResult` | Magnetic alignment helpers and guideline outputs |
| Column snapping | `alignColumn` | Snapping columns to grid axes, neighboring columns, and slab edges |
| Shear wall snapping | `alignShearWall` | Collinear merge, L/T corner joints, and axis offsets |
| Beam snapping | `alignBeamEndpoint` | Beam endpoint snapping to columns, wall nodes, and ortho locks |
