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
| [TAG:UNDERLAY_CROP] | Selected CAD/raster clipping grips, isolated preview and one-release commit |
| [TAG:CAD_INSERTION] | Interactive CAD underlay placement |
| [TAG:UNDERLAY_DRAG] | Underlay snap and repositioning |
| [TAG:DRAG_TOOL] | Two-point drag and element relocation |
| [TAG:STATE_LIFECYCLE] | Initialization, listeners, and disposal |
| [TAG:XFORM_COORDS] | Screen/model transforms, snapping, and hit-test helpers |
| [TAG:TOUCH_DOWN] | Pointer-down dispatch and tool start |
| [TAG:TOUCH_MOVE] | Pointer movement, preview, and snapping |
| [TAG:TOUCH_UP] | Pointer-up dispatch and commits |
| [TAG:OBJECT_PLACEMENT] | Exclusive furniture/service placement preview and shared Apply/Cancel |
| [TAG:OBJECT_REPLACEMENT] | Catalog replacement retaining object identity and placement |
| [TAG:ZONE_LOGIC] | Zone mutations, area updates, and schedules |
| [TAG:WALL_DRAFT] | Wall drafting and chained wall placement |
| [TAG:WALL_ENDPOINT_ANGLE] | Straight-wall endpoint angle constraint and compact unlock control |
| [TAG:WALL_OPERATION_AXES] | Fillet/Chamfer core-axis geometry; wall-specific axis dimensions for corner edits and Offset |
| [TAG:ARC_EXACT_PLACEMENT] | Shared wall/line/arc sequence: exact chord, shaping, exact rise, commit |
| [TAG:WALL_SPLIT] | Wall splitting and cut sessions |
| [TAG:FENEST_RADIAL] | Door/window placement and radial context actions |
| [TAG:SELECTION_BAR] | Selection HUD, action bars, and layer dialogs |
| [TAG:FENESTRATION_SELECTION_UPDATES] | Selected opening parameter updates |
| [TAG:FLOATING_HUD] | Multi-step overlays and interactive edge curving |
| [TAG:CURVING_EXACT_INPUT] | Existing-element Curve: exact h first, fixed-rise side preview, final Apply/Cancel |
| [TAG:CURVING_FEEDBACK] | One neutral localized rise/snap badge, placed clear of edited geometry |
| [TAG:MIRROR_WORKFLOW] | Mirror axis picking, preview, cancellation and commit |
| [TAG:GRID_AXIS] | Grid axis operations |
| [TAG:BUILD_LAYOUT] | Screen layout, bars, sheets, and view switching |
| [TAG:LOGGER_UI] | Diagnostic logs UI |
| [TAG:CANVAS_2D] | 2D viewport, painter stack, and draft overlays |
| [TAG:CAD_EXPANSION_COMMITS] | CAD primitive commit handlers |
| [TAG:ELLIPSE_DRAFT] | Centre/first semi-axis/second semi-axis drafting and exact review |
| [TAG:SHAPE_EXACT_INPUT] | Shared size panel bounded to the available canvas above the palette |
| [TAG:SLAB_DRAFT_CONTROLS] | Manual slab toolbar and staged composition defaults |
| [TAG:POLYGON_ANGLE_LOCK] | Selected Hatch/slab on-canvas angle constraint |
| [TAG:VIEW_3D] | 3D viewport and publication preview |

## 3. Tool archetypes and reference flows

These are existing reference patterns, not mandatory templates. For a new feature, choose the closest match by interaction and user intent, then verify the implementation in source.

