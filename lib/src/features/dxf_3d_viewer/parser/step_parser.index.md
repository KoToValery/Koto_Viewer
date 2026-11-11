# STEP 3D Parser — Reference & Navigation Map
> **Path**: `lib/src/features/dxf_3d_viewer/parser/step_parser.dart`
> **Primary class**: `StepParser`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete class or method names with `rg -n`.

## 1. How to use this map

1. Use this map to identify the STEP entity struct or tessellation routine you need.
2. Search the current Dart source, for example: `rg -n "_evaluateStepNurbsSurface|_parseBSplineCurve|StepParser" lib/src/features/dxf_3d_viewer/parser/step_parser.dart`.
3. Inspect the target method and callers before modifying STEP curve/surface parsing or mesh generation.

## 2. Key classes & parsing operations

| Area | Concrete symbols | Responsibility |
| --- | --- | --- |
| Internal geometry types | `_UVPoint`, `_StepSubEntity`, `_StepEntity`, `_StepAxisPlacement`, `_StepBSplineCurve`, `_StepMatrix4` | UV coordinates, STEP entity graph, axis placement, B-spline sampling, 4x4 matrices |
| Public API & decoder | `StepParser`, `parseFromFile`, `parseFromBytes`, `_parseStepFileCompute`, `_decodeText`, `_parseStepText` | Isolate file/byte parsing and text decoding |
| Curve & surface helpers | `_parseBSplineCurve`, `_evaluateStepNurbsSurface`, `_parseSubEntities`, `_parseComplexContent`, `_parse2DIdList`, `_parseNumberLists`, `_expandKnots` | B-spline/NURBS surface evaluation and STEP parameter parsing |
