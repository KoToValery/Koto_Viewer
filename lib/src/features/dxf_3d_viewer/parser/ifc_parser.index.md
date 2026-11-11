# IFC 3D Parser — Reference & Navigation Map
> **Path**: `lib/src/features/dxf_3d_viewer/parser/ifc_parser.dart`
> **Primary classes**: `IfcParser`, `_IfcGeometrySolver`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete class or method names with `rg -n`.

## 1. How to use this map

1. Use this map to identify the parsing, CSG clipping, or B-Rep tessellation helper you need.
2. Search the current Dart source, for example: `rg -n "_clipMeshByCuttingSolid|_resolveProfilePoints|_cleanWallJunctions" lib/src/features/dxf_3d_viewer/parser/ifc_parser.dart`.
3. Inspect the target method and its callers inside `_IfcGeometrySolver` before modifying placement transforms or boolean void subtraction.

## 2. Key classes & geometry pipeline

| Area | Concrete symbols | Responsibility |
| --- | --- | --- |
| Public API & utilities | `IfcParser`, `parseFromFile`, `parseFromText`, `decodeIfcString`, `triangulatePolygon3D`, `bridgePolygonWithHoles` | Entrypoints, isolate parsing, polygon triangulation |
| STEP/IFC primitives | `_RawIfcEntity`, `_IfcParamTokenizer`, `_Transform3D`, `_Plane3D`, `_Obb`, `_OpeningVoidData`, `_OpeningFillInterface` | Tokenization, 3D transforms, bounding boxes, void records |
| Solver & post-processing | `_IfcGeometrySolver`, `_categorizeIfcType`, `_getArchitecturalColor`, `_pruneDuplicateGhostWalls`, `_cleanWallJunctions`, `_cleanOpeningFillInterfaces`, `_bridgeConnectedWallCorners`, `_preTessellateLargeSurfaces` | Element categorization, corner welding, ghost/interface cleanup |
| Profiles, curves & B-Rep | `_resolveCurvePoints`, `_resolveProfilePoints`, `_resolveShapeRepresentation`, `_resolveGeometryItem`, `_generateExtrudedSolid`, `_generateFacetedBrep`, `_generateTriangulatedFaceSet`, `_generatePolygonalFaceSet`, `_triangulatePolygon3D` | Profile/curve extraction and 3D mesh generation |
| Void clipping & CSG | `_applyOpeningVoids`, `_clipMeshByCuttingSolid`, `_clipTrianglesByBoundedHalfSpace`, `_clipTrianglesByPlane`, `_sliceByPlane`, `_filterDegenerateTriangles` | Opening void subtraction and half-space clipping |