| Interaction archetype | Reference examples to inspect | What to trace |
| --- | --- | --- |
| Drafting and placement with live preview | Wall chain: [TAG:TOUCH_DOWN], [TAG:TOUCH_MOVE], [TAG:TOUCH_UP], [TAG:WALL_DRAFT], [TAG:CANVAS_2D]; _onPointerDown, _onPointerMove, _onPointerUp, _placeDraftSegment, _finishChainedWall | Tool activation/configuration, viewport input, snapping, preview, finish/cancel behavior, commit and undo/persistence |
| Opening placement and editing | [TAG:FENEST_RADIAL], [TAG:FENESTRATION_SELECTION_UPDATES], [TAG:TOUCH_DOWN], [TAG:TOUCH_UP]; _tryPlaceDoorAt, _commitOpeningPlacement | Candidate selection, host detection, placement preview, selection actions, property UI, confirmation, model update |
| Selected-element context actions | [TAG:SELECTION_BAR], [TAG:FENEST_RADIAL], [TAG:GRID_AXIS]; _handleSelectionTap, _buildSelectionBar | Selection hit path, contextual actions, property controls, cancellation/closing, state updates |
| Two-point drag of elements or underlays | [TAG:DRAG_TOOL], [TAG:UNDERLAY_DRAG], [TAG:TOUCH_DOWN], [TAG:TOUCH_MOVE], [TAG:TOUCH_UP]; _startDragSession, _startUnderlaySnapDrag, _updateDragTarget, _cancelDragGesture, _confirmDragPlacement, _cancelDragPlacement, ArchitectDragController | Dormant touch input allows pan/pinch before either pick; taps or precision holds choose points. Navigation preserves the session and placed target; Apply commits once. Both element and underlay drag use the same controller and lifecycle, with no generic geometry-command preview. |
| Multi-step geometry modification | Wall split: [TAG:WALL_SPLIT]. Chamfer/fillet and edge-curving: [TAG:FLOATING_HUD]; _startChamferFilletSession, _buildChamferFilletFloatingOverlay | Session state, preview/rubber band, pan and gesture arbitration, confirm/cancel controls, model command and history |
| CAD/raster underlay placement or repositioning | [TAG:UNDERLAY_DRAG], [TAG:CAD_INSERTION], [TAG:DRAG_TOOL]; _startUnderlaySnapDrag, _confirmDragPlacement | Import/configuration, shared drag lifecycle, calibration, preview, commit and persistence |

### CAD underlay display settings

`_openCadEditDialog` uses `_updateCadPresentation` to commit opacity, source
colors and source lineweights through the existing model/history/autosave path.
`ArchitectUnderlayPainter` passes the active config into `drawUnderlay`;
`ArchitectUnderlayPresentation` resolves display pens without mutating the CAD
document. Its opacity applies to both uniform tint and original colors. Raster
images retain their existing image-opacity controls; CAD-specific style toggles
are omitted for raster inputs. Underlay masks, hit testing and snap geometry
are unchanged by these display settings.

### Storey management and return to drawing

`_manageWorkspaceViews(plan)` opens `ArchitectStoreysScreen` with the shared
model controller. The manager returns its selected storey ID through the route;
the explicit Back/Return controls reopen it through `_selectWorkspaceView`,
preserving the workspace's camera/navigation lifecycle. Storey edits use the
existing command history and the workspace model listener's save debounce.
The manager's copy action opens `ArchitectCopyStoreyDialog` and executes
`CopyArchitectElementsAcrossStoreys`; no separate copy controls or category
state are maintained in the manager.

### Layer visibility menu

Layer visibility menu: `_openLayersDialog` under `[TAG:SELECTION_BAR]` follows
the live-listener pattern of `ArchitectGridAxisBar`. Its route listens to
`_commands` and passes the current project into `ArchitectLayersDialog` on each
change, including Undo/Redo. The existing callbacks commit and save as before.
`ArchitectWorkspaceViewController.commit` forwards layers and element-layer
assignments to the source model from sections/elevations, alongside line styles.
`ArchitectLayer.sortedForDisplay` groups hidden layers first, then sorts each
group by localized name; the element-layer picker shares that display order.
The modal route retains normal input blocking for the drawing viewport.

### Drag entry points and exclusive ownership

| Entry point | Session owner | Confirmation and cancellation |
| --- | --- | --- |
| _handleRadialAction(move), _setSelectionMove(free), _changeTool(drag) | _startDragSession -> ArchitectDragController | _confirmDragPlacement / _cancelDragPlacement |
| CAD/raster context Move | _startUnderlaySnapDrag -> ArchitectDragController | Same Drag handlers, preserving underlay coordinates and masks |
| Transverse move or numeric offset | _beginGeometryCommand(move) and the existing constrained-edit state | Generic geometry-command handlers; do not merge with free Drag |

