# DXF Viewer Screen — LLM Semantic Navigation Map
> **Path**: `lib/src/features/dxf_viewer/dxf_viewer_screen.dart`  
> **Total Lines**: ~2,555 | **Primary Class**: `_DxfViewerScreenState`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Feature**: Look at Section 2 (Master Section Registry).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target method name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:DXF_IMPORTS]` | L1 – L47 | Flutter widgets, DXF parser, layers, structural designer link |
| `[SEC-01-WIDGET]` | `[TAG:DXF_WIDGET]` | L60 – L84 | `DxfViewerScreen` StatefulWidget & parameters |
| `[SEC-02-STATE]` | `[TAG:DXF_STATE]` | L85 – L524 | State fields, async DXF parsing, layout tabs, canvas transforms |
| `[SEC-03-MEASURE]` | `[TAG:DXF_MEASURE]` | L525 – L834 | Interactive distance measurement, magnetic snap point detector |
| `[SEC-04-ACTIONS]` | `[TAG:DXF_ACTIONS]` | L835 – L1157 | Area calculations, PDF export, screenshot captures, layer toggles |
| `[SEC-05-GESTURES]`| `[TAG:DXF_GESTURES]` | L1158 – L1446| Pan/zoom gestures, mouse wheel scaling, trackpad pinch & hotkeys |
| `[SEC-06-DIALOGS]` | `[TAG:DXF_DIALOGS]` | L1447 – L1730| Layer manager bottom sheet, entity properties dialog, font picker |
| `[SEC-07-HUD]` | `[TAG:DXF_HUD]` | L1731 – L2063| Top app bar, Layout/Model space switcher tabs, zoom extents HUD |
| `[SEC-08-BUILD]` | `[TAG:DXF_BUILD]` | L2064 – L2555| Main `build()` method, interactive canvas viewport with `DxfPainter` |

---

## 3. Key Operations Matrix

| Operation | Method Name | Section Tag |
| :--- | :--- | :--- |
| Parse DXF/DWG file | `_loadFile` | `[TAG:DXF_STATE]` |
| Zoom to Extents | `_zoomToFit` | `[TAG:DXF_STATE]` |
| Switch Layout / Model | `_selectLayout` | `[TAG:DXF_HUD]` |
| Toggle Layer Visibility | `_toggleLayer` | `[TAG:DXF_DIALOGS]` |
| Launch Structural Designer | `_launchStructuralDesigner` | `[TAG:DXF_ACTIONS]` |
| Export to PDF | `_exportPdf` | `[TAG:DXF_ACTIONS]` |
