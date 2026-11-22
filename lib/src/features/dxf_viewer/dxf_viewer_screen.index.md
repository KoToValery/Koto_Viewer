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
| Widget & loading | `DxfViewerScreen`, `_DxfViewerScreenState`, `_loadDxfFile`, `_importDxfFile`, `_loadStructuralProject`, `_saveToRecentFiles` | Original DWG paths dispatch through `DxfParser.parseFromFile` to the direct native reader; DXF imports and linked project state retain their existing paths |
| Viewport & layouts | `_fitToScreen`, `_switchLayout`, `_onTransformChanged`, `_syncCanvasAfterTransform`, `_updateHudCadCoord`, `_buildLayoutTabsWidget`, `_buildProjectSwitchBar` | Camera transforms, Model/Paper layout switching, HUD bars |
| Pointer & keyboard input | `_handleGeneralPointerDown`, `_handleGeneralPointerMove`, `_handleGeneralPointerUp`, `_handleGeneralPointerCancel`, `_handlePointerSignal`, `_handlePointerHover`, `_handleCanvasTap`, `_handleCanvasContextTap`, `_handleKeyEvent` | Pan/zoom/wheel/keyboard input and entity context actions |
| Measurement & annotations | `_handleMeasurePointerDown`, `_handleMeasurePointerMove`, `_handleMeasurePointerUp`, `_handleMeasurePointerCancel`, `_updateMeasurePointer`, `_applyMeasurementPoint`, `_handleUndoAreaPoint`, `_handleCloseAreaPolygon`, `_openAnnotationDialog`, `_saveAnnotationsToPrefs`, `_loadSavedAnnotations` | Interactive distance/area measurement, snapping, and saved annotations |
| Sheets & export | `_showLayersSheet`, `_showInfoSheet`, `_showCoordinateSettings`, `_saveAsAnnotatedDxf`, `_exportKcad`, `_shareDxf`, `_printDxf` | Layer management, DXF/KCAD export, sharing, and printing |

`[TAG:DWG_DIRECT_IMPORT]` reuses the existing import action, model merge and
selection workflow with native DWG objects. DXF conversion remains only for
explicit DXF export/share operations in `_filesForDxfExport`
(`[TAG:DWG_EXPORT_BOUNDARY]`), outside opening or importing DWGs.

The navigation canvas opts in to `DxfPainter.interactiveHatches` for bounded
pattern work in the Model and Paper views. The viewport transform and input
routing still use the same `InteractiveViewer` and pointer handlers.

`[TAG:VIEWPORT_PICTURE_CACHE]` reuses the full-Model raster during expensive
camera motion, up to the magnification limit. `_updateMotionPreview` samples
the visible region through `DxfQuadTree.reachesWorkBudget`, weighing blocks
and patterned hatches more than simple entities. `_syncCanvasAfterTransform`
restores the retained vector layer after input settles.

`[TAG:VIEWPORT_PICTURE_CACHE]` owns the retained vector drawings and advances the
layer revision after visibility and lineweight mutations. Selection and snap
markers paint above the retained drawing in an independent repaint boundary.
Broad Model-space gestures can display a single scene texture prepared while
idle. The settled canvas uses the vector recording at the current zoom band.
