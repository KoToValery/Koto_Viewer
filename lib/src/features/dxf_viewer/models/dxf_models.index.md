# DXF Models — LLM Semantic Navigation Map
> **Path**: `lib/src/features/dxf_viewer/models/dxf_models.dart`  
> **Total Lines**: ~2,079 | **Primary Class**: `DxfDocument` & `DxfEntity`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Model / Class**: Look at Section 2 (Master Section Registry) or Section 3 (Class Directory).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target class name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:DXF_M_IMPORTS]` | L1 – L5 | Math, Flutter Material, QuadTree & math helpers |
| `[SEC-01-TABLES]` | `[TAG:DXF_M_TABLES]` | L6 – L163 | `DxfPolylineVertex`, `DxfTextStyle`, `DxfDimStyle`, `DxfLayer` |
| `[SEC-02-COMPILED]` | `[TAG:DXF_M_COMPILED]`| L164 – L400 | Fast path rendering caches: `DxfCompiledLine`, `DxfCompiledBlock` |
| `[SEC-03-BLOCKS]` | `[TAG:DXF_M_BLOCKS]` | L401 – L437 | `DxfBlock` definition container & base points |
| `[SEC-04-BASE]` | `[TAG:DXF_M_BASE]` | L438 – L466 | `abstract class DxfEntity`: layer, color, lineType, bounds |
| `[SEC-05-CURVES]` | `[TAG:DXF_M_CURVES]` | L467 – L787 | `DxfLine`, `DxfCircle`, `DxfArc`, `DxfEllipse`, `DxfPolyline`, `DxfSpline` |
| `[SEC-06-TEXT]` | `[TAG:DXF_M_TEXT]` | L788 – L957 | `DxfText`, `DxfMText`: alignment, rotation, bounding boxes |
| `[SEC-07-HATCHES]` | `[TAG:DXF_M_HATCHES]`| L958 – L1070| `DxfSolid`, `DxfHatch`, `DxfHatchPatternLine`, boundary loops |
| `[SEC-08-BLOCKREFS]`| `[TAG:DXF_M_BLOCKREFS]`|L1071 – L1259| `DxfAttribute`, `DxfAttdef`, `DxfInsert` (scales, rotations) |
| `[SEC-09-DIMS]` | `[TAG:DXF_M_DIMS]` | L1260 – L1535| `DxfDimension`, `DxfLeader`, `DxfMLeader`, `DxfViewport` |
| `[SEC-10-DOC]` | `[TAG:DXF_M_DOC]` | L1536 – L1854| `DxfDocument`: master document model, layer index, QuadTree |
| `[SEC-11-MEASURE]` | `[TAG:DXF_M_MEASURE]` | L1855 – L2079| `DxfUnit`, `DxfMeasureTool`, `DxfAnnotation`, `DxfMeasurement` |

---

## 3. Class Directory

| Class Name | Line Range | Section Tag |
| :--- | :--- | :--- |
| `DxfLayer` | L86 – L163 | `[TAG:DXF_M_TABLES]` |
| `DxfEntity` | L438 – L466 | `[TAG:DXF_M_BASE]` |
| `DxfLine`, `DxfCircle`, `DxfArc` | L467 – L653 | `[TAG:DXF_M_CURVES]` |
| `DxfLwPolyline`, `DxfPolyline` | L654 – L737 | `[TAG:DXF_M_CURVES]` |
| `DxfText`, `DxfMText` | L788 – L957 | `[TAG:DXF_M_TEXT]` |
| `DxfHatch` | L1019 – L1070 | `[TAG:DXF_M_HATCHES]` |
| `DxfInsert` | L1180 – L1259 | `[TAG:DXF_M_BLOCKREFS]` |
| `DxfDimension` | L1260 – L1327 | `[TAG:DXF_M_DIMS]` |
| `DxfDocument` | L1536 – L1854 | `[TAG:DXF_M_DOC]` |