Free Drag must not coexist with _commandPreview: one owner of preview, cancel,
and commit. A touch down leaves the selected element inactive so an ordinary
swipe pans, including over the selected element or its leader grip. A tap or
precision-hold release picks the base (on or off the element) without moving
anything. A separate pick freezes a valid target candidate (_dragTargetPlaced).
`_updateDragAim` shares the drafting hold/offset-pointer pattern through
`_beginPlacementHold` and `StructuralPointerInteraction.placementTarget`;
grabbing the default leader preserves its offset while relocating the base.
The viewport locks pan only during precision aiming (or direct mouse aiming),
and disables selection/context hold timers. Pinch, scroll and trackpad navigation
interrupt the gesture through _cancelDragGesture while preserving the tool,
base and any already placed target. A later canvas pick may revise the target,
and the sole Drag Apply control publishes one undoable mutation and saves.
While active, drafting/selection/context-hold controls and the bottom palette
are hidden. The palette retains its state and returns after confirm/cancel;
the canvas expands before the base-point pick and stays stable during movement.
Regression coverage: test/features/architect/architect_drag_tool_ui_regression_test.dart.

### Wall operation axes

`[TAG:WALL_OPERATION_AXES]`: `ArchitectWallOperationAxis.core` derives the
calculation line/arc from the physical core. `restore` converts the result back
to the wall's saved placement reference, including concentric arc radii.
`ArchitectChamferFillet.wallPairChamfer` / `wallPairFillet` share this conversion,
keep hosted opening positions, and refuse clipped openings or an impossible
typed radius/setback. Both the second-wall pick and two-wall dialog paths use
the same pure geometry, then the existing atomic commit/Undo/save path.
With one wall or CAD line selected, _startChamferFilletSession starts the
second-element HUD before numeric input. A matching pick selects both elements
and opens _openChamferFilletDialog; a preselected pair opens it immediately.
Dialog cancellation leaves the single-source session available for another pick.
_applyChamferFillet stages the pair through the generic preview, whose sole Apply
publishes the edit. Pending corner picks suppress selection/context hold timers.
`ArchitectOffset` normalizes connected core-axis endpoints, offsets the chains,
and restores each wall's own reference and opening stations. Detached ends stay
independent. CAD/polygon operations retain their native geometry. Short ARB
axis labels are passed only for wall selections; dynamic wall clearances use core faces.
Coverage: `architect_wall_operation_axis_test.dart` and
`architect_wall_core_operations_phone_test.dart`, plus
`architect_corner_selection_test.dart` in `test/features/architect/`.

### Lightweight command controls and hints

ArchitectFloatingCommandOverlay renders independent 32 px action discs with
48 px touch targets on a transparent surface. Labels and the general canvas
guidance use ArchitectCanvasHint (compact, neutral chips); embedded numeric
editors retain their own surface. Drag measurements and snap feedback share
one badge in ArchitectDragPainterHelper to avoid overlapping labels.
These widgets/painters change presentation only; session ownership stays above.

### Mirror axis workflow

`[TAG:MIRROR_WORKFLOW]` covers `_previewMirrorSnap`, `_pickMirrorSnap`,
`_startMirrorSession`, `_executeMirror`, and `_confirmMirror`.
`ArchitectTransformPointInput` owns axis picks and navigation. Aiming applies
`MirrorArchitectElements` to `ArchitectCommandPreview.original`; it never stages
another reflection of the preview. Axis placement stages one candidate and
keeps the Mirror HUD as the sole owner through review. The localized Keep
original checkbox defaults off, reuses a session-stable ID map and rebuilds from
the original model on every toggle. `_confirmMirror` publishes once through the
shared confirmation/history path and selects the final copies. The generic HUD
and generic review input stay suppressed while Mirror owns the session.

### Wall reference, detach and contact-only attach

Wall drafting uses `ArchitectWallAttachment.continuation` to carry the ordered
chain's exterior side through turns. Independent starts retain physical-face
adoption. `_snapWall` selects core-only geometry for walls;
`ArchitectWallGeometry.coreWalls` supplies cached proxies for object snaps,
midpoint tracking, alignment, translation and endpoint edits. Two-point Drag also
uses core geometry for both picks when its selection contains walls. Other drawing tools
keep the full physical geometry. A snapped `corePoint` lets
`_orientWallReference` compensate the active finish-based leading line, including
inside plaster, before preview/commit.

