# Structural Magnetic Alignment Helper — LLM Semantic Navigation Map
> **Path**: `lib/src/features/structural_designer/analysis/structural_magnetic_alignment_helper.dart`  
> **Total Lines**: ~1,828 | **Primary Class**: `StructuralMagneticAlignmentHelper`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Element Alignment Helper**: Look at Section 2 (Master Section Registry).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target method name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:SMA_IMPORTS]` | L1 – L6 | DXF models, snap helpers, structural element models |
| `[SEC-01-MODELS]` | `[TAG:SMA_MODELS]` | L7 – L113 | Alignment result records: `ColumnMagneticAlignmentResult`, guidelines |
| `[SEC-02-COLUMNS]` | `[TAG:SMA_COLUMNS]` | L114 – L1047| Column snapping to grid axes, neighboring columns, slab edges |
| `[SEC-03-WALLS]` | `[TAG:SMA_WALLS]` | L1048 – L1525| Shear wall snapping: collinear merge, L/T corner joints, axis offset |
| `[SEC-04-BEAMS]` | `[TAG:SMA_BEAMS]` | L1526 – L1828| Beam alignment: column center snap, wall node snap, ortho locks |

---

## 3. Magnetic Snapping Routines

| Target Element | Alignment Routine | Section Tag |
| :--- | :--- | :--- |
| Column | `alignColumn` | `[TAG:SMA_COLUMNS]` |
| Shear Wall | `alignShearWall` | `[TAG:SMA_WALLS]` |
| Beam | `alignBeam` | `[TAG:SMA_BEAMS]` |
