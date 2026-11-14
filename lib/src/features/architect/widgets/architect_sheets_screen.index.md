# Architect Sheets Screen — Reference & Navigation Map
> **Path**: `lib/src/features/architect/widgets/architect_sheets_screen.dart`  
> **Primary class**: `_SheetsState` (+9 more)  
> **Important**: Treat this map as a discovery aid, not a specification. Verify concrete symbols, anchors, and behavior in the current source with `rg -n`.

---

## 1. How to use this map

1. Use this map to find the relevant section tag, class, or method name.
2. Search the current Dart source with `rg -n "\[TAG:<NAME>\]|<SymbolName>" lib/src/features/architect/widgets/architect_sheets_screen.dart`.
3. For behavior changes, read the target implementation and its immediate callers/callees; follow the Reference-First protocol in `AGENTS.md` / `GEMINI.md`.

---

## 2. Source section registry

| Section ID | Tag | Description & Primary Responsibilities |
| :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:ARCH_SHEETS_IMPORTS]` | Package, model, service, and widget imports |
| `[SEC-01-WIDGET]` | `[TAG:ARCH_SHEETS_WIDGET]` | Declarations: `_paperFormat`, `_paperNumber`, `_id`, `_parse` (+1 more) |
| `[SEC-02-STATE]` | `[TAG:ARCH_SHEETS_STATE]` | `_SheetsState` state fields (16 fields: `selected`, `pendingPlacement`, `pendingDrawing`, `cropMode`, `busy`) |
| `[SEC-03-CORE]` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | Core Operations & Helpers: `_sourceOptions`, `fitView`, `checkLayout`, `fitPlacement` (13 methods) |
| `[SEC-04-COMMITS]` | `[TAG:ARCH_SHEETS_COMMIT_HANDLERS]` | Placement & Geometry Commit Handlers: `placeView`, `template`, `placementProperties`, `placePending` (7 methods) |
| `[SEC-05-CORE]` | `[TAG:ARCH_SHEETS_OUTPUT]` | Core Operations & Helpers: `output`, `visibility`, `renameDrawing` (3 methods) |
| `[SEC-06-BUILD]` | `[TAG:ARCH_SHEETS_BUILD_LAYOUT]` | Widget Build & HUD Layout: `build` (1 methods) |
| `[SEC-07-WIDGET]` | `[TAG:ARCH_SHEETS_WIDGET_2]` | Declarations: `_SheetDialog`, `_SheetDialogState`, `_PlacementDialog`, `_PlacementDialogState` (+4 more) |
| `[SEC-08-MODELS]` | `[TAG:ARCH_SHEETS_TEMPLATE]` | Declarations: `_TemplateDialogState`, `_fieldLabel` |

---

## 3. Classes, Enums & Top-Level Declarations

| Symbol | Kind | Members | Signature / Heritage |
| :--- | :--- | :--- | :--- |
| `_paperFormat` | function | 0 | `String _paperFormat(double width, double height)` |
| `_paperNumber` | function | 0 | `String _paperNumber(double value)` |
| `_id` | function | 0 | `String _id() => DateTime.now().microsecondsSinceEpoch.toString();` |
| `_parse` | function | 0 | `double? _parse(String text) =>` |
| `ArchitectSheetsScreen` | class | 4 | `class ArchitectSheetsScreen extends StatefulWidget` |
| `_SheetsState` | class | 40 | `class _SheetsState extends State<ArchitectSheetsScreen>` |
| `_SheetDialog` | class | 3 | `class _SheetDialog extends StatefulWidget` |
| `_SheetDialogState` | class | 4 | `class _SheetDialogState extends State<_SheetDialog>` |
| `_PlacementDialog` | class | 5 | `class _PlacementDialog extends StatefulWidget` |
| `_PlacementDialogState` | class | 8 | `class _PlacementDialogState extends State<_PlacementDialog>` |
| `_scaleInput` | function | 0 | `Widget _scaleInput(BuildContext context, TextEditingController controller)` |
| `_ScaleDialog` | class | 3 | `class _ScaleDialog extends StatefulWidget` |
| `_ScaleDialogState` | class | 4 | `class _ScaleDialogState extends State<_ScaleDialog>` |
| `_TemplateDialog` | class | 3 | `class _TemplateDialog extends StatefulWidget` |
| `_TemplateDialogState` | class | 5 | `class _TemplateDialogState extends State<_TemplateDialog>` |
| `_fieldLabel` | function | 0 | `String _fieldLabel(AppLocalizations l, ArchitectTitleField f) => switch (f)` |

---

## 4. Method & Action Directory (49 methods indexed)

| Method / Handler | Class | Section Tag | Summary / Signature |
| :--- | :--- | :--- | :--- |
| `_paperFormat` | `(top-level)` | `[TAG:ARCH_SHEETS_WIDGET]` | String _paperFormat(double width, double height) |
| `_paperNumber` | `(top-level)` | `[TAG:ARCH_SHEETS_WIDGET]` | String _paperNumber(double value) |
| `_id` | `(top-level)` | `[TAG:ARCH_SHEETS_WIDGET]` | String _id() => DateTime.now().microsecondsSinceEpoch.toString(); |
| `_parse` | `(top-level)` | `[TAG:ARCH_SHEETS_WIDGET]` | double? _parse(String text) => |
| `ArchitectSheetsScreen` | `ArchitectSheetsScreen` | `[TAG:ARCH_SHEETS_WIDGET]` | const ArchitectSheetsScreen({ super.key, required this.controller, this.sou |
| `createState` | `ArchitectSheetsScreen` | `[TAG:ARCH_SHEETS_WIDGET]` | State<ArchitectSheetsScreen> createState() |
| `layoutIssues` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | List<String> layoutIssues(ArchitectSheet value, AppLocalizations l) |
| `exchange` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | Future<void> exchange(ArchitectExchangeFormat format) |
| `fitSheet` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | void fitSheet() |
| `cancelEdit` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | void cancelEdit() |
| `message` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | void message(String value) |
| `checkLayout` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | Future<void> checkLayout() async |
| `fitPlacement` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | ArchitectDrawingPlacement? fitPlacement( ArchitectDrawingPlacement place, R |
| `fitView` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | void fitView() |
| `commit` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | void commit(ArchitectDocument next) |
| `saveSheet` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | void saveSheet(ArchitectSheet value) |
| `savePlacement` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | void savePlacement(ArchitectDrawingPlacement value) |
| `sheetProperties` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | Future<void> sheetProperties( |
| `_sourceOptions` | `_SheetsState` | `[TAG:ARCH_SHEETS_CORE_LOGIC]` | List<ArchitectSavedDrawing> _sourceOptions() |
| `placeView` | `_SheetsState` | `[TAG:ARCH_SHEETS_COMMIT_HANDLERS]` | Future<void> placeView() async |
| `placePending` | `_SheetsState` | `[TAG:ARCH_SHEETS_COMMIT_HANDLERS]` | void placePending(ArchitectDrawingPlacement place) |
| `placementProperties` | `_SheetsState` | `[TAG:ARCH_SHEETS_COMMIT_HANDLERS]` | Future<void> placementProperties() async |
| `duplicate` | `_SheetsState` | `[TAG:ARCH_SHEETS_COMMIT_HANDLERS]` | void duplicate() |
| `changeScale` | `_SheetsState` | `[TAG:ARCH_SHEETS_COMMIT_HANDLERS]` | Future<void> changeScale() async |
| `align` | `_SheetsState` | `[TAG:ARCH_SHEETS_COMMIT_HANDLERS]` | void align(String side) |
| `template` | `_SheetsState` | `[TAG:ARCH_SHEETS_COMMIT_HANDLERS]` | Future<void> template() async |
| `renameDrawing` | `_SheetsState` | `[TAG:ARCH_SHEETS_OUTPUT]` | Future<void> renameDrawing() async |
| `visibility` | `_SheetsState` | `[TAG:ARCH_SHEETS_OUTPUT]` | Future<void> visibility() async |
| `output` | `_SheetsState` | `[TAG:ARCH_SHEETS_OUTPUT]` | Future<void> output( |
| `build` | `_SheetsState` | `[TAG:ARCH_SHEETS_BUILD_LAYOUT]` | Widget build(BuildContext context) |
| `_SheetDialog` | `_SheetDialog` | `[TAG:ARCH_SHEETS_WIDGET_2]` | const _SheetDialog(this.initial) |
| `createState` | `_SheetDialog` | `[TAG:ARCH_SHEETS_WIDGET_2]` | State<_SheetDialog> createState() |
| `dispose` | `_SheetDialogState` | `[TAG:ARCH_SHEETS_WIDGET_2]` | void dispose() |
| `build` | `_SheetDialogState` | `[TAG:ARCH_SHEETS_WIDGET_2]` | Widget build(BuildContext context) |
| `_PlacementDialog` | `_PlacementDialog` | `[TAG:ARCH_SHEETS_WIDGET_2]` | const _PlacementDialog(this.initial, this.drawings, this.units) |
| `createState` | `_PlacementDialog` | `[TAG:ARCH_SHEETS_WIDGET_2]` | State<_PlacementDialog> createState() |
| `dispose` | `_PlacementDialogState` | `[TAG:ARCH_SHEETS_WIDGET_2]` | void dispose() |
| `build` | `_PlacementDialogState` | `[TAG:ARCH_SHEETS_WIDGET_2]` | Widget build(BuildContext context) |
| `_scaleInput` | `(top-level)` | `[TAG:ARCH_SHEETS_WIDGET_2]` | Widget _scaleInput(BuildContext context, TextEditingController controller) |
| `_ScaleDialog` | `_ScaleDialog` | `[TAG:ARCH_SHEETS_WIDGET_2]` | const _ScaleDialog(this.initial) |
| `createState` | `_ScaleDialog` | `[TAG:ARCH_SHEETS_WIDGET_2]` | State<_ScaleDialog> createState() |
| `dispose` | `_ScaleDialogState` | `[TAG:ARCH_SHEETS_WIDGET_2]` | void dispose() |
| `build` | `_ScaleDialogState` | `[TAG:ARCH_SHEETS_WIDGET_2]` | Widget build(BuildContext context) |
| `_TemplateDialog` | `_TemplateDialog` | `[TAG:ARCH_SHEETS_WIDGET_2]` | const _TemplateDialog(this.initial) |
| `createState` | `_TemplateDialog` | `[TAG:ARCH_SHEETS_WIDGET_2]` | State<_TemplateDialog> createState() |
| `dispose` | `_TemplateDialogState` | `[TAG:ARCH_SHEETS_TEMPLATE]` | void dispose() |
| `edit` | `_TemplateDialogState` | `[TAG:ARCH_SHEETS_TEMPLATE]` | Future<void> edit(ArchitectTitleItem item) async |
| `build` | `_TemplateDialogState` | `[TAG:ARCH_SHEETS_TEMPLATE]` | Widget build(BuildContext context) |
| `_fieldLabel` | `(top-level)` | `[TAG:ARCH_SHEETS_TEMPLATE]` | String _fieldLabel(AppLocalizations l, ArchitectTitleField f) => switch (f) |

---

## 5. Key State Fields & Controllers Registry (36 fields)

- `controller` (`ArchitectCommandController`)
- `sources` (`ArchitectPublicationSources`)
- `selected` (`String? sheetId,`)
- `pendingPlacement` (`ArchitectDrawingPlacement?`)
- `pendingDrawing` (`ArchitectSavedDrawing?`)
- `cropMode` (`bool`)
- `busy` (`bool`)
- `viewportKey` (`var`)
- `drawingScenes` (`var`)
- `sceneRevision` (`Object?`)
- `sceneLabels` (`AppLocalizations?`)
- `sceneSources` (`ArchitectPublicationSources?`)
- `preflightRevision` (`Object?`)
- `preflightIssues` (`List<String>`)
- `project` (`ArchitectProject`)
- `document` (`ArchitectDocument`)
- `sheet` (`ArchitectSheet?`)
- `placement` (`ArchitectDrawingPlacement?`)
- `initial` (`ArchitectSheet`)
- `values` (`var`)
- `invalid` (`bool`)
- `initial` (`ArchitectDrawingPlacement`)
- `drawings` (`List<ArchitectSavedDrawing>`)
- `units` (`ArchitectUnit`)
- `original` (`var`)
- `fields` (`var`)
- `scaleField` (`var`)
- `source` (`String?`)
- `title` (`bool`)
- `invalid` (`bool`)
- `initial` (`int`)
- `controller` (`var`)
- `invalid` (`bool`)
- `initial` (`ArchitectSheetTemplate`)
- `name` (`var`)
- `items` (`List<ArchitectTitleItem>`)
