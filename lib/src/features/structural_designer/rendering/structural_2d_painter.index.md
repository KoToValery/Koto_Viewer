# Structural 2D Painter — Reference & Navigation Map
> **Path**: `lib/src/features/structural_designer/rendering/structural_2d_painter.dart`
> **Primary class**: `Structural2dPainter`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete method names with `rg -n`.

## 1. How to use this map

1. Use this map to locate the element painting routine or overlay helper you need.
2. Search the current Dart source, for example: `rg -n "_drawShearWall|_drawInteractivePreview|_drawSlab" lib/src/features/structural_designer/rendering/structural_2d_painter.dart`.
3. Inspect both `Structural2dPainter` and `structural_designer_screen.dart` when updating previews, grips, or analysis overlays.

## 2. Key painting methods

| Layer / element | Concrete symbols | Responsibility |
| --- | --- | --- |
| Main pipeline & measurements | `Structural2dPainter`, `paint`, `_drawMeasurementLine` | Painter entrypoints and measurement lines |
| Ghost storeys & foundations | `_drawGhostStorey`, `_drawGroundFoundations` | Trace reference ghost storeys and strip/mat foundations |
| Slabs & openings | `_drawSlab`, `_drawSlabLabels`, `_drawSlabVertexHandles`, `_drawSlabEdgeGrips`, `_drawEdgeExtrusionPreview`, `_drawOpeningVertexHandles`, `_drawOpeningEdgeGrips`, `_drawOpeningExtrusionPreview`, `_drawStaircaseTreads`, `_drawElevatorCabin` | Slabs, vertex/edge handles, extrusion previews, and stairs/elevator openings |
| Beams & grid axes | `_drawBeam`, `_drawGridAxis`, `_drawAxisBubble`, `_drawDashDotLine` | Beams, structural grid axes, and axis bubbles |
| Walls, columns & guides | `_drawShearWall`, `_drawColumn`, `_drawMagneticGuidelines` | Shear walls, column shapes, and magnetic alignment guides |
| Previews & analysis overlays | `_drawInteractivePreview`, `_drawSupportSpanFeedback`, `_drawSupportOverviewLabels`, `_drawCantileverOverlays`, `_drawSeismicCenters`, `_drawCenterTarget` | Active drafting previews, span checks, cantilever heatmaps, and seismic center targets |