`ArchitectWallDraftControls` places reference, Flip and curve controls above
the exact length without resetting the keypad. The exact panel exposes Axis,
Inside and Outside as separate icon buttons; the toolbar retains its compact
reference dropdown. Flip shares `_flipDraftWallSide`
with the toolbar; `_setDraftWallCurve` / `_toggleExactWallCurve` preserve the current chord and enter
the existing `_beginDraftArcShaping` flow on confirmation. The wall panel uses
`BimDistanceDraftingPanel.continuePrimary`; Enter follows Next when shown.
The arc hint distinguishes picking the end, confirming an already fixed chord,
and setting rise/direction. `_commitWallArc` follows the current chain mode via
`_commitCurrentWallSegment`; the next segment starts at the saved arc endpoint.
Toolbar and palette shape changes retain the chain, and switching back to a
straight segment during shaping restores the fixed chord for exact review.
All labels/tooltips use ARB messages. Placement continues through
`_placeDraftSegment`, `CreateArchitectWall`, command history and the existing save
path. Regression coverage: `architect_wall_core_snapping_test.dart` and
`architect_wall_drafting_controls_test.dart` and `architect_arc_exact_placement_test.dart`.

`_setWallReferenceLine` and wall properties use
`SetArchitectElementProperties.preserveWallPosition` (default true). The core
axis remains fixed while the saved reference is reconstructed, including
concentric arcs; connected neighbours are not carried by that representation
change. The setting can be disabled explicitly.

`_confirmWallDetach` publishes its candidate directly after its sole confirmation.
The persisted `ArchitectWall.autoAttachAfterMove` distinguishes a temporary user
Detach from cut ends. Movement commands call `ArchitectWallConnectionPolicy.afterMove`
using the original detached wall, so old neighbours do not follow it. A real
relocation restores connections only at finite physical contact; a free wall
keeps waiting. Zero movement and cancellation do not release Detach. `AttachArchitectWalls` validates existing finite end-cap/body contact and
only changes connection flags. CAD vertex joining retains its separate command.
Contact predicates use model metres (0.1 mm tolerance), never the pointer radius.

### Core clearances and contour editing

`ArchitectWallClearance.nearest`, `endpoints`, and `nearView` use physical core
faces for witnesses and numeric movement. Support recognition retains the saved
physical wall relationship, including endpoints placed on a finish face.
Persistent dimension chains have their independent measurement convention.
Chamfer/Fillet initial input and parameter changes share
`BimDistanceDraftingPanel`, project units/decimals and one final command preview.
The second-wall HUD excludes the generic HUD until a result is ready.
Hatch and slab edit entry initializes angle-preserving movement (`extendCatheti`).
The contextual padlock switches between that constraint and free `move` for the
current element. Explicit `pull` remains a separate extrusion operation and hides
the padlock. Other CAD contours retain their existing three operation choices.

Regression coverage: `architect_wall_safety_refinements_test.dart`,
`architect_wall_core_operations_phone_test.dart`, `architect_mirror_elements_test.dart`,
and `architect_wall_operation_axis_test.dart` in `test/features/architect/`.

## 4. Cross-cutting state and owners

### Straight-wall endpoint angle

`[TAG:WALL_ENDPOINT_ANGLE]`: `_buildWallAngleOverlay` reuses the temporary
white-paper dimension badge pattern, with a 44 px touch target outside the
endpoint/offset grips. A straight selected wall starts angle-locked. Tapping
the badge sets `_wallAngleUnlockedId`; explicit unlock removes angular capture
for small corrections. The choice is transient and clears with selection.
Unlocked endpoint nudges use a 1 px touch dead zone; other handles retain 6 px.
The endpoint branch of `_updatePointerPreview` uses `ArchitectWallEndpointSnap`
for actual straight walls only; CAD lines, polylines and curved walls keep their
existing resolver. Locked snaps use true crossings on the original direction,
never an off-axis endpoint. Global magnet toggling does not change the lock.
Preview and release keep `UpdateArchitectWall(carryConnections: true)`,
`_commitActiveHandleDrag`, the existing history/save path and gesture ownership.
Whole-wall Drag, transverse move and numeric offset do not use this constraint.
Regression coverage: `test/features/architect/architect_wall_angle_lock_test.dart`.

