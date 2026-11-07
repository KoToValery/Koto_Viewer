# BIM Alignment Screen — LLM Semantic Navigation Map
> **Path**: `lib/src/features/bim_projects/screens/bim_alignment_screen.dart`  
> **Total Lines**: ~1,560 | **Primary Class**: `_BimAlignmentScreenState`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Alignment Feature**: Look at Section 2 (Master Section Registry).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target method name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:BAS_IMPORTS]` | L1 – L21 | DXF models, painter, layers, BiM project models |
| `[SEC-01-WIDGET]` | `[TAG:BAS_WIDGET]` | L22 – L38 | `BimAlignmentScreen` StatefulWidget declaration & parameters |
| `[SEC-02-STATE]` | `[TAG:BAS_STATE]` | L39 – L300 | State fields, storey list, interactive matrix transforms |
| `[SEC-03-LOADER]` | `[TAG:BAS_LOADER]` | L301 – L650 | Underlay DXF file loader, caching & storey underlay picker |
| `[SEC-04-POINTS]` | `[TAG:BAS_POINTS]` | L651 – L950 | Reference control point placement, snap calculations |
| `[SEC-05-BUILD]` | `[TAG:BAS_BUILD]` | L951 – L1350| Main `build()` layout: Storey tabs, top HUD, bottom action bar |
| `[SEC-06-PAINTER]` | `[TAG:BAS_PAINTER]` | L1351 – L1560| `_ControlPointOverlayPainter` CustomPainter & crosshairs |

---

## 3. Key Multi-Storey Alignment Operations

| Operation | Method Name | Section Tag |
| :--- | :--- | :--- |
| Load Storey Underlay | `_loadStoreyUnderlay` | `[TAG:BAS_LOADER]` |
| Place Control Point | `_setReferencePoint` | `[TAG:BAS_POINTS]` |
| Switch Storey Tab | `_switchStorey` | `[TAG:BAS_BUILD]` |
| Calibrate Coordinate Frame | `_commitAlignmentFrame` | `[TAG:BAS_POINTS]` |
