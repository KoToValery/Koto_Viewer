# Structural Designer Screen — Reference & Navigation Map
> **Path**: `lib/src/features/structural_designer/structural_designer_screen.dart`
> **Primary class**: `_StructuralDesignerScreenState`
> **Important**: In this file, the header TOC `[TAG:STRUCT_*]` labels are topic summaries while the body uses `// === SECTION: ... ===` headers. Treat this map as a discovery aid and verify symbol names and behavior in the current source with `rg -n`.

## 1. How to use this map

1. Use this map to find the closest existing interaction archetype and concrete method names.
2. Search the current Dart source, for example: `rg -n "_commitPlacement|_handlePointerDown|_buildContextualElementBottomDock" lib/src/features/structural_designer/structural_designer_screen.dart`.
3. For behavior changes, read the relevant method bodies and immediate callers/callees across the screen, `Structural2dPainter`, models, and analysis helpers where they participate.
4. Select the closest behaviorally similar feature as a reference; do not copy a pattern mechanically when the requirement differs.

## 2. Source section registry

| Section header in source | Header topic tag | Responsibility |
| --- | --- | --- |
| `// === SECTION: [SEC-01-WIDGET]` | `[TAG:STRUCT_WIDGET]` | `StructuralDesignerScreen` widget declaration and public API |
| `// === SECTION: STATE VARIABLES & LIFECYCLE` | `[TAG:STRUCT_STATE]` | State fields, `_project`, `_activeTool`, selections, `_pushUndo`, `_undo` |
| `// === SECTION: COORDINATE TRANSFORMATIONS & VIEWPORT` | `[TAG:STRUCT_XFORM]` | Screen/CAD coordinate transforms and viewport helpers |
| `// === SECTION: HIT TESTING & SELECTION HELPERS` | `[TAG:STRUCT_HITS]` | Hit testing and selection helpers for columns, walls, beams, openings, slabs, axes |
| `// === SECTION: ELEMENT ACTIONS (COLUMNS, WALLS, BEAMS)` | `[TAG:STRUCT_ACTIONS]` | Element mutations, duplicate drag, move sessions, custom dialogs |
| `// === SECTION: OPENINGS & GRID AXES MANAGEMENT` | `[TAG:STRUCT_OPENINGS]` | Slab openings, offset drag modes, grid axis management |
| `// === SECTION: SLAB CORRECTION & POLYGON EDITING` | `[TAG:STRUCT_SLABS]` | Slab contour editing (`_startSlabCorrection`, `_saveSlabCorrection`) and opening taps |
| `// === SECTION: POINTER GESTURES & INTERACTION CONTROLLER` | `[TAG:STRUCT_POINTER]` | `_handlePointerDown`, `_handlePointerMove`, `_handlePointerUp`, `_handleTapUp`, `_handleLongPressStart` |
| `// === SECTION: ELEMENT PLACEMENT & COMMIT LOGIC` | `[TAG:STRUCT_COMMITS]` | `_commitPlacement`, stair/slab generation, `_saveProject` |
| `// === SECTION: UNDERLAY FILTERING & CAD SETTINGS` | `[TAG:STRUCT_UNDERLAY]` | Underlay filtering, layer sheets, wall/axis auto-detection triggers |
| `// === SECTION: STOREY MANAGEMENT & ANALYSIS DIALOGS` | `[TAG:STRUCT_STOREY]` | Storey switching, vertical/cantilever/seismic report triggers |
| `// === SECTION: APPBAR & HUD ACTION BUILDERS` | `[TAG:STRUCT_APPBAR]` | Top AppBar actions and tool switching (`_selectTool`) |
| `// === SECTION: MAIN BUILD METHOD & VIEWPORT CANVAS` | `[TAG:STRUCT_BUILD]` | Main `build()`, `BimEditingViewport`, `DxfPainter`, `Structural2dPainter` |
| `// === SECTION: CONTEXTUAL BOTTOM DOCKS & ACTION BARS` | `[TAG:STRUCT_DOCKS]` | `_buildContextualElementBottomDock`, `_buildSlabCorrectionBottomBar`, `_buildFloatingMoveBottomBar` |

## 3. Tool archetypes and reference flows

These are existing reference patterns, not mandatory templates. For a new feature, choose the closest match by interaction and user intent, then verify the implementation in source.

