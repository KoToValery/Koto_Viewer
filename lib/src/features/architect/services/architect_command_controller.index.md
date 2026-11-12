# Architect Command Controller — Reference & Navigation Map
> **Path**: `lib/src/features/architect/services/architect_command_controller.dart`
> **Primary class**: `ArchitectCommandController`
> **Important**: Header TOC tags in this file are topic labels except where an anchor exists in the body (`[SEC-01-BASE]`, `[TAG:CMD_LANDSCAPE]`). Treat this map as a discovery aid and search concrete command class names with `rg -n`.

## 1. How to use this map

1. Use this map to identify the closest existing `ArchitectModelCommand` for your mutation.
2. Search the current Dart source, for example: `rg -n "class SplitArchitectWall|class MoveArchitectElements|class ArchitectCommandController" lib/src/features/architect/services/architect_command_controller.dart`.
3. Inspect both the command class (`execute` / `undo`) and its callers in `architect_workspace_screen.dart` to match undo/redo and persistence behavior.

## 2. Key command categories & concrete classes

| Domain | Concrete command / controller symbols | Responsibility |
| --- | --- | --- |
| Command base | `ArchitectModelCommand` (`[SEC-01-BASE]`) | Base undoable command interface (`execute`, `undo`) |
| Wall mutations | `CreateArchitectWall`, `SplitArchitectWall`, `CutArchitectWalls`, `TrimArchitectWall` | Wall creation, splitting, cutting, trimming, and junctions |
| Wall contacts | `AttachArchitectWalls`, `SetArchitectWallConnection`, `ArchitectWallConnectionPolicy.afterMove` | Contact-only attachment and persisted temporary Detach; no endpoint relocation |
| Move / transform | `MoveArchitectElements` | Element translation with topology/room sync |
| Roofs | `CreateArchitectRoofPlane` | Roof plane creation, updates, and deletion |
| Polygon / vertex editing | `InsertArchitectElementPoint` | Polygon edge insertion, vertex dragging, hole updates |
| Multi-storey & landscape | `CopyArchitectElementsAcrossStoreys`, `UpdateArchitectLandscapeProject` (`[TAG:CMD_LANDSCAPE]`) | Cross-storey copy and landscape project updates |
| Controller stack | `ArchitectCommandController` | Undo/redo stack management (`undo()`, `redo()`) |
