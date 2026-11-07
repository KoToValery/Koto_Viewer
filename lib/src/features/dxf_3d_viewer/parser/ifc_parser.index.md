# IFC 3D Parser — LLM Semantic Navigation Map
> **Path**: `lib/src/features/dxf_3d_viewer/parser/ifc_parser.dart`  
> **Total Lines**: ~4,207 | **Primary Class**: `IfcParser` & `_IfcGeometrySolver`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Parsing Stage**: Look at Section 2 (Master Section Registry).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target method name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:IFC_IMPORTS]` | L1 – L9 | Flutter rendering, vector_math, 3D models, isolates |
| `[SEC-01-PARSER]` | `[TAG:IFC_PARSER_API]`| L10 – L90 | `IfcParser` public API, STEP header tokenizer, `_parseIfcFileCompute` |
| `[SEC-02-STRUCTS]` | `[TAG:IFC_STRUCTS]` | L91 – L234 | `_RawIfcEntity`, `_IfcParamTokenizer`, `_Transform3D`, `_Obb`, `_Plane3D` |
| `[SEC-03-SOLVER]` | `[TAG:IFC_SOLVER_INIT]`| L235 – L733 | `_IfcGeometrySolver` lifecycle, entity map indexing, spatial tree |
| `[SEC-04-ELEMENTS]` | `[TAG:IFC_CATEGORIES]`| L734 – L1346 | `_categorizeIfcType`: walls, slabs, columns, doors, windows, corner joints |
| `[SEC-05-XFORMS]` | `[TAG:IFC_XFORMS]` | L1347 – L1750 | `_resolveAxis2Placement3D`, `_resolvePlacement`, coordinate matrices |
| `[SEC-06-PROFILES]` | `[TAG:IFC_PROFILES]` | L1751 – L2260 | Profile curves: rectangle, circle, composite, arbitrary closed profile |
| `[SEC-07-OPENINGS]` | `[TAG:IFC_OPENINGS]` | L2261 – L2809 | `IfcRelVoidsElement`, opening geometry extraction, bounding boxes |
| `[SEC-08-BOOLEANS]` | `[TAG:IFC_BOOLEANS]` | L2810 – L3295 | CSG boolean clipping: `_clipMeshByCuttingSolid`, half-spaces |
| `[SEC-09-MATERIALS]`| `[TAG:IFC_MATERIALS]`| L3296 – L3600 | `IfcStyledItem`, RGB color mapping, material property sets |
| `[SEC-10-BREP-MESH]`| `[TAG:IFC_BREP_MESH]` | L3601 – L4207 | Brep face extraction, 3D polygon triangulation, degenerate filtering |

---

## 3. Key Geometry & Conversion Operations

| Operation | Method Name | Section Tag |
| :--- | :--- | :--- |
| Coordinate Transforms | `_resolveAxis2Placement3D` | `[TAG:IFC_XFORMS]` |
| Curve Extraction | `_resolveCurvePoints` | `[TAG:IFC_XFORMS]` |
| Opening Subtractions | `_clipMeshByCuttingSolid` | `[TAG:IFC_BOOLEANS]` |
| Wall Corner Welding | `_bridgeConnectedWallCorners`| `[TAG:IFC_CATEGORIES]` |
| Color / Texture Styling | `_mapMaterialNameToColor` | `[TAG:IFC_MATERIALS]` |
| 3D Triangulation | `_triangulatePolygon3D` | `[TAG:IFC_BREP_MESH]` |
