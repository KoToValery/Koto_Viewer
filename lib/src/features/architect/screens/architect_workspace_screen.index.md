# Architect Workspace Screen — LLM Semantic Navigation Map
> **Path**: `lib/src/features/architect/screens/architect_workspace_screen.dart`  
> **Total Lines**: ~33,316 | **Primary Class**: `_ArchitectWorkspaceScreenState`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step without reading 31k lines.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Tool or Feature in this document**: Look at Section 3 (Tool Routing Matrix) or Section 2 (Master Section Registry).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target method name in your prompt or infill range.
3. **Verify State Dependencies**: Look at Section 4 (State & Controller Registry) to see which fields control the tool before editing.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:IMPORTS]` | L1 – L329 | All package and internal imports (widgets, services, models) |
| `[SEC-01-WIDGET]` | `[TAG:WIDGET_API]` | L362 – L433 | `ArchitectWorkspaceScreen` StatefulWidget & `_ArchitectSurfaceHit` |
| `[SEC-02-STATE]` | `[TAG:STATE_CORE]` | L434 – L7461 | State fields, controllers, listeners, dialog triggers, and lifecycle |
| ↳ `[SUB-02A]` | `[TAG:STATE_FIELDS]` | L435 – L3831 | Active tool flags, drafting caches, preview points, mode enums |
| ↳ `[SUB-02B]` | `[TAG:STATE_PRESETS]` | L3001 – L6140 | Wall/opening style caches, layer filters, command controllers |
| ↳ `[SUB-02U]` | `[TAG:UNDERLAY_TOOLS]` | L3832 – L7197 | CAD Xref live-reload, Raster 2-point calibration & Geodesy handlers |
| ↳ `[SUB-02C]` | `[TAG:STATE_LIFECYCLE]` | L7198 – L7461 | `initState()`, `_initTransform()`, `dispose()` |
| `[SEC-03-XFORM]` | `[TAG:XFORM_COORDS]` | L7462 – L7682 | Coordinate transforms: `_screenToModel`, `_modelToScreen`, hit tests |
| `[SEC-04-TOUCH]` | `[TAG:TOUCH_INPUT]` | L7683 – L14324 | 2D Pointer & Gesture dispatch for all architectural tools |
| ↳ `[SUB-04A]` | `[TAG:TOUCH_DOWN]` | L7684 – L8724 | `_onPointerDown`: hit detection, drag initiation, tool start |
| ↳ `[SUB-04B]` | `[TAG:TOUCH_MOVE]` | L8725 – L11297 | `_onPointerMove`: hover previews, rubber-banding, snap calculations |
| ↳ `[SUB-04C]` | `[TAG:TOUCH_UP]` | L11298 – L14324 | `_onPointerUp`: tool commits, geometry insertion, history push |
| `[SEC-05-ZONES]` | `[TAG:ZONE_LOGIC]` | L14325 – L14830 | Zone mutations, area recalculations, room schedule dialogs |
| `[SEC-06-WALLS]` | `[TAG:WALL_DRAFT]` | L14831 – L15393 | Wall segment chain grouping, concept draft commit, angle locks |
| `[SEC-07-SPLIT]` | `[TAG:WALL_SPLIT]` | L15394 – L18156 | Wall splitting, cut sessions, clearance checks, intersection joints |
| `[SEC-08-FENEST]` | `[TAG:FENEST_RADIAL]` | L18157 – L23634 | Doors, windows, vitrines, radial actions menu, opening hover |
| `[SEC-09-SELECT]` | `[TAG:SELECTION_BAR]` | L23635 – L26917 | Selection HUD, reference line switch, layer dialogs, thickness bar |
| `[SEC-10-GRIDS]` | `[TAG:GRID_AXIS]` | L26918 – L27232 | Dynamic grid axes actions (offset, align, resequence, delete) |
| `[SEC-11-LAYOUT]` | `[TAG:BUILD_LAYOUT]` | L27233 – L29067 | Main `build()` method: Scaffold, HUD bars, sheets, 2D/3D toggle |
| `[SEC-12-LOGS]` | `[TAG:LOGGER_UI]` | L29068 – L29276 | `_showDebugLogsDialog` diagnostic console |
| `[SEC-13-VIEW2D]` | `[TAG:CANVAS_2D]` | L29277 – L33254 | 2D Canvas Viewport, CustomPainter stack, preview commit overlays |
| `[SEC-14-VIEW3D]` | `[TAG:VIEW_3D]` | L33255 – L33316 | 3D Viewport builder & publication preview painter |

---

## 3. Tool Routing Matrix (Pointer -> Commit -> UI)

| Tool (`ArchitectTool`) | Pointer Down/Move/Up | Commit / Action Handler | UI Bar / Dialog Widget |
| :--- | :--- | :--- | :--- |
| **wall** | L7025, L10149, L12612 | `_finishChainedWall`, `_placeDraftSegment` | `ArchitectWallReferenceControl`, `ArchitectWallThicknessDialog` |
| **door** | L7025, L10277, L11971 | `_tryPlaceDoorAt`, `_commitOpeningPlacement` | `ArchitectCandidatePicker`, `ArchitectDoorPropertiesDialog` |
| **window** | L7025, L10277, L12045 | `_tryPlaceDoorAt`, `_commitOpeningPlacement` | `ArchitectCandidatePicker`, `ArchitectFenestrationStyle` |
| **column** | L7025, L9613, L11925 | `_commitColumnPlacement` | `ArchitectColumnClearance`, `ArchitectCandidatePicker` |
| **beam** | L7025, L8043, L12842 | `_commitBeamPlacement` | `ArchitectElementPropertiesDialog` |
| **slab** | L7025, L8043, L12925 | `_commitPolygonDraft` | `ArchitectSlabLayersDialog` |
| **roof** | L7025, L10261, L12989 | `_commitRoofDraft` | `ArchitectRoofLayersDialog`, `ArchitectRoofNumberField` |
| **zone** | L7959, L10099, L12308 | `_commitDraftedZone`, `_updateZone` | `ArchitectZonePropertyBar`, `_showRoomScheduleDialog` |
| **zoneTable** | L7025, L8043, L12565 | `_commitZoneTablePlacement` | Zone schedule overlay |
| **axis** | L7161, L10055, L12174 | `_handleAxisOffset`, `_handleAxisAlign` | `ArchitectDynamicGridBar`, `_handleResequenceAxes` |
| **dimension** | L7151, L9267, L11451 | `_commitDimensionDraft` | `ArchitectAnnotationSettings` |
| **measure** | L7025, L8043, L13383 | `_finishMeasurement` | Distance preview tooltip |
| **select** | L7025, L10139, L11323 | `_commitMarquee`, `_handleSelectionTap` | `ArchitectSelectionActionBar`, `ArchitectSelectionControl` |
| **floorDrain** | L7025, L8043, L11366 | `_commitFloorDrain` | `ArchitectFloorDrainBar` |
| **hatch** | L7025, L8043, L11392 | `_commitHatch` | `ArchitectHatchPicker` |
| **services** | L7025, L9633, L12725 | `_commitServicePlacement` | Service component selector |
| **stair** | L7025, L8043, L13104 | `_commitStairDraft` | `ArchitectElementPropertiesDialog` |
| **cadLine** | L7025, L10157, L14140 | `_commitCurrentWallSegment`, `_commitLineArc` | `_lineStyleControl`, `_showLineCapsDialog`, polyline width |
| **cadArc** | L7025, L10157, L12624 | `_commitLineArc`, `_commitWallArc` | Arc radius HUD (`R=`), line style control |
| **mask** | L7025, L10310, L13000 | `_commitMask`, `_elementTool.cancelSlabDrafting` | Mask HUD bar, border toggle checkbox |
| **leader** | L7025, L10212, L13380 | `_promptAddLeaderAnnotation` | Multileader HUD bar, note dialog |
| **spline** | L7025, L10310, L13000 | `_commitSpline` | Spline HUD bar, Catmull-Rom Bezier preview |
| **cadEllipse** | L7735, L10212, L14100 | `_commitCadEllipse` | Ellipse HUD bar, line style control |
| **roofSlope** | L7735, L10315, L14115 | `_commitRoofSlopeArrow` | Roof slope HUD bar (format chips %, °, both; reverse arrow) |
| **cadUnderlay** | L3890, L30506 | `_importOrReplaceCadUnderlay`, `_loadExternalCadFileForStorey`, `_extractGeodesyFromCurrentUnderlay` | `ArchitectCadUnderlayBar`, `_openCadDxfLayersSheet` |
| **rasterUnderlay** | L7780, L9945, L13365 | `_importRasterUnderlay`, `_handleRasterCalibrationTap`, `_updateSelectedRaster` | `ArchitectRasterUnderlayBar`, `showArchitectRasterCalibrationDialog`, `showArchitectPdfPagePickerDialog` |
| **wallAttach** | L11025, L12390, L23350 | _triggerWallAttach, ConnectArchitectWallsAtVertex | _buildAttachPromptBanner, quick access bar |
| **wallDetach** | L23390, L26090 | _triggerWallDetach, _confirmWallDetach, _cancelWallDetach | _buildDetachConfirmationBanner (on-screen green checkmark) |
| **wallOffset** | L12065, L24435, L24595 | _previewOffset, _commitOffset, dynamic distance chip | _offsetBanner with tappable distance chip & green checkmark |

---

## 4. Key State Fields & Controllers Registry

- `_commands` (`ArchitectWorkspaceViewController`): Main document controller.
- `_modelCommands` (`ArchitectCommandController`): Undo/Redo & geometry transaction coordinator.
- `_project` (`ArchitectProject`): The active architectural document model.
- `_viewport` (`ArchitectViewportController`): Handles zoom, pan, screen-to-model matrix.
- `_activeTool` (`ArchitectTool`): Currently selected drafting tool.
- `_cursorModel` (`Offset?`): Real-time snapped model coordinates of pointer.
- `_selectedElementIds` (`Set<String>`): Currently highlighted/selected element IDs.
- `_activeWallChain` (`List<Offset>`): Points in currently chaining wall.
- `_marqueeTool` (`ArchitectMarqueeTool`): Multi-select rectangle logic.
- `_axisTool` (`ArchitectAxisTool`): Dynamic grid axis placement controller.
- `_zoneTool` (`ArchitectZoneTool`): Zone polygon drafting state.
- `_activeLineStartCap` / `_activeLineEndCap` (`ArchitectLineEndCap`): Active line start/end terminating caps (arrows, dots, ticks).
- `_activeLineCapSize` (`double`): Size in meters for line terminating end caps.
- `_activePolylineWidth` (`double?`): Custom thickness for polyline segments.
- `_polylineArcSegmentMode` (`bool`): Mixed polyline arc segment toggle.
- `_maskBorder` (`bool`): Mask / wipeout border frame visibility.
- `_activeRoofSlopeFormat` (`RoofSlopeFormat`): Roof slope display format (`percent`, `degree`, `both`).
- `_activeRoofSlopeDirection` (`RoofSlopeDirection`): Roof slope arrow direction (`downslope`, `upslope`).
- `_activeLeaderArrowStyle` (`ArchitectLineEndCap`): Leader arrow head terminating style.
- `_cadFileWatcher` (`ArchitectCadFileWatcher?`): Watches external CAD/DXF files for live Xref reload.
- `_rasterImages` (`Map<String, ui.Image>`): Decoded GPU images for active raster underlays.
- `_rasterCalibrationStep` / `_rasterCalibrationP1` / `_rasterCalibrationP2`: 2-point scale + deskew calibration state.

---

## 5. Safe Modification Rules for Agents
1. **Never alter the public API** of `ArchitectWorkspaceScreen` (constructor, parameters) — 55 tests depend on it.
2. **Coordinate discipline**: Always convert touch inputs via `_screenToModel(event.localPosition)` before passing to geometry algorithms.
3. **Save hook**: Any operation mutating `_project` must invoke `_saveBiMProjectIfAttached()` to preserve workspace sync.
4. **Command transactions**: Use `_beginGeometryCommand(...)` and `_modelCommands.execute(...)` to preserve Undo/Redo integrity.
