# Wall & Axis Detector — LLM Semantic Navigation Map
> **Path**: `lib/src/features/structural_designer/analysis/wall_axis_detector.dart`  
> **Total Lines**: ~2,353 | **Primary Class**: `WallAxisDetector`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Detection Phase**: Look at Section 2 (Master Section Registry).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target method name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:WAD_IMPORTS]` | L1 – L9 | Underlay source, DXF models, structural models |
| `[SEC-01-DETECT]` | `[TAG:WAD_DETECT]` | L10 – L420 | `WallAxisDetector.detect()`: Auto-scale detection (mm/cm/m), scoring |
| `[SEC-02-AXIS-GEN]` | `[TAG:WAD_AXES]` | L421 – L909 | Grid axis clustering, orientation alignment, bubble labels |
| `[SEC-03-FILTERS]` | `[TAG:WAD_FILTERS]` | L910 – L1100 | Border rejection, clutter layers, paper space filtering |
| `[SEC-04-SEGMENTS]` | `[TAG:WAD_SEGMENTS]` | L1101 – L1446| Segment extraction: Lines, LwPolylines, nested Block Inserts |
| `[SEC-05-PAIRS]` | `[TAG:WAD_PAIRS]` | L1447 – L1840| Parallel pair matching (20cm shear walls, 25cm masonry) |
| `[SEC-06-BRIDGES]` | `[TAG:WAD_BRIDGES]` | L1841 – L2020| Door/window gap bridging, collinear segment clustering |
| `[SEC-07-TOPOLOGY]` | `[TAG:WAD_TOPOLOGY]` | L2021 – L2353| Corner snapping (L-corners, T-junctions) & contour output |

---

## 3. Core Detection Algorithms

| Algorithm Step | Method Name | Section Tag |
| :--- | :--- | :--- |
| Auto-Scale / Unit Detection | `_detectScaleFromSegments` | `[TAG:WAD_DETECT]` |
| Parallel Pair Search | `_findParallelPairs` | `[TAG:WAD_PAIRS]` |
| Door / Window Bridging | `_bridgeCollinearOpenings` | `[TAG:WAD_BRIDGES]` |
| L/T Corner Snapping | `_snapTopologicalCorners` | `[TAG:WAD_TOPOLOGY]` |
| Grid Axis Generation | `_generateGridAxesFromWalls` | `[TAG:WAD_AXES]` |
