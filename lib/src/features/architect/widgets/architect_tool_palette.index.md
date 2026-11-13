# Architect Tool Palette — Reference & Navigation Map

Freeform stair entry: `_buildStairSubBar` exposes `onFreeStair` alongside the
existing preset picker and properties. It starts the workspace session under
`[TAG:STAIR_FREEFORM]`; the palette is hidden while that session owns the canvas.
Both supported ARB locales provide the entry label and its drafting messages.
> **Path**: `lib/src/features/architect/widgets/architect_tool_palette.dart`  
> **Primary class**: `_ArchitectToolPaletteState` (+1 more)  
> **Important**: Treat this map as a discovery aid, not a specification. Verify concrete symbols, anchors, and behavior in the current source with `rg -n`.

---

## 1. How to use this map

Opening size shortcuts: `_buildDoorSubBar` and `_buildWindowSubBar` under
`[TAG:ARCH_PALETTE_FENEST_OPENINGS]` offer metric dimension chips, including
150 cm window width/height and 60/140/160/180 cm door widths. The existing
parameter callbacks update drafting defaults or the selected opening through
the workspace's normal editing/history path.

Object controls: `_buildComponentSubBar` under `[TAG:ARCH_PALETTE_COMPONENT_SUB]`
keeps the Object toggle distinct from the library opener. Its compact row is
shown only while drawing, and repeated Object taps return to navigation without
opening the catalog. `_buildToolButton` uses the same deactivation rule for
auto-picked component context; catalog selection uses the workspace's normal
tool-reset path.

1. Use this map to find the relevant section tag, class, or method name.
2. Search the current Dart source with `rg -n "\[TAG:<NAME>\]|<SymbolName>" lib/src/features/architect/widgets/architect_tool_palette.dart`.
3. For behavior changes, read the target implementation and its immediate callers/callees; follow the Reference-First protocol in `AGENTS.md` / `GEMINI.md`.

---

## 2. Source section registry

