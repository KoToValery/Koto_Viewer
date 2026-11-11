# Architect Workspace Screen — Reference & Navigation Map
> **Path**: lib/src/features/architect/screens/architect_workspace_screen.dart
> **Primary class**: _ArchitectWorkspaceScreenState
> **Important**: The source header TOC lists grep tags without line offsets. Treat this map as a discovery aid; verify method names and behavior in the current source with rg.

## 1. How to use this map

1. Use this map to discover a likely analogous feature and its source tags.
2. Search the current Dart source, for example: rg -n "\[TAG:WALL_DRAFT\]|_finishChainedWall" lib/src/features/architect/screens/architect_workspace_screen.dart
3. For behavior changes, read the relevant method bodies and immediate callers/callees. Follow related widgets, services, rendering, and viewport routing only where they participate in the feature.
4. Treat the patterns below as examples. Select the closest behaviorally similar feature; do not copy a pattern mechanically when the new requirement differs.

## 2. Source section registry

| Source anchor | Responsibility |
| --- | --- |
| [SEC-01-WIDGET] | Screen API and widget declaration |
| [TAG:STATE_FIELDS] | Tool flags, drafting state, caches, and preview state |
| [TAG:UNDERLAY_TOOLS] | CAD/raster underlay handlers and related state |
| [TAG:CAD_INSERTION] | Interactive CAD underlay placement |
| [TAG:UNDERLAY_DRAG] | Underlay snap and repositioning |
| [TAG:DRAG_TOOL] | Two-point drag and element relocation |
| [TAG:STATE_LIFECYCLE] | Initialization, listeners, and disposal |
| [TAG:XFORM_COORDS] | Screen/model transforms, snapping, and hit-test helpers |
| [TAG:TOUCH_DOWN] | Pointer-down dispatch and tool start |
| [TAG:TOUCH_MOVE] | Pointer movement, preview, and snapping |
| [TAG:TOUCH_UP] | Pointer-up dispatch and commits |
| [TAG:ZONE_LOGIC] | Zone mutations, area updates, and schedules |
| [TAG:WALL_DRAFT] | Wall drafting and chained wall placement |
| [TAG:WALL_SPLIT] | Wall splitting and cut sessions |
| [TAG:FENEST_RADIAL] | Door/window placement and radial context actions |
| [TAG:SELECTION_BAR] | Selection HUD, action bars, and layer dialogs |
| [TAG:FENESTRATION_SELECTION_UPDATES] | Selected opening parameter updates |
| [TAG:FLOATING_HUD] | Multi-step overlays and interactive edge curving |
| [TAG:GRID_AXIS] | Grid axis operations |
| [TAG:BUILD_LAYOUT] | Screen layout, bars, sheets, and view switching |
| [TAG:LOGGER_UI] | Diagnostic logs UI |
| [TAG:CANVAS_2D] | 2D viewport, painter stack, and draft overlays |
| [TAG:CAD_EXPANSION_COMMITS] | CAD primitive commit handlers |
| [TAG:VIEW_3D] | 3D viewport and publication preview |

## 3. Tool archetypes and reference flows

These are existing reference patterns, not mandatory templates. For a new feature, choose the closest match by interaction and user intent, then verify the implementation in source.

| Interaction archetype | Reference examples to inspect | What to trace |
| --- | --- | --- |
| Drafting and placement with live preview | Wall chain: [TAG:TOUCH_DOWN], [TAG:TOUCH_MOVE], [TAG:TOUCH_UP], [TAG:WALL_DRAFT], [TAG:CANVAS_2D]; _onPointerDown, _onPointerMove, _onPointerUp, _placeDraftSegment, _finishChainedWall | Tool activation/configuration, viewport input, snapping, preview, finish/cancel behavior, commit and undo/persistence |
| Opening placement and editing | [TAG:FENEST_RADIAL], [TAG:FENESTRATION_SELECTION_UPDATES], [TAG:TOUCH_DOWN], [TAG:TOUCH_UP]; _tryPlaceDoorAt, _commitOpeningPlacement | Candidate selection, host detection, placement preview, selection actions, property UI, confirmation, model update |
| Selected-element context actions | [TAG:SELECTION_BAR], [TAG:FENEST_RADIAL], [TAG:GRID_AXIS]; _handleSelectionTap, _buildSelectionBar | Selection hit path, contextual actions, property controls, cancellation/closing, state updates |
| Multi-step geometry modification | Wall split: [TAG:WALL_SPLIT]. Chamfer/fillet and edge-curving: [TAG:FLOATING_HUD]; _startChamferFilletSession, _buildChamferFilletFloatingOverlay | Session state, preview/rubber band, pan and gesture arbitration, confirm/cancel controls, model command and history |
| CAD/raster underlay placement or repositioning | [TAG:UNDERLAY_DRAG], [TAG:CAD_INSERTION]; _startUnderlaySnapDrag, _confirmUnderlaySnapPlacement | Import/configuration, hit testing, drag lifecycle, calibration, preview, commit and persistence |

## 4. Cross-cutting state and owners

- _commands: ArchitectWorkspaceViewController, the screen-level document operations controller.
- _modelCommands: ArchitectCommandController; inspect its callers to determine which mutations use this command path.
- _project: active ArchitectProject.
- _viewport: viewport transform and navigation state; verify the actual pan/gesture owner for the operation.
- _activeTool and _cursorModel: active drafting mode and current model-space pointer.
- _selectedElementIds: current selection.
- _activeWallChain: chained wall drafting state.
- _landscapeTool: terrain, pathway, vegetation, fence, and related landscape interactions.
- _dragController: two-point drag interactions; verify which element types use it.

## 5. Reference-first implementation checklist

1. For a behavior or interaction change, identify the closest existing feature with the same interaction pattern and inspect its source. Inspect a second only when needed to resolve ambiguity.
2. Trace the relevant input, hit testing/gesture arbitration, state, preview, contextual UI, commit, undo/redo, and persistence across files. Skip layers that the change does not touch.
3. Reuse the established UI behavior for comparable actions. Do not force all tools into a radial menu or all multi-step operations into one overlay.
4. Check cancellation, confirmation, active-pan behavior, hold timers, and underlying-element selection when relevant to the changed interaction.
5. Follow the analogous feature's actual command and save path. Do not assume every mutation uses _modelCommands.execute or _saveBiMProjectIfAttached.
6. Use ARB localization for new user-facing text and follow the nearest equivalent control's mobile behavior.
7. For a small presentation, localization, copy, or layout-only change, use a targeted comparison rather than tracing the full interaction lifecycle.
8. If requirements justify a meaningful deviation, implement it coherently and explain the reason in the change summary.
