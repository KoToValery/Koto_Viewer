# Home Screen — Reference & Navigation Map
> **Path**: `lib/src/features/home/home_screen.dart`
> **Primary class**: `_HomeScreenState`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete method/class names with `rg -n`.

## 1. How to use this map

1. Use this map to locate file icon helpers, folder/recent management, file dispatch, or tab layout.
2. Search the current Dart source, for example: `rg -n "_openFileScreen|_buildViewerTab|_tabController" lib/src/features/home/home_screen.dart`.
3. Inspect the target handler and neighboring UI controls before changing navigation, folder picking, or tab structure.

## 2. Key classes, tabs & handlers

| Area | Concrete symbols | Responsibility |
| --- | --- | --- |
| File icons | `FileTypeIcon` | File format icon and badge widgets (`_buildCsvIcon`, `_buildImageIcon`, etc.) |
| Screen & lifecycle | `HomeScreen`, `_HomeScreenState`, `initState`, `dispose`, `_onRecentFilesChanged` | Main home screen state and recent files listener |
| Discovery & folders | `_loadFiles`, `_recomputeCategoryCounts`, `_updateFilteredFiles`, `_switchMode`, `_selectCustomFolder`, `_pickCustomFolder`, `_confirmRemoveCustomFolder`, `_showRenameFolderDialog` | Folder scanning, filtering, custom folder management |
| File actions & dialogs | `_pickAndOpenFile`, `_openFileScreen`, `_showReceiveFilesDialog`, `_removeRecentFile`, `_deleteLocalFile`, `_clearAllRecent`, `_showAboutDialog`, `_showCoordinateSettings` | Opening files into target viewers, WiFi receive, recent/file deletion, settings |
| Tabs & layout | `_tabController`, `_buildViewerTab`, `ArchitectStudioTab`, `StructuralStudioTab`, `build` | 3-tab shell: AIO Viewer, Architect Studio, Construction BIM |
