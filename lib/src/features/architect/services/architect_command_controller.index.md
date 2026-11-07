# Architect Command Controller — LLM Semantic Navigation Map
> **Path**: `lib/src/features/architect/services/architect_command_controller.dart`  
> **Total Lines**: ~2,778 | **Primary Class**: `ArchitectCommandController`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Command Category**: Look at Section 3 (Command Class Registry) or Section 2 (Master Section Registry).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target command class name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:CMD_IMPORTS]` | L1 – L35 | Imports, model dependencies, export statements |
| `[SEC-01-BASE]` | `[TAG:CMD_BASE]` | L36 – L105 | `abstract class ArchitectModelCommand`, base interface & contracts |
| `[SEC-02-GROUPS]` | `[TAG:CMD_GROUPS]` | L106 – L251 | Offset, Group, Ungroup, AddGroupMembers |
| `[SEC-03-WALLS]` | `[TAG:CMD_WALLS]` | L252 – L1023 | Wall creation, update, split, cut, trim, clearances, connections, mirrors |
| `[SEC-04-ELEMENTS]`| `[TAG:CMD_ELEMENTS]` | L1024 – L1066 | Columns, zones, candidate placement |
| `[SEC-05-MOVE]` | `[TAG:CMD_MOVE]` | L1067 – L1639 | `MoveArchitectElement`, `MoveArchitectElements` with room detector sync |
| `[SEC-06-EXTEND]` | `[TAG:CMD_EXTEND]` | L1640 – L1826 | Wall extensions, joints, wall dimension parameters |
| `[SEC-07-CONTOURS]`| `[TAG:CMD_CONTOURS]` | L1827 – L1997 | Contour cuts, CAD primitives (rect, circle, line), polyline updates |
| `[SEC-08-ROOFS]` | `[TAG:CMD_ROOFS]` | L1998 – L2079 | Roof plane creation, pitch updates, storey roof replacement, deletion |
| `[SEC-09-POLYGONS]`| `[TAG:CMD_POLYGONS]` | L2080 – L2450 | Polygon edge insertion, vertex dragging, hole punctures |
| `[SEC-10-CTRL]` | `[TAG:CMD_CONTROLLER]`| L2451 – L2598 | `ArchitectCommandController`: Undo/Redo stack, transaction batching |
| `[SEC-11-VIEWS]` | `[TAG:CMD_VIEWS]` | L2599 – L2726 | Sections, elevations, decorative element commands |
| `[SEC-12-STOREYS]` | `[TAG:CMD_STOREYS]` | L2727 – L2778 | Cross-storey copy, batch storey additions, storey deletion |

---

## 3. Command Class Registry

| Operation | Command Class | Section Tag |
| :--- | :--- | :--- |
| Create Wall | `CreateArchitectWall` | `[TAG:CMD_WALLS]` |
| Split Wall | `SplitArchitectWall` | `[TAG:CMD_WALLS]` |
| Cut Wall | `CutArchitectWalls` | `[TAG:CMD_WALLS]` |
| Trim Wall | `TrimArchitectWall` | `[TAG:CMD_WALLS]` |
| Move Elements | `MoveArchitectElements` | `[TAG:CMD_MOVE]` |
| Create Roof | `CreateArchitectRoofPlane` | `[TAG:CMD_ROOFS]` |
| Vertex Insert | `InsertArchitectElementPoint` | `[TAG:CMD_POLYGONS]` |
| Storey Copy | `CopyArchitectElementsAcrossStoreys` | `[TAG:CMD_STOREYS]` |
| Landscape Update | `UpdateArchitectLandscapeProject` | `[TAG:CMD_STOREYS]` |
| Undo / Redo | `ArchitectCommandController.undo() / redo()` | `[TAG:CMD_CONTROLLER]` |
