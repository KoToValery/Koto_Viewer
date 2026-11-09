# Home Screen — LLM Semantic Navigation Map
> **Path**: `lib/src/features/home/home_screen.dart`  
> **Total Lines**: ~3,268 | **Primary Class**: `_HomeScreenState`  
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
| `[SEC-00-IMPORTS]` | `[TAG:HOME_IMPORTS]` | L1 – L28 | Package imports, tabs, viewers, localization extensions |
| `[SEC-01-ICONS]` | `[TAG:HOME_ICONS]` | L39 – L1635 | `FileTypeIcon`, badge decorations, file format helpers |
| `[SEC-02-WIDGET]` | `[TAG:HOME_WIDGET]` | L1636 – L1655 | `HomeScreen` StatefulWidget declaration |
| `[SEC-03-STATE]` | `[TAG:HOME_STATE]` | L1656 – L1755 | State variables, tab controller, folder scanning, file discovery cache |
| `[SEC-04-FOLDERS]` | `[TAG:HOME_FOLDERS]` | L1756 – L2052 | Directory picker, recent folders list, storage permissions |
| `[SEC-05-ACTIONS]` | `[TAG:HOME_ACTIONS]` | L2053 – L2236 | Opening files in viewer (DXF, PDF, Image, Architect, Structural) |
| `[SEC-06-DIALOGS]` | `[TAG:HOME_DIALOGS]` | L2237 – L2265 | Settings, coordinate system & about screen dialogs |
| `[SEC-07-HEADER]` | `[TAG:HOME_HEADER]` | L2266 – L2780 | Search bar, category filters, quick action buttons |
| `[SEC-08-BUILD]` | `[TAG:HOME_BUILD]` | L2781 – L3268 | 3-Tab Shell (AIO Viewer, Architect Studio, Construction BIM) |

---

## 3. Key Navigation & Viewer Dispatch Matrix

| Target Module / Format | Routing / Tab | Target View / Screen |
| :--- | :--- | :--- |
| **AIO Viewer Tab** | Tab 0 (`_tabController`) | File browser, search, recent files |
| **Architect Studio Tab** | Tab 1 (`_tabController`) | `ArchitectStudioTab` -> `ArchitectWorkspaceScreen` |
| **Construction BIM Tab** | Tab 2 (`_tabController`) | `StructuralStudioTab` -> `BimWorkspaceScreen` / `BimAlignmentScreen` |
| **DXF / DWG** | `_openDxfFile` | `DxfViewerScreen` |
| **PDF** | `_openPdfFile` | `PdfViewerScreen` |
| **Images** | `_openImageFile` | `ImageViewerScreen` |
| **Docx** | `_openDocxFile` | `DocxViewerScreen` |
| **3D / IFC / STEP** | `_open3DFile` | `Dxf3DViewerScreen` |
| **Local WiFi Receive**| `_showLocalNetworkReceiveDialog` | `LocalNetworkReceiveDialog` |
