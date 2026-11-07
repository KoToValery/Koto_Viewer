# Structural Element Models — LLM Semantic Navigation Map
> **Path**: `lib/src/features/structural_designer/models/structural_element.dart`  
> **Total Lines**: ~1,908 | **Primary Class**: `StructuralProject` & `StoreyLevel`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Element Model**: Look at Section 2 (Master Section Registry) or Section 3 (Class Directory).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target model class name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:SEM_IMPORTS]` | L1 – L11 | BiM polygon geometry, contour repair, grid axes |
| `[SEC-01-COLUMNS]` | `[TAG:SEM_COLUMNS]` | L12 – L223 | `ColumnShape`, `GhostStoreyMode`, `StructuralColumn` (Rect, Circular, L-shape) |
| `[SEC-02-WALLS]` | `[TAG:SEM_WALLS]` | L224 – L373 | `ShearWallReferenceLine`, `StructuralShearWall` (thickness, offset, 2D profile) |
| `[SEC-03-BEAMS]` | `[TAG:SEM_BEAMS]` | L374 – L489 | `StructuralBeam` (start/end nodes, width, depth, drop profile) |
| `[SEC-04-OPENINGS]` | `[TAG:SEM_OPENINGS]`| L490 – L547 | `SlabOpeningType`, `SlabOpening` (shaft, void, stair opening) |
| `[SEC-05-SLABS]` | `[TAG:SEM_SLABS]` | L548 – L1203| `StructuralSlab`, `SlabZoneKind`, polygon contours, cantilever checks |
| `[SEC-06-STOREYS]` | `[TAG:SEM_STOREYS]` | L1204 – L1371| `StoreyLevel`: elevation, floor-to-floor height, element collections |
| `[SEC-07-PROJECT]` | `[TAG:SEM_PROJECT]` | L1372 – L1908| `StructuralProject`, serialization, foundation types, JSON transforms |

---

## 3. Class Directory

| Class Name | Line Range | Section Tag |
| :--- | :--- | :--- |
| `StructuralColumn` | L27 – L223 | `[TAG:SEM_COLUMNS]` |
| `StructuralShearWall` | L232 – L373 | `[TAG:SEM_WALLS]` |
| `StructuralBeam` | L374 – L489 | `[TAG:SEM_BEAMS]` |
| `SlabOpening` | L505 – L547 | `[TAG:SEM_OPENINGS]` |
| `StructuralSlab` | L561 – L1203 | `[TAG:SEM_SLABS]` |
| `StoreyLevel` | L1204 – L1371 | `[TAG:SEM_STOREYS]` |
| `StructuralProject` | L1416 – L1908 | `[TAG:SEM_PROJECT]` |
