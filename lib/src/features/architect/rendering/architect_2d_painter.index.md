# Architect 2D Painter — Reference & Navigation Map
> **Path**: `lib/src/features/architect/rendering/architect_2d_painter.dart`
> **Primary class**: `Architect2dPainter`
> **Important**: Treat this map as a discovery aid, not a specification. Verify concrete symbols, anchors, and behavior in the current source with `rg -n`.

## 1. How to use this map

1. Use this map to locate the rendering section, enum, method, or state field you need.
2. Search the current Dart source, for example: `rg -n "\[TAG:ARCH_PAINTER_DRAW_ACTIVE\]|_drawActiveDrafting" lib/src/features/architect/rendering/architect_2d_painter.dart`.
3. When changing canvas previews or selection feedback, inspect both `Architect2dPainter` and the matching pointer/session state in `architect_workspace_screen.dart`.

## 2. Source section registry

| Source anchor | Responsibility |
| --- | --- |
| `[SEC-01-ENUMS]` / `[TAG:ARCH_PAINTER_ENUMS]` | Declarations: `ArchitectPaintLayer`, `ArchitectTool`, `WallDraftingMode` |
| `[SEC-02-STATE]` / `[TAG:ARCH_PAINTER_STATE]` | `Architect2dPainter` state fields and constructor inputs |
| `[SEC-03-PAINT]` / `[TAG:ARCH_PAINTER_PAINT_RENDER]` | `paint` and `_paint` main rendering dispatch |
| `[SEC-04-CORE]` / `[TAG:ARCH_PAINTER_CORE_LOGIC]` | `_filterElements` layer/visibility filtering |
| `[SEC-05-PAINT]` / `[TAG:ARCH_PAINTER_DRAW_SELECTED]` | `_drawSelectedElement` and `_drawDecorativeElements` |
| `[SEC-06-WALLS]` / `[TAG:ARCH_PAINTER_WALL_OPS]` | `_drawSelectedWallHandles`, `_drawTouchGrip`, `_drawWallEndpointLeaderLine`, `_drawNewPointPreview`, `_drawPolygonEditing`, `_drawZones` |
| `[SEC-07-GRIDS]` / `[TAG:ARCH_PAINTER_GRID_AXES]` | `_drawZoneSchedule`, `_drawZoneDrafting`, `_drawZoneExtrudePreview`, `_drawDraftingGrid`, `_drawGridAxes` |
| `[SEC-08-WALLS]` / `[TAG:ARCH_PAINTER_DRAW_WALLS]` | `_drawWalls` and `_drawWallLayers` |
| `[SEC-09-PAINT]` / `[TAG:ARCH_PAINTER_DRAW_ACTIVE]` | `_drawActiveDrafting`, `_drawDraftMarker`, `_drawDashedLine` |
| `[SEC-10-CORE]` / `[TAG:ARCH_PAINTER_SHOULD_REPAINT]` | `shouldRepaint` comparison |

## 3. Top-level declarations

- `enum ArchitectPaintLayer`
- `enum ArchitectTool`
- `enum WallDraftingMode`
- `class Architect2dPainter extends CustomPainter`

## 4. Key rendering methods

| Method | Section tag | Responsibility |
| --- | --- | --- |
| `paint`, `_paint` | `[TAG:ARCH_PAINTER_PAINT_RENDER]` | Main canvas rendering pipeline and layer dispatch |
| `_filterElements` | `[TAG:ARCH_PAINTER_CORE_LOGIC]` | Storey element filtering by visibility/layer |
| `_drawSelectedElement`, `_drawDecorativeElements` | `[TAG:ARCH_PAINTER_DRAW_SELECTED]` | Selection highlights and decorative CAD elements |
| `_drawSelectedWallHandles`, `_drawTouchGrip`, `_drawWallEndpointLeaderLine` | `[TAG:ARCH_PAINTER_WALL_OPS]` | Selected wall grips and leader lines |
| `_drawNewPointPreview`, `_drawPolygonEditing`, `_drawZones` | `[TAG:ARCH_PAINTER_WALL_OPS]` | Polygon edit handles and zone fills |
| `_drawZoneSchedule`, `_drawZoneDrafting`, `_drawZoneExtrudePreview` | `[TAG:ARCH_PAINTER_GRID_AXES]` | Zone schedule table and zone drafting previews |
| `_drawDraftingGrid`, `_drawGridAxes` | `[TAG:ARCH_PAINTER_GRID_AXES]` | Background drafting grid and axis lines/bubbles |
| `_drawWalls`, `_drawWallLayers` | `[TAG:ARCH_PAINTER_DRAW_WALLS]` | Wall geometry and multi-layer composition fills |
| `_drawActiveDrafting`, `_drawDraftMarker`, `_drawDashedLine` | `[TAG:ARCH_PAINTER_DRAW_ACTIVE]` | Active tool rubber-bands, snap markers, and previews |
| `shouldRepaint` | `[TAG:ARCH_PAINTER_SHOULD_REPAINT]` | Repaint diffing across all painter inputs |

## 5. Key painter inputs & controllers

- Document & viewport: `_project`, `_visibleProject`, `project`, `viewport`, `layer`, `paintGrid`, `palette`, `l10n`, `drawingViewKey`, `publicationWallLayers`
- Active tool & drafting state: `activeTool`, `activeOpeningType`, `activeCadLineStyle`, `activeWallLayers`, `activeWallArcEnd`, `activeWallArcBulge`, `activeWallCurved`, `activeDraftStart`, `activeDraftEnd`, `stairPreview`, `activeWallThickness`, `activeWallReference`, `activeWallTypeId`, `activeWallRailing`, `activeWallHeight`, `activeWallExteriorSide`, `activeWallInsulation`, `activeOvershoot`
- Selection & interactive tool controllers: `selectedElementIds`, `selectionPreviewActive`, `activeSnapLabel`, `selectedElementId`, `selectedZoneId`, `activeZoneCategory`, `selectedAxisId`, `selectedZoneTableId`, `isZoneTableSelected`, `underlayLayerVisibility`, `activeHatchPattern`, `activeHatchColorValue`, `roofTool`, `landscapeTool`, `dragController`, `localizeSnap`

### Exact arc placement preview

`_drawActiveDrafting` (`[TAG:ARCH_PAINTER_DRAW_ACTIVE]`) renders a straight CAD
primitive whenever the draft bulge is zero, including the CAD arc tool's chord
stage and sagitta-0 previews. Only a nonzero bulge uses arc tessellation; a
zero-bulge circle has no finite radius. Input and commit ownership remain in
`[TAG:ARC_EXACT_PLACEMENT]` in the workspace screen.
