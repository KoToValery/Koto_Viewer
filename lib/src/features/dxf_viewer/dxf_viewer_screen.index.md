# DXF Viewer Screen — Reference & Navigation Map
> **Path**: `lib/src/features/dxf_viewer/dxf_viewer_screen.dart`
> **Primary class**: `_DxfViewerScreenState`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete method/class names with `rg -n`.

## 1. How to use this map

1. Use this map to find the viewer handler or pointer mode you need.
2. Search the current Dart source, for example: `rg -n "_handleMeasurePointerDown|_loadDxfFile|_switchLayout" lib/src/features/dxf_viewer/dxf_viewer_screen.dart`.
3. Inspect pointer arbitration between general pan/zoom and measurement mode before changing gestures or overlays.

## 2. Key operations & handlers

| Area | Concrete symbols | Responsibility |
| --- | --- | --- |
| Widget & loading | `DxfViewerScreen`, `_DxfViewerScreenState`, `_loadDxfFile`, `_importDxfFile`, `_loadStructuralProject`, `_saveToRecentFiles` | Async DXF/DWG loading and linked project state |
| Viewport & layouts | `_fitToScreen`, `_switchLayout`, `_onTransformChanged`, `_syncCanvasAfterTransform`, `_updateHudCadCoord`, `_buildLayoutTabsWidget`, `_buildProjectSwitchBar` | Camera transforms, Model/Paper layout switching, HUD bars |
| Pointer & keyboard input | `_handleGeneralPointerDown`, `_handleGeneralPointerMove`, `_handleGeneralPointerUp`, `_handleGeneralPointerCancel`, `_handlePointerSignal`, `_handlePointerHover`, `_handleCanvasTap`, `_handleCanvasContextTap`, `_handleKeyEvent` | Pan/zoom/wheel/keyboard input and entity context actions |
| Measurement & annotations | `_handleMeasurePointerDown`, `_handleMeasurePointerMove`, `_handleMeasurePointerUp`, `_handleMeasurePointerCancel`, `_updateMeasurePointer`, `_applyMeasurementPoint`, `_handleUndoAreaPoint`, `_handleCloseAreaPolygon`, `_openAnnotationDialog`, `_saveAnnotationsToPrefs`, `_loadSavedAnnotations` | Interactive distance/area measurement, snapping, and saved annotations |
| Sheets & export | `_showLayersSheet`, `_showInfoSheet`, `_showCoordinateSettings`, `_saveAsAnnotatedDxf`, `_exportKcad`, `_shareDxf`, `_printDxf` | Layer management, DXF/KCAD export, sharing, and printing |