| Interaction archetype | Reference symbols to inspect | What to trace |
| --- | --- | --- |
| Viewport routing & gesture arbitration | `BimEditingViewport`, `_viewportDragging`, `_handlePointerDown`, `_moveViewportTool`, `_releaseViewportTool`, `_beginViewportHold`, `_cancelViewportTool` | Shared viewport ownership, pan lock via `isDraggingHandle`, hold-to-place, cancel cleanup |
| Element placement & polygon drafting | `_selectTool`, `_handleTapUp`, `_commitPlacement`, `_commitOpeningTap`, `_closeSlabPolygon`, `_closeOpeningPolygon` | Tool preset state, snap/alignment preview in `Structural2dPainter`, commit, `_pushUndo`, `_saveProject` |
| Selected-element contextual dock actions | `_buildContextualElementBottomDock`, `_deleteSelectedColumn`, `_rotateSelectedWall`, `_updateOpeningTypeInStorey`, `_deleteSelectedGridAxis` | Selection state (`_selectedColumn`, `_selectedShearWall`, `_selectedBeam`, `_selectedOpening`, `_selectedGridAxis`), dock actions, undo/save |
| Interactive move & duplicate drag sessions | `_startDuplicateDrag`, `_commitDuplicateDrag`, `_startMovingSelectedColumn`, `_startMovingSelectedWall`, `_startMovingOpening`, `_confirmCurrentMove`, `_cancelCurrentMove`, `_buildFloatingMoveBottomBar` | Session start, live move preview, viewport drag lock, confirm/cancel floating bar, undo/save |
| Multi-step slab contour correction | `_startSlabCorrection`, `_pushSlabCorrectionUndo`, `_undoSlabCorrection`, `_cancelSlabCorrection`, `_saveSlabCorrection`, `_buildSlabCorrectionBottomBar`, `_updateSlabVertexDrag`, `_updateEdgeExtrusion` | Isolated editing state (`_editingSlab`), vertex/edge extrusion drag, dedicated correction bar, save/cancel |
| Offset drag & numeric input | `_startAxisOffsetDragMode`, `_startColumnOffsetDragMode`, `_updateAxisOffsetDrag`, `_updateColumnOffsetDrag`, `_showGridAxisOffsetDialog`, `_showColumnOffsetDialog` | Interactive drag preview combined with exact distance dialog |

## 4. Cross-cutting state and owners

- `_project` (`StructuralProject`): Active structural engineering model and active storey (`_project.activeStorey`).
- `_activeTool` (`StructuralDrawTool`): Currently selected structural tool (`select`, `gridAxis`, `column`, `shearWall`, `beam`, `slab`, `slabOpening`, `measure`, `layers`).
- `_viewportNavigation` & `_transformController`: Viewport transform and `BimEditingViewport` navigation controller; pan locking is driven by `_viewportDragging`.
- Selection fields: `_selectedColumn`, `_selectedShearWall`, `_selectedBeam`, `_selectedOpening`, `_selectedOpeningVertexIndex`, `_selectedGridAxis`, `_selectedSlabVertexIndex`.
- Undo and persistence: `_pushUndo()`, `_undo()`, and `_saveProject()` (plus slab-correction-local undo via `_pushSlabCorrectionUndo()` / `_undoSlabCorrection()`).
- Analysis & overlays: `_runAnalysis()`, `_verticalCapacityReport`, `_seismicAnalysisReport`, `_openCantileverReport()`, `_openVerticalCapacityReport()`, `_openSeismicReport()`.

## 5. Reference-first implementation checklist

1. For a behavior or interaction change, identify the closest existing feature above and inspect its source in `structural_designer_screen.dart` and `Structural2dPainter`.
2. Trace the relevant `BimEditingViewport` callbacks, `_viewportDragging` pan lock, state fields, preview rendering, bottom dock/floating bar, `_pushUndo()`, and `_saveProject()`.
3. Reuse the established UI archetype (`_buildContextualElementBottomDock`, `_buildFloatingMoveBottomBar`, `_buildSlabCorrectionBottomBar`, or dialogs) by operation type.
4. Use ARB localization for new user-facing text and follow the nearest equivalent control's mobile layout.
5. For isolated visual, copy, or localization changes without behavior changes, verify only the nearest affected widget/control.
