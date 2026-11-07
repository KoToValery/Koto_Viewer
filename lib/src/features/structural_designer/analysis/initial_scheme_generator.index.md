# Initial Scheme Generator — LLM Semantic Navigation Map
> **Path**: `lib/src/features/structural_designer/analysis/initial_scheme_generator.dart`  
> **Total Lines**: ~2,342 | **Primary Class**: `InitialSchemeGenerator`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Scheme Synthesis Stage**: Look at Section 2 (Master Section Registry).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target method name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:ISG_IMPORTS]` | L1 – L20 | Wall networks, window detectors, seismic/vertical calculators |
| `[SEC-01-OPTIONS]` | `[TAG:ISG_OPTIONS]` | L31 – L267 | `InitialSchemeOptions`, `InitialSchemeProposal`, `_WallRun` |
| `[SEC-02-GEN]` | `[TAG:ISG_GENERATOR]`| L268 – L1227| `InitialSchemeGenerator.generate()` pipeline & geometric helpers |
| `[SEC-03-CORES]` | `[TAG:ISG_CORES]` | L1228 – L1414| Staircase, elevator shaft & core boundary shear walls |
| `[SEC-04-WALLS]` | `[TAG:ISG_WALLS]` | L1415 – L1791| Shear wall placement, seismic X/Y pairing, stiffness center |
| `[SEC-05-COLUMNS]` | `[TAG:ISG_COLUMNS]` | L1792 – L2164| Column layout, span optimization, grid intersection matching |
| `[SEC-06-BEAMS]` | `[TAG:ISG_BEAMS]` | L2165 – L2342| Perimeter & tie beams, final scheme structural validation |

---

## 3. Structural Synthesis Operations

| Synthesis Stage | Method Name | Section Tag |
| :--- | :--- | :--- |
| Core Wall Placement | `_placeCoreWalls` | `[TAG:ISG_CORES]` |
| Seismic Wall Pairing | `_placeSeismicShearWalls` | `[TAG:ISG_WALLS]` |
| Column Span Grid | `_placeColumns` | `[TAG:ISG_COLUMNS]` |
| Tie Beam Generation | `_generateConnectingBeams` | `[TAG:ISG_BEAMS]` |
| Layout Optimization | `_evaluateAndOptimizeScheme` | `[TAG:ISG_OPTIONS]` |
