# STEP 3D Parser — LLM Semantic Navigation Map
> **Path**: `lib/src/features/dxf_3d_viewer/parser/step_parser.dart`  
> **Total Lines**: ~1,787 | **Primary Class**: `StepParser`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Parsing Stage / Geometry**: Look at Section 2 (Master Section Registry).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target method name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:STEP_IMPORTS]` | L1 – L9 | Flutter, math, NURBS surface evaluator, Mesh3D models |
| `[SEC-01-MATH]` | `[TAG:STEP_MATH]` | L10 – L285 | `_UVPoint`, `_StepEntity`, `_StepAxisPlacement`, `_StepBSplineCurve`, `_StepMatrix4` |
| `[SEC-02-API]` | `[TAG:STEP_API]` | L286 – L600 | `StepParser` public API, background isolate parsing, tokenization |
| `[SEC-03-CURVES]` | `[TAG:STEP_CURVES]` | L601 – L1100 | CARTESIAN_POINT, DIRECTION, LINE, CIRCLE, B_SPLINE_CURVE |
| `[SEC-04-SURFACES]` | `[TAG:STEP_SURFACES]`| L1101 – L1500| Analytical & freeform surfaces: Plane, Cylinder, Cone, Torus, B-Spline |
| `[SEC-05-TOPOLOGY]` | `[TAG:STEP_TOPOLOGY]`| L1501 – L1787| ADVANCED_FACE, CLOSED_SHELL, surface triangulation & normal calculation |

---

## 3. Key STEP Geometry Operations

| Operation | Method Name | Section Tag |
| :--- | :--- | :--- |
| Coordinate Transforms | `_resolveAxisPlacement` | `[TAG:STEP_MATH]` |
| Curve Evaluation | `_evaluateBSplineCurve` | `[TAG:STEP_CURVES]` |
| NURBS Surface Tessellation | `_tessellateSurface` | `[TAG:STEP_SURFACES]` |
| Face Triangulation | `_triangulateFace` | `[TAG:STEP_TOPOLOGY]` |