- _commands: ArchitectWorkspaceViewController, the screen-level document operations controller.
- _modelCommands: ArchitectCommandController; inspect its callers to determine which mutations use this command path.
- _project: active ArchitectProject.
- _viewport: viewport transform and navigation state; verify the actual pan/gesture owner for the operation.
- _activeTool and _cursorModel: active drafting mode and current model-space pointer.
- _selectedElementIds: current selection.
- _activeWallChain: chained wall drafting state.
- _landscapeTool: terrain, pathway, vegetation, fence, and related landscape interactions.
- _dragController: the single two-point drag controller for elements and CAD/raster underlays; verify the active branch before changing preview or commit behavior.

## 5. Reference-first implementation checklist

1. For a behavior or interaction change, identify the closest existing feature with the same interaction pattern and inspect its source. Inspect a second only when needed to resolve ambiguity.
2. Trace the relevant input, hit testing/gesture arbitration, state, preview, contextual UI, commit, undo/redo, and persistence across files. Skip layers that the change does not touch.
3. Reuse the established UI behavior for comparable actions. Do not force all tools into a radial menu or all multi-step operations into one overlay.
4. Check cancellation, confirmation, active-pan behavior, hold timers, and underlying-element selection when relevant to the changed interaction.
5. Follow the analogous feature's actual command and save path. Do not assume every mutation uses _modelCommands.execute or _saveBiMProjectIfAttached.
6. Use ARB localization for new user-facing text and follow the nearest equivalent control's mobile behavior.
7. For a small presentation, localization, copy, or layout-only change, use a targeted comparison rather than tracing the full interaction lifecycle.
8. If requirements justify a meaningful deviation, implement it coherently and explain the reason in the change summary.

### Exact curved placement

`[TAG:ARC_EXACT_PLACEMENT]`: `_curvedDraftTool` shares wall, curved CAD line /
polyline, and CAD arc placement. The second canvas pick locks `_draftEnd` and
opens `BimDistanceDraftingPanel`; its Apply calls `_beginDraftArcShaping`
without committing. The third pick opens `_editWallArcDimension(commitDraft:
true)` in sagitta mode. Cancel restores the draft; Apply calls `_commitWallArc`
through the existing draft command/history and save path. The numeric editor
also remains available from the dimension badge without auto-commit.
`_draftArcExactBulge` preserves a typed value across hover. Sagitta 0 is a
straight wall/line (CAD arcs change primitive type to line). Active curved
placement locks single-pointer panning through the viewport callback; existing
context-hold guards reject active drafts before underlay hit testing. The shared
panel uses a centered bottom position on phones, with bounded scrolling for
short viewports. `ArchitectWallArcDimensionDialog` shares the numeric keypad
and permits zero for sagitta while radius still requires a finite positive value.

### Curving feedback presentation

`_buildCurvingEdgeFloatingOverlay` (`[TAG:CURVING_FEEDBACK]`) supplies model
geometry, compact localized snap labels, and drawing obstacle queries to
`widgets/architect_curving_edge_overlay.dart`. `ArchitectCurvingEdgeOverlay`
owns the neutral guide painter and one `h=… · Midpoint` badge. It reuses
`ArchitectClearanceBadgeLayout` and `ArchitectFloatingCommandOverlay`, avoids
the edited curve, walls, grips and endpoints, and reserves canvas edges for
the existing bars. The painter no longer paints a second label on the wall;
midpoint alignment uses the existing `snapMidpoint` ARB message. Pending
Apply/Cancel still call `_commitCurvingEdgeSession` / `_cancelCurvingEdgeSession`;
input routing, snap calculations, model commands and history stay in the screen.

### Existing-element exact Curve workflow

`_initCurvingEdgeSession` opens `_showCurvingEdgeExactInputDialog` immediately
(`[TAG:CURVING_EXACT_INPUT]`), with sagitta mode and the element's actual
curvature (including 0). Wall validation retains its real host properties;
CAD/contour edges use a thin surrogate. Typing updates only the preview.
Accepting the dialog sets `_curvingEdgeExactBulge` and shows the neutral
Apply/Cancel HUD without committing. Handle dragging selects the side and
preserves the entered rise; snap labels appear only when the exact apex
reaches a target. Release returns to review, without reopening numeric input.
Only the HUD Apply calls `_commitCurvingEdgeSession` through the existing
command/history/save path; Cancel restores the original. Dialog callbacks
check project/element/endpoints before applying asynchronous results.

