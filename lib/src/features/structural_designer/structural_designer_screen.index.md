# Structural Designer Screen — LLM Semantic Navigation Map
> **Path**: `lib/src/features/structural_designer/structural_designer_screen.dart`  
> **Total Lines**: ~9,175 | **Primary Class**: `_StructuralDesignerScreenState`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Tool or Feature in this document**: Look at Section 3 (Tool & Action Directory) or Section 2 (Master Section Registry).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target method name in your prompt or infill range.
3. **Verify State Dependencies**: Look at Section 4 (State & Controller Registry) before editing.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:STRUCT_IMPORTS]` | L1 – L78 | All package and internal imports |
| `[SEC-01-WIDGET]` | `[TAG:STRUCT_WIDGET]` | L97 – L126 | `StructuralDesignerScreen` StatefulWidget & parameters |
| `[SEC-02-STATE]` | `[TAG:STRUCT_STATE]` | L127 – L767 | State fields, active tool, storey cache, `initState`, `dispose` |
| `[SEC-03-XFORM]` | `[TAG:STRUCT_XFORM]` | L768 – L872 | Matrix4 & Canvas transforms: screenToCad, cadToScreen, zoom/pan |
| `[SEC-04-HITS]` | `[TAG:STRUCT_HITS]` | L873 – L1196 | Hit testing for structural columns, walls, slabs, and beam edges |
| `[SEC-05-ACTIONS]` | `[TAG:STRUCT_ACTIONS]` | L1197 – L1966 | Column dimensioning, wall thickness, beam profile mutation |
| `[SEC-06-OPENINGS]` | `[TAG:STRUCT_OPENINGS]`| L1967 – L2992 | Wall openings, slab voids, grid axes creation & resequencing |
| `[SEC-07-SLABS]` | `[TAG:STRUCT_SLABS]` | L2993 – L3339 | Slab contour auto-detection, polygon editing, cantilever check |
| `[SEC-08-POINTER]` | `[TAG:STRUCT_POINTER]` | L3340 – L5740 | Pointer gestures: onPointerDown, onPointerMove, onPointerUp |
| `[SEC-09-COMMITS]` | `[TAG:STRUCT_COMMITS]` | L5741 – L6282 | Final commit handlers for placed columns, walls, slabs, beams |
| `[SEC-10-UNDERLAY]` | `[TAG:STRUCT_UNDERLAY]`| L6283 – L7126 | DXF layer filtering, pen color overrides, trace reference levels |
| `[SEC-11-STOREY]` | `[TAG:STRUCT_STOREY]` | L7127 – L7363 | Storey switching, vertical alignment, seismic analysis triggers |
| `[SEC-12-APPBAR]` | `[TAG:STRUCT_APPBAR]` | L7364 – L7674 | Header app bar, tool palette toggle, calculation action icons |
| `[SEC-13-BUILD]` | `[TAG:STRUCT_BUILD]` | L7675 – L8384 | Main `build()` method, interactive canvas viewport stack |
| `[SEC-14-DOCKS]` | `[TAG:STRUCT_DOCKS]` | L8385 – L9175 | Contextual bottom sheets, candidate picker dock, element properties |

---

## 3. Tool & Action Directory

| Element / Tool | Pointer Handler | Commit Method | Context UI / Dock |
| :--- | :--- | :--- | :--- |
| **Column** | L3340+ | `_commitColumnPlacement` | `_buildColumnDock` |
| **Shear Wall** | L3340+ | `_commitWallPlacement` | `_buildWallDock` |
| **Beam** | L3340+ | `_commitBeamPlacement` | `_buildBeamDock` |
| **Slab** | L2993+ | `_commitSlabContour` | `_buildSlabDock` |
| **Opening** | L1967+ | `_commitOpeningPlacement` | Opening candidate sheet |
| **Grid Axis** | L1967+ | `_commitGridAxis` | Grid axis property bar |
| **Cantilever** | L2993+ | `_checkCantileverOverhangs`| `VerticalCapacitySheet` |

---

## 4. Key State Fields & Controllers Registry

- `_project` (`StructuralProject`): The active structural engineering model.
- `_activeStoreyId` (`String`): Current building level ID.
- `_activeTool` (`StructuralTool`): Currently selected structural design tool.
- `_selectedElementIds` (`Set<String>`): Highlighted structural members.
- `_traceStoreyId` (`String?`): Underlay trace reference storey ID.
- `_transform` (`Matrix4`): Interactive viewport transform matrix.
- `_analysisController`: Manages seismic, vertical capacity, and deflection analysis.
