# DXF Painter — LLM Semantic Navigation Map
> **Path**: `lib/src/features/dxf_viewer/rendering/dxf_painter.dart`  
> **Total Lines**: ~3,835 | **Primary Class**: `DxfPainter extends CustomPainter`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Entity / Rendering Domain**: Look at Section 3 (Entity Drawing Directory) or Section 2 (Master Section Registry).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target method name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:PAINTER_IMPORTS]` | L1 – L11 | Flutter UI, math, DXF model imports, snap helpers |
| `[SEC-01-ENUMS]` | `[TAG:PAINTER_ENUMS]` | L26 – L140 | `DxfCanvasTheme`, `DxfPaintStats`, contrast adjustments |
| `[SEC-02-LOOP]` | `[TAG:PAINTER_LOOP]` | L141 – L748 | `DxfPainter` declaration, culling checks, `paint()` pipeline |
| `[SEC-03-STROKES]` | `[TAG:PAINTER_STROKES]` | L749 – L874 | Line weights, stroke dash paths, pen color resolution |
| `[SEC-04-GEOMETRY]`| `[TAG:PAINTER_GEOM]` | L875 – L1472 | Lines, circular arcs, elliptical arcs, polylines, 2D splines |
| `[SEC-05-TEXT]` | `[TAG:PAINTER_TEXT]` | L1473 – L1808 | Single-line `TEXT`, multiline `MTEXT`, alignment & fonts |
| `[SEC-06-HATCH]` | `[TAG:PAINTER_HATCH]` | L1809 – L2157 | Solid fills, associative hatches, cross-hatching loops |
| `[SEC-07-BLOCKS]` | `[TAG:PAINTER_BLOCKS]` | L2158 – L2342 | `INSERT` references, block definition expansions, nested scales |
| `[SEC-08-DIMS]` | `[TAG:PAINTER_DIMS]` | L2343 – L2978 | Aligned, linear, angular dimensions, leader arrows, ticks |
| `[SEC-09-SNAPS]` | `[TAG:PAINTER_SNAPS]` | L2979 – L3091 | Magnetic snap indicators (endpoint, midpoint, center), selection highlights |
| `[SEC-10-MEASURE]` | `[TAG:PAINTER_MEASURE]` | L3092 – L3835 | Real-time distance measurement overlay, area badge ribbons |

---

## 3. Entity Drawing Directory

| DXF Entity Type | Primary Render Method | Section Tag |
| :--- | :--- | :--- |
| `DxfLine` | `_paintLine` | `[TAG:PAINTER_GEOM]` |
| `DxfCircle`, `DxfArc` | `_paintArc`, `_paintCircle` | `[TAG:PAINTER_GEOM]` |
| `DxfPolyline`, `DxfLwPolyline` | `_paintPolyline` | `[TAG:PAINTER_GEOM]` |
| `DxfSpline` | `_paintSpline` | `[TAG:PAINTER_GEOM]` |
| `DxfText`, `DxfMText` | `_paintText`, `_paintMText` | `[TAG:PAINTER_TEXT]` |
| `DxfHatch`, `DxfSolid` | `_paintHatch`, `_paintSolid` | `[TAG:PAINTER_HATCH]` |
| `DxfInsert` | `_paintInsert` | `[TAG:PAINTER_BLOCKS]` |
| `DxfDimension` | `_paintDimension` | `[TAG:PAINTER_DIMS]` |
