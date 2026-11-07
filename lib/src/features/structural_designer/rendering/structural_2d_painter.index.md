# Structural 2D Painter — LLM Semantic Navigation Map
> **Path**: `lib/src/features/structural_designer/rendering/structural_2d_painter.dart`  
> **Total Lines**: ~2,404 | **Primary Class**: `Structural2dPainter extends CustomPainter`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Element / Rendering Layer**: Look at Section 2 (Master Section Registry).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target method name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:S2D_IMPORTS]` | L1 – L16 | Slab colors, bubble layout, structural models |
| `[SEC-01-DISPATCH]` | `[TAG:S2D_DISPATCH]` | L29 – L333 | `Structural2dPainter` declaration, culling & `paint()` pipeline |
| `[SEC-02-GHOSTS]` | `[TAG:S2D_GHOSTS]` | L334 – L657 | Trace Reference ghost storeys, support span overlays |
| `[SEC-03-SLABS]` | `[TAG:S2D_SLABS]` | L658 – L1249 | Floor & ceiling slabs, void contours, slab thickness labels |
| `[SEC-04-STAIRS]` | `[TAG:S2D_STAIRS]` | L1250 – L1347| Stairs, elevator shafts, diagonal crossing lines |
| `[SEC-05-BEAMS-AXES]`| `[TAG:S2D_BEAMS]` | L1348 – L1590| Beams, structural grid axes, bubble numbers & offsets |
| `[SEC-06-WALLS-COLS]`| `[TAG:S2D_WALLS]` | L1591 – L1849| Shear walls, column profiles (rect, circle, L, T), guidelines |
| `[SEC-07-PREVIEWS]` | `[TAG:S2D_PREVIEWS]` | L1850 – L2250| Interactive drafting rubber-bands, snap point indicators |
| `[SEC-08-ANALYSIS]` | `[TAG:S2D_ANALYSIS]` | L2251 – L2404| Cantilever risk heatmap, seismic center of rigidity targets |

---

## 3. Element Painting Directory

| Structural Element | Painting Routine | Section Tag |
| :--- | :--- | :--- |
| Columns | `_paintColumns` | `[TAG:S2D_WALLS]` |
| Shear Walls | `_paintShearWalls` | `[TAG:S2D_WALLS]` |
| Beams | `_paintBeams` | `[TAG:S2D_BEAMS]` |
| Slabs & Voids | `_paintSlabs` | `[TAG:S2D_SLABS]` |
| Grid Axes | `_paintGridAxes` | `[TAG:S2D_BEAMS]` |
| Trace Reference | `_paintGhostStorey` | `[TAG:S2D_GHOSTS]` |
| Cantilever Zones | `_paintCantilevers` | `[TAG:S2D_ANALYSIS]` |
