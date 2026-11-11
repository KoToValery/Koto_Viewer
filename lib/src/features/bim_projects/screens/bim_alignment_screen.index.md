# BIM Alignment Screen — Reference & Navigation Map
> **Path**: `lib/src/features/bim_projects/screens/bim_alignment_screen.dart`
> **Primary class**: `_BimAlignmentScreenState`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete method/class names with `rg -n`.

## 1. How to use this map

1. Use this map to identify the alignment method or painter you need.
2. Search the current Dart source, for example: `rg -n "_onSetControlPoint|_onConfirmAlignment|_ControlPointOverlayPainter" lib/src/features/bim_projects/screens/bim_alignment_screen.dart`.
3. Inspect the method body and its callers before modifying underlay loading, point calibration, or storey switching.

## 2. Key classes & alignment operations

| Area | Concrete symbols | Responsibility |
| --- | --- | --- |
| Screen widget & state | `BimAlignmentScreen`, `_BimAlignmentScreenState` | Multi-storey underlay alignment screen |
| Underlay loading & sheets | `_loadAllUnderlays`, `_pickAndAttachUnderlayForCurrentStorey`, `_showLayersSheet`, `_showDisplaySettingsSheet`, `_initDisplaySettings`, `_onDisplaySettingsChanged` | Loading storey DXF underlays, layer visibility, display settings |
| Viewport & tabs | `_onTransformChanged`, `_syncCanvasAfterTransform`, `_onTabChanged`, `_manageElevation` | Interactive transform sync, storey tabs, elevation management |
| Control points & alignment | `_onSetControlPoint`, `_clearControlPoint`, `_onConfirmAlignment`, `_showSlabPreviewReport`, `_reprocess` | Reference point placement, alignment commit, slab preview reprocessing |
| Overlay painter | `_ControlPointOverlayPainter` | CustomPainter for control point crosshairs and overlay markers |