| Section ID | Tag | Description & Primary Responsibilities |
| :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:ARCH_PALETTE_IMPORTS]` | Package, model, service, and widget imports |
| `[SEC-01-WIDGET]` | `[TAG:ARCH_PALETTE_WIDGET]` | Declarations: `ArchitectToolPalette` |
| `[SEC-02-STATE]` | `[TAG:ARCH_PALETTE_STATE]` | `_ArchitectToolPaletteState` state fields (51 fields: `category`, `colors`, `activeTool`, `mode`, `onToolChanged`) |
| `[SEC-03-BUILD]` | `[TAG:ARCH_PALETTE_BUILD_LAYOUT]` | Widget Build & HUD Layout: `build`, `_buildToolButton` (2 methods) |
| `[SEC-04-WALLS]` | `[TAG:ARCH_PALETTE_WALL_OPS]` | Wall Drafting, Splitting & Joints: `_buildWallSubBar`, `_chooseWallType`, `_buildDrawingShortcut` (3 methods) |
| `[SEC-05-OPENINGS]` | `[TAG:ARCH_PALETTE_FENEST_OPENINGS]` | Doors, Windows & Openings: `_buildWindowSubBar`, `_buildDoorSubBar` (2 methods) |
| `[SEC-06-BUILD]` | `[TAG:ARCH_PALETTE_COMPONENT_SUB]` | Widget Build & HUD Layout: `_buildComponentSubBar`, `_buildColumnSubBar`, `_buildStairSubBar`, `_buildBeamSubBar` (4 methods) |
| `[SEC-07-OPENINGS]` | `[TAG:ARCH_PALETTE_OPENING_SUB]` | Doors, Windows & Openings: `_buildOpeningSubBar`, `_buildZoneSubBar` (2 methods) |
| `[SEC-08-HITS]` | `[TAG:ARCH_PALETTE_HIT_TESTING]` | Hit Testing & Candidate Picking: `_showStylePicker`, `_buildViewsSubBar`, `_buildDecorativeSubBar` (3 methods) |

---

## 3. Classes, Enums & Top-Level Declarations

| Symbol | Kind | Members | Signature / Heritage |
| :--- | :--- | :--- | :--- |
| `ArchitectToolPalette` | class | 98 | `class ArchitectToolPalette extends StatefulWidget` |
| `_ArchitectToolPaletteState` | class | 70 | `class _ArchitectToolPaletteState extends State<ArchitectToolPalette>` |

---

## 4. Method & Action Directory (21 methods indexed)

| Method / Handler | Class | Section Tag | Summary / Signature |
| :--- | :--- | :--- | :--- |
| `ArchitectToolPalette` | `ArchitectToolPalette` | `[TAG:ARCH_PALETTE_WIDGET]` | const ArchitectToolPalette({ super.key, this.zonePresets = const ArchitectZ |
| `createState` | `ArchitectToolPalette` | `[TAG:ARCH_PALETTE_WIDGET]` | State<ArchitectToolPalette> createState() |
| `initState` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_STATE]` | void initState() |
| `_browseTools` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_STATE]` | Future<void> _browseTools() async |
| `didUpdateWidget` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_STATE]` | void didUpdateWidget(ArchitectToolPalette oldWidget) |
| `build` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_BUILD_LAYOUT]` | Widget build(BuildContext context) |
| `_buildToolButton` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_BUILD_LAYOUT]` | Widget _buildToolButton( |
| `_buildDrawingShortcut` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_WALL_OPS]` | Widget _buildDrawingShortcut(BuildContext context, ArchitectTool tool) |
| `_chooseWallType` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_WALL_OPS]` | Future<void> _chooseWallType() async |
| `_buildWallSubBar` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_WALL_OPS]` | Widget _buildWallSubBar(BuildContext context) |
| `_buildDoorSubBar` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_FENEST_OPENINGS]` | Widget _buildDoorSubBar(BuildContext context) |
| `_buildWindowSubBar` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_FENEST_OPENINGS]` | Widget _buildWindowSubBar(BuildContext context) |
| `_buildColumnSubBar` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_COMPONENT_SUB]` | Widget _buildColumnSubBar(BuildContext context) |
| `_buildBeamSubBar` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_COMPONENT_SUB]` | Widget _buildBeamSubBar(BuildContext context) |
| `_buildComponentSubBar` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_COMPONENT_SUB]` | Widget _buildComponentSubBar(BuildContext context) |
| `_buildStairSubBar` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_COMPONENT_SUB]` | Widget _buildStairSubBar(BuildContext context) |
| `_buildOpeningSubBar` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_OPENING_SUB]` | Widget _buildOpeningSubBar(BuildContext context) |
| `_buildZoneSubBar` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_OPENING_SUB]` | Widget _buildZoneSubBar(BuildContext context) |
| `_showStylePicker` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_HIT_TESTING]` | void _showStylePicker(BuildContext context, FenestrationKind kind) |
| `_buildDecorativeSubBar` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_HIT_TESTING]` | Widget _buildDecorativeSubBar(BuildContext context) |
| `_buildViewsSubBar` | `_ArchitectToolPaletteState` | `[TAG:ARCH_PALETTE_HIT_TESTING]` | Widget _buildViewsSubBar(BuildContext context) |

---

## 5. Key State Fields & Controllers Registry (147 fields)

- `activeTool` (`ArchitectTool`)
- `drawingOnly` (`bool`)
- `interactionMode` (`ArchitectInteractionMode?`)
- `selectionTool` (`ArchitectTool?`)
- `onDrawSelection` (`VoidCallback?`)
- `onSelectAll` (`VoidCallback?`)
- `onFindAndSelect` (`VoidCallback?`)
- `onTerrain` (`VoidCallback?`)
- `onToolChanged` (`ValueChanged<ArchitectTool>`)
- `multiSelect` (`bool`)
- `onToggleMultiSelect` (`VoidCallback?`)
- `onCreateFenestration` (`VoidCallback?`)
- `activeWindowStyle` (`ArchitectFenestrationStyle?`)
- `activeDoorStyle` (`ArchitectFenestrationStyle?`)
- `onWindowStyleSelected` (`ValueChanged<ArchitectFenestrationStyle>?`)
- `onDoorStyleSelected` (`ValueChanged<ArchitectFenestrationStyle>?`)
- `zonePresets` (`ArchitectZonePresets`)
- `activeZoneCategory` (`ArchitectZoneCategory`)
- `onZoneCategoryChanged` (`ValueChanged<ArchitectZoneCategory>`)
- `wallThickness` (`double`)
- `onWallThicknessChanged` (`ValueChanged<double>`)
- `wallMode` (`WallDraftingMode`)
- `onWallModeChanged` (`ValueChanged<WallDraftingMode>`)
- `curvedWall` (`bool`)
- `onArcWallSelected` (`VoidCallback?`)
- `isChainingWall` (`bool`)
- `activeWallType` (`ArchitectWallType?`)
- `onWallTypeSelected` (`ValueChanged<ArchitectWallType>?`)
- `wallProjectId` (`String`)
- `selectedDoor` (`ArchitectDoor?`)
- `selectedWindow` (`ArchitectWindow?`)
- `activeDecorativePreset` (`ArchitectDecorativeElement?`)
- `category` (`ArchitectToolCategory`)
- `activeTool` (`ArchitectTool`)
- `mode` (`ArchitectInteractionMode`)
- `onToolChanged` (`ValueChanged<ArchitectTool>`)
- `activeWindowStyle` (`ArchitectFenestrationStyle?`)
- `activeDoorStyle` (`ArchitectFenestrationStyle?`)
- `onWindowStyleSelected` (`ValueChanged<ArchitectFenestrationStyle>?`)
- `onDoorStyleSelected` (`ValueChanged<ArchitectFenestrationStyle>?`)
- `activeZoneCategory` (`ArchitectZoneCategory`)
- `wallMode` (`WallDraftingMode`)
- `onWallModeChanged` (`ValueChanged<WallDraftingMode>`)
- `activeWallType` (`ArchitectWallType?`)
- `onWallTypeSelected` (`ValueChanged<ArchitectWallType>?`)
- *+102 additional fields in source*
