# Structural Element Models — Reference & Navigation Map
> **Path**: `lib/src/features/structural_designer/models/structural_element.dart`
> **Primary classes**: `StructuralProject`, `StoreyLevel`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete class or enum names with `rg -n`.

## 1. How to use this map

1. Use this map to identify the structural data model or enum you need.
2. Search the current Dart source, for example: `rg -n "class StructuralShearWall|class StructuralSlab|class StructuralProject" lib/src/features/structural_designer/models/structural_element.dart`.
3. Inspect the model fields, `copyWith`, and JSON serialization directly in source before modifying element properties.

## 2. Model & enum directory

| Category | Concrete classes / enums | Responsibility |
| --- | --- | --- |
| Columns | `ColumnShape`, `GhostStoreyMode`, `StructuralColumn` | Column shapes (rect, circular, L-shape) and ghost display modes |
| Shear walls | `ShearWallReferenceLine`, `StructuralShearWall` | Wall endpoints, thickness, reference line, and 2D profile |
| Beams | `StructuralBeam` | Beam start/end nodes, width, depth, and drop profile |
| Slab openings | `SlabOpeningType`, `SlabOpening` | Shaft, void, and stair opening contours |
| Slabs & grips | `StructuralSlab`, `SlabZoneKind`, `SlabEdgeGripInfo` | Slab polygon contours, edge grips, and cantilever checks |
| Storeys & project | `StoreyLevel`, `FoundationType`, `StructuralProject` | Elevation levels, foundations, project state, and JSON serialization |
