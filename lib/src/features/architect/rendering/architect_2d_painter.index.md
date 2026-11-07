# Architect 2d Painter — LLM Semantic Navigation Map
> **Path**: `lib/src/features/architect/rendering/architect_2d_painter.dart`  
> **Total Lines**: ~2,302 | **Primary Class**: `Architect2dPainter`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step without reading the full file.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Section, Class, or Method**: Check Section 2 (Master Section Registry), Section 3 (Class Registry), or Section 4 (Method Directory).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the exact line range via `read_file` (`StartLine`–`EndLine`).
   - Never read the entire file at once; always read only the target 50–150 line range.
3. **Check State Dependencies**: Review Section 5 (State Fields & Controllers Registry) before modifying interactive or stateful methods.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:ARCH_PAINTER_IMPORTS]` | L1 – L45 | Package, model, service, and widget imports |
| `[SEC-01-ENUMS]` | `[TAG:ARCH_PAINTER_ENUMS]` | L66 – L125 | Declarations: `ArchitectPaintLayer`, `ArchitectTool`, `WallDraftingM |
| `[SEC-02-STATE]` | `[TAG:ARCH_PAINTER_STATE]` | L126 – L387 | `Architect2dPainter` state fields (111 fields: `_project`, `_visible |
| `[SEC-03-PAINT]` | `[TAG:ARCH_PAINTER_PAINT_RENDER]` | L388 – L734 | Canvas Painting & Geometry Rendering: `_paint`, `paint` (2 methods) |
| `[SEC-04-CORE]` | `[TAG:ARCH_PAINTER_CORE_LOGIC]` | L735 – L825 | Core Operations & Helpers: `_filterElements` (1 methods) |
| `[SEC-05-PAINT]` | `[TAG:ARCH_PAINTER_DRAW_SELECTED]` | L826 – L1011 | Canvas Painting & Geometry Rendering: `_drawSelectedElement`, `_draw |
| `[SEC-06-WALLS]` | `[TAG:ARCH_PAINTER_WALL_OPS]` | L1012 – L1226 | Wall Drafting, Splitting & Joints: `_drawPolygonEditing`, `_drawNewP |
| `[SEC-07-GRIDS]` | `[TAG:ARCH_PAINTER_GRID_AXES]` | L1227 – L1388 | Grid Axes, Alignment & Snapping: `_drawDraftingGrid`, `_drawGridAxes |
| `[SEC-08-WALLS]` | `[TAG:ARCH_PAINTER_DRAW_WALLS]` | L1389 – L1556 | Wall Drafting, Splitting & Joints: `_drawWalls`, `_drawWallLayers` ( |
| `[SEC-09-PAINT]` | `[TAG:ARCH_PAINTER_DRAW_ACTIVE]` | L1557 – L2260 | Canvas Painting & Geometry Rendering: `_drawActiveDrafting`, `_drawD |
| `[SEC-10-CORE]` | `[TAG:ARCH_PAINTER_SHOULD_REPAINT]` | L2261 – L2302 | Core Operations & Helpers: `shouldRepaint` (1 methods) |

---

## 3. Classes, Enums & Top-Level Declarations

| Symbol | Kind | Lines (Span) | Members | Signature / Heritage |
| :--- | :--- | :--- | :--- | :--- |
| `ArchitectPaintLayer` | enum | L68 – L68 (1L) | 0 | `enum ArchitectPaintLayer` |
| `ArchitectTool` | enum | L70 – L122 (53L) | 0 | `enum ArchitectTool` |
| `WallDraftingMode` | enum | L124 – L124 (1L) | 0 | `enum WallDraftingMode` |
| `Architect2dPainter` | class | L129 – L2302 (2174L) | 133 | `class Architect2dPainter extends CustomPainter` |

---

## 4. Method & Action Directory (23 methods indexed)

| Method / Handler | Class | Section Tag | Lines (Span) | Summary / Signature |
| :--- | :--- | :--- | :--- | :--- |
| `Architect2dPainter` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_STATE]` | L268–L386 (119L) | Architect2dPainter({ required ArchitectProject project, this.viewport, this |
| `paint` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_PAINT_RENDER]` | L391–L397 (7L) | void paint(Canvas canvas, Size size) |
| `_paint` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_PAINT_RENDER]` | L398–L730 (333L) | void _paint(Canvas canvas, Size size) |
| `_filterElements` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_CORE_LOGIC]` | L737–L824 (88L) | ArchitectStorey _filterElements( ArchitectStorey storey, |
| `_drawSelectedElement` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_DRAW_SELECTED]` | L828–L974 (147L) | void _drawSelectedElement(Canvas canvas) |
| `_drawDecorativeElements` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_DRAW_SELECTED]` | L976–L1010 (35L) | void _drawDecorativeElements(Canvas canvas, ArchitectStorey storey) |
| `_drawSelectedWallHandles` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_WALL_OPS]` | L1014–L1050 (37L) | void _drawSelectedWallHandles(Canvas canvas, ArchitectWall wall) |
| `_drawTouchGrip` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_WALL_OPS]` | L1052–L1072 (21L) | void _drawTouchGrip( Canvas canvas, Offset handle, double draftingScale, Co |
| `_drawWallEndpointLeaderLine` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_WALL_OPS]` | L1074–L1106 (33L) | void _drawWallEndpointLeaderLine(Canvas canvas) |
| `_drawNewPointPreview` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_WALL_OPS]` | L1108–L1155 (48L) | void _drawNewPointPreview(Canvas canvas) |
| `_drawPolygonEditing` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_WALL_OPS]` | L1157–L1209 (53L) | void _drawPolygonEditing(Canvas canvas) |
| `_drawZones` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_WALL_OPS]` | L1211–L1225 (15L) | void _drawZones(Canvas canvas) |
| `_drawZoneSchedule` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_GRID_AXES]` | L1229–L1257 (29L) | void _drawZoneSchedule(Canvas canvas) |
| `_drawZoneDrafting` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_GRID_AXES]` | L1273–L1282 (10L) | void _drawZoneDrafting(Canvas canvas) |
| `_drawZoneExtrudePreview` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_GRID_AXES]` | L1284–L1299 (16L) | void _drawZoneExtrudePreview(Canvas canvas) |
| `_drawDraftingGrid` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_GRID_AXES]` | L1305–L1345 (41L) | void _drawDraftingGrid(Canvas canvas, Size size) |
| `_drawGridAxes` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_GRID_AXES]` | L1351–L1383 (33L) | void _drawGridAxes(Canvas canvas) |
| `_drawWalls` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_DRAW_WALLS]` | L1391–L1507 (117L) | void _drawWalls(Canvas canvas) |
| `_drawWallLayers` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_DRAW_WALLS]` | L1509–L1551 (43L) | void _drawWallLayers( Canvas canvas, ArchitectWallLayers layers, Paint bord |
| `_drawActiveDrafting` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_DRAW_ACTIVE]` | L1559–L2166 (608L) | void _drawActiveDrafting(Canvas canvas) |
| `_drawDraftMarker` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_DRAW_ACTIVE]` | L2168–L2237 (70L) | static void _drawDraftMarker( Canvas canvas, Offset point, |
| `_drawDashedLine` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_DRAW_ACTIVE]` | L2239–L2259 (21L) | static void _drawDashedLine( Canvas canvas, Offset p1, Offset p2, Paint pai |
| `shouldRepaint` | `Architect2dPainter` | `[TAG:ARCH_PAINTER_SHOULD_REPAINT]` | L2264–L2301 (38L) | bool shouldRepaint(covariant Architect2dPainter oldDelegate) |

---

## 5. Key State Fields & Controllers Registry (110 fields)

- `_project` (`ArchitectProject`, L130)
- `_visibleProject` (`ArchitectProject?`, L131)
- `project` (`ArchitectProject`, L132)
- `viewport` (`BimViewportController?`, L133)
- `layer` (`ArchitectPaintLayer`, L134)
- `paintGrid` (`bool`, L135)
- `publicationWallLayers` (`ArchitectWallLayers?`, L137) — Publication can share physical wall geometry between annotation scales.
- `drawingViewKey` (`String?`, L138)
- `palette` (`ArchitectCanvasPalette`, L139)
- `l10n` (`AppLocalizations?`, L140)
- `activeTool` (`ArchitectTool`, L141)
- `activeOpeningType` (`OpeningType`, L142)
- `showServiceProjections` (`bool`, L143)
- `activeCadLineStyle` (`ArchitectLineStyle`, L144)
- `activeWallLayers` (`List<ArchitectMaterialLayer>`, L145)
- `activeWallArcEnd` (`Offset?`, L146)
- `activeWallArcBulge` (`double?`, L147)
- `activeWallCurved` (`bool`, L148)
- `activeDraftStart` (`Offset?`, L149)
- `activeDraftEnd` (`Offset?`, L150)
- `stairPreview` (`ArchitectStair?`, L151)
- `activeWallThickness` (`double`, L152)
- `landscapeTool` (`ArchitectLandscapeTool?`, L266) — Active landscape drafting state for Terrain, Pathway, Vegetation, and Site Fence.
- `activeWallReference` (`WallReferenceLine`, L153)
- `activeWallTypeId` (`String?`, L154)
- `activeWallRailing` (`ArchitectRailingDesign?`, L155)
- `activeWallHeight` (`double?`, L156)
- `activeWallExteriorSide` (`WallExteriorSide`, L157)
- `activeWallSideManual` (`bool activeWallIsExterior,`, L158)
- `activeWallInsulation` (`double?`, L160)
- `selectedElementIds` (`Set<String>`, L177)
- `selectionPreviewActive` (`bool`, L178)
- `activeSnapLabel` (`String?`, L183)
- `selectedElementId` (`String?`, L184)
- `selectedZoneId` (`String?`, L185)
- `activeZoneCategory` (`ArchitectZoneCategory?`, L186)
- `selectedAxisId` (`String?`, L203)
- `selectedZoneTableId` (`String?`, L237)
- `isZoneTableSelected` (`bool`, L238)
- `underlayLayerVisibility` (`Map<String, bool>`, L243)
- `activeHatchPattern` (`ArchitectHatchPattern`, L247)
- `activeHatchColorValue` (`int`, L248)
- `roofTool` (`ArchitectRoofTool?`, L250)
- `activeOvershoot` (`ArchitectWallOvershoot?`, L260)
- `_elementLayerStorey` (`ArchitectStorey`, L732)
- `_zoneLayerProject` (`ArchitectProject`, L1259)
- *+65 additional fields in `L130–L1271`*
