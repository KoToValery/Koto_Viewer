# DXF Painter — Reference & Navigation Map
> **Path**: `lib/src/features/dxf_viewer/rendering/dxf_painter.dart`
> **Primary class**: `DxfPainter`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete class or method names with `rg -n`.

## 1. How to use this map

1. Use this map to identify the painter theme, stats, or rendering method you need.
2. Search the current Dart source, for example: `rg -n "_renderEntity|_renderInsert|_renderDimensionText" lib/src/features/dxf_viewer/rendering/dxf_painter.dart`.
3. Check callers in `dxf_viewer_screen.dart` and `structural_designer_screen.dart` before altering overrides or theme contrast behavior.

## 2. Key declarations & rendering methods

| Area | Concrete symbols | Responsibility |
| --- | --- | --- |
| Themes & diagnostics | `DxfCanvasTheme`, `DxfPaintStats`, `DxfBlockDiagEntry`, `DxfCachedTextLayout` | Canvas theme presets, paint diagnostics, and text layout cache |
| Painter core | `DxfPainter`, `_drawGrid`, `_renderEntity` | Main `CustomPainter` pipeline, culling, grid, and entity dispatch |
| Specialized renderers | `_renderSinglePatternLineFamily`, `_renderInsert`, `_renderDimensionText`, `_drawSingleLeaderAnnotation`, `_drawBadge` | Hatch patterns, block inserts, dimensions, leaders, and measurement badges |
