# Home Screen — LLM Semantic Navigation Map
> **Path**: `lib/src/features/home/home_screen.dart`  
> **Total Lines**: ~3,691 | **Primary Class**: `_HomeScreenState`  
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
| `[SEC-00-IMPORTS]` | `[TAG:HOME_IMPORTS]` | L1 – L26 | Package imports, viewers, localization extensions |
| `[SEC-01-ICONS]` | `[TAG:HOME_ICONS]` | L39 – L1635 | `FileTypeIcon`, badge decorations, file format helpers |
| `[SEC-02-WIDGET]` | `[TAG:HOME_WIDGET]` | L1636 – L1650 | `HomeScreen` StatefulWidget declaration |
| `[SEC-03-STATE]` | `[TAG:HOME_STATE]` | L1651 – L1749 | State variables, folder scanning, file discovery cache |
| `[SEC-04-FOLDERS]` | `[TAG:HOME_FOLDERS]` | L1750 – L2046 | Directory picker, recent folders list, storage permissions |
| `[SEC-05-ACTIONS]` | `[TAG:HOME_ACTIONS]` | L2047 – L2230 | Opening files in viewer (DXF, PDF, Image, Architect, Structural) |
| `[SEC-06-DIALOGS]` | `[TAG:HOME_DIALOGS]` | L2231 – L2572 | Settings dialog, donation modal, about screen, license dialog |
| `[SEC-07-HEADER]` | `[TAG:HOME_HEADER]` | L2573 – L3064 | Search bar, category filters, quick action buttons |
| `[SEC-08-BUILD]` | `[TAG:HOME_BUILD]` | L3065 – L3691 | Main `build()` method, file list/grid view, empty states |

---

## 3. Key Navigation & Viewer Dispatch Matrix

| Target Format | Routing Method | Target Viewer Screen |
| :--- | :--- | :--- |
| **DXF / DWG** | `_openDxfFile` | `DxfViewerScreen` |
| **Architectural BiM** | `_openArchitectWorkspace` | `ArchitectWorkspaceScreen` |
| **Structural BiM** | `_openStructuralDesigner` | `StructuralDesignerScreen` |
| **PDF** | `_openPdfFile` | `PdfViewerScreen` |
| **Images** | `_openImageFile` | `ImageViewerScreen` |
| **Docx** | `_openDocxFile` | `DocxViewerScreen` |
| **3D / IFC / STEP** | `_open3DFile` | `Dxf3DViewerScreen` |
| **Local WiFi Receive**| `_showLocalNetworkReceiveDialog` | `LocalNetworkReceiveDialog` |