The curving preview branch precedes adopted drawing-tool previews in
`_updatePointerPreview`. Selection/context holds reject active curving sessions,
so stationary holds and secondary taps cannot steal the grip; viewport pan
locking continues through `_isActivelyDraggingHandle`. Final CAD line/arc edits
use the existing `ArchitectLineEditing` adapter with `UpdateArchitectWall`;
polyline/contour segments use `UpdateArchitectBulges`, preserving existing IDs.

### Compact distance checkpoint and corner command identities

`[TAG:DRAFT_DISTANCE_PANEL]`: `_hasDistanceDraftPanel` is the shared visibility
predicate for the pending wall and CAD line/arc/polyline segment.
Snapping never hides the editable distance or chooses another confirmation flow.
The panel starts collapsed, including arc chord input. Tapping its value opens
the existing in-app keypad immediately. Continue/End/Cancel keep the established
callbacks, command/history and save paths. The first-point floating cancel stays
available before a checkpoint; `_draftCancelRect` returns null while the panel
owns cancellation, including hit-test and obstacle rectangles.

`BimDistanceDraftingPanel` uses a single 44 px action row at phone widths, short
localized captions where space permits, and a two-row fallback in narrow hosts.
Its `extraControls` and input state survive leading-line changes. No native
keyboard is opened. Exact-value dialogs can still request an initially open
keypad explicitly.

Selection menus expose Chamfer/Fillet once: walls and CAD segments retain the
wall-actions entries; other contours use the localized Corners group. Both
entries use canonical command IDs. `BimEditActions.icon` and all direct corner
controls share the dedicated `chamfer` and `fillet` SVG IDs; Curve keeps its own
symbol. Coverage: `architect_compact_drafting_panel_test.dart`,
`architect_arc_exact_placement_test.dart` and `command_icons_test.dart`.

### Shape dimensions, ellipse and selected contours

`[TAG:SHAPE_EXACT_INPUT]` places `BimShapeDimensionPanel` through
`ArchitectExactInputOverlay`: bottom-centred on phones and bounded near the
anchor on desktop. Actions precede the collapsible/scrollable local keypad.
`ArchitectEllipseDraft` owns centre -> first semi-axis -> perpendicular second
semi-axis; review is frozen until exact Apply/Cancel. `ArchitectEllipseGeometry`
defines the persisted centre/radii/rotation contract for all consumers. Existing
visible centres are preserved. Placement publishes one creation command.

`[TAG:SLAB_DRAFT_CONTROLS]` stages slab properties in a temporary model until
manual contour completion; it never creates a placeholder in the real project.
`[TAG:POLYGON_ANGLE_LOCK]` uses the wall badge archetype. Edge release for Hatch
and slabs opens `_editPolygonDisplacement` automatically; vertices retain their
separate precision option. Manual Hatch points are accepted immediately with
snaps and never enter the wall distance checkpoint.

### Project snapshots and editable underlay crops

`_underlayOwnerId` is the attached manifest ID or standalone model ID.
`_restorePersistedUnderlays` prefers saved architectural snapshots over supplied
fallback documents. Architectural opening uses
`BimUnderlayLoadMode.architecturalOriginal`; aligned fallback originals are
captured once into owner-local assets with their effective coordinate frame.
Visibility caches are per storey. External changes require explicit Refresh.

`[TAG:UNDERLAY_CROP]` reuses polygon edge geometry with `extendCatheti`, but owns
a separate preview editor. Grip routing precedes raster/selection input. Only
release commits masks through `_commands.commit`; cancellation/navigation drops
the preview. `ArchitectUnderlayClip` supplies inclusive mask hits and clipped
CAD segments for shared/wall/endpoint snaps. Cropped areas cannot steal selection
or snaps; selected boundary grips remain available for expansion. Raster direct
drag also previews without mutation, translating its mask in the same final edit.
Regression coverage: `architect_drawing_controls_revision_test.dart`,
`architect_ellipse_geometry_test.dart`, `architect_underlay_mask_snap_test.dart`
and `architect_underlay_snapshot_test.dart`.
