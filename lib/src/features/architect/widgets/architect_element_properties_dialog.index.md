# Architect Element Properties Dialog — Reference & Navigation Map
> **Path**: `lib/src/features/architect/widgets/architect_element_properties_dialog.dart`  
> **Primary class**: `_ArchitectElementPropertiesDialogState` (+1 more)  
> **Important**: Treat this map as a discovery aid, not a specification. Verify concrete symbols, anchors, and behavior in the current source with `rg -n`.

---

## 1. How to use this map

1. Use this map to find the relevant section tag, class, or method name.
2. Search the current Dart source with `rg -n "\[TAG:<NAME>\]|<SymbolName>" lib/src/features/architect/widgets/architect_element_properties_dialog.dart`.
3. For behavior changes, read the target implementation and its immediate callers/callees; follow the Reference-First protocol in `AGENTS.md` / `GEMINI.md`.

---

## 2. Source section registry

| Section ID | Tag | Description & Primary Responsibilities |
| :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:ARCH_PROPS_IMPORTS]` | Package, model, service, and widget imports |
| `[SEC-01-WIDGET]` | `[TAG:ARCH_PROPS_WIDGET]` | Declarations: `ArchitectElementPropertiesDialog` |
| `[SEC-02-STATE]` | `[TAG:ARCH_PROPS_STATE]` | `_ArchitectElementPropertiesDialogState` state fields (45 fields: `values`, `texts`, `panelPlacement`, `_lineStyle`, `_hatchPattern`) |
| `[SEC-03-LIFECYCL]` | `[TAG:ARCH_PROPS_STATE_LIFECYCLE]` | Lifecycle & Initialization: `initState`, `label`, `reference`, `metric` (5 methods) |
| `[SEC-04-ZONES]` | `[TAG:ARCH_PROPS_ZONE_ROOMS]` | Zones, Rooms & Area Schedules: `_zoneNumberAndNameFields`, `_zoneMetricsBanner`, `_zoneCategoryField`, `fieldValue` (4 methods) |
| `[SEC-05-ZONES]` | `[TAG:ARCH_PROPS_ZONE_FINISH]` | Zones, Rooms & Area Schedules: `_zoneFinishField`, `numberField`, `materialField`, `_zoneBoundaryModeSwitch` (7 methods) |
| `[SEC-06-CORE]` | `[TAG:ARCH_PROPS_CORE_LOGIC]` | Core Operations & Helpers: `_candidate`, `_save`, `_textField`, `_wallType` (9 methods) |
| `[SEC-07-CORE]` | `[TAG:ARCH_PROPS_TEXT_FIELDS]` | Core Operations & Helpers: `_textFields`, `_levelFields`, `_title` (3 methods) |
| `[SEC-08-BUILD]` | `[TAG:ARCH_PROPS_BUILD_LAYOUT]` | Widget Build & HUD Layout: `build` (1 methods) |

---

## 3. Classes, Enums & Top-Level Declarations

| Symbol | Kind | Members | Signature / Heritage |
| :--- | :--- | :--- | :--- |
| `ArchitectElementPropertiesDialog` | class | 15 | `class ArchitectElementPropertiesDialog extends StatefulWidget` |
| `_ArchitectElementPropertiesDialogState` | class | 74 | `class _ArchitectElementPropertiesDialogState` |

---

## 4. Method & Action Directory (38 methods indexed)

| Method / Handler | Class | Section Tag | Summary / Signature |
| :--- | :--- | :--- | :--- |
| `Function` | `ArchitectElementPropertiesDialog` | `[TAG:ARCH_PROPS_WIDGET]` | final bool Function(ArchitectProject)? onApplyProject |
| `Function` | `ArchitectElementPropertiesDialog` | `[TAG:ARCH_PROPS_WIDGET]` | final void Function(ArchitectProject?)? onPreview |
| `Function` | `ArchitectElementPropertiesDialog` | `[TAG:ARCH_PROPS_WIDGET]` | final ArchitectProject Function(ArchitectProject)? prepare |
| `Function` | `ArchitectElementPropertiesDialog` | `[TAG:ARCH_PROPS_WIDGET]` | final bool Function()? isCurrent |
| `Function` | `ArchitectElementPropertiesDialog` | `[TAG:ARCH_PROPS_WIDGET]` | final void Function(Map<String, double>, Map<String, String>)? onWallLayers |
| `Function` | `ArchitectElementPropertiesDialog` | `[TAG:ARCH_PROPS_WIDGET]` | final bool Function(Map<String, double>, Map<String, String>)? onStraighten |
| `Function` | `ArchitectElementPropertiesDialog` | `[TAG:ARCH_PROPS_WIDGET]` | final bool Function(Map<String, double>, Map<String, String>) onApply |
| `ArchitectElementPropertiesDialog` | `ArchitectElementPropertiesDialog` | `[TAG:ARCH_PROPS_WIDGET]` | const ArchitectElementPropertiesDialog({ super.key, required this.project,  |
| `createState` | `ArchitectElementPropertiesDialog` | `[TAG:ARCH_PROPS_WIDGET]` | State<ArchitectElementPropertiesDialog> createState() |
| `updatePanelPlacement` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_STATE_LIFECYCLE]` | void updatePanelPlacement(Map<String, dynamic> patch) |
| `reference` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_STATE_LIFECYCLE]` | String reference(Map<String, dynamic> record) => switch (record['']) |
| `initState` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_STATE_LIFECYCLE]` | void initState() |
| `label` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_STATE_LIFECYCLE]` | String label(String key) |
| `metric` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_STATE_LIFECYCLE]` | bool metric(String key) => ! |
| `fieldValue` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_ZONE_ROOMS]` | double? fieldValue(String key) |
| `_zoneMetricsBanner` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_ZONE_ROOMS]` | Widget _zoneMetricsBanner( ArchitectZone zone, AppLocalizations l, ) |
| `_zoneCategoryField` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_ZONE_ROOMS]` | Widget _zoneCategoryField(AppLocalizations l) |
| `_zoneNumberAndNameFields` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_ZONE_ROOMS]` | Widget _zoneNumberAndNameFields(AppLocalizations l) |
| `_zoneFinishField` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_ZONE_FINISH]` | Widget _zoneFinishField(String key, String label, List<String> presets) |
| `_zoneBoundaryModeSwitch` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_ZONE_FINISH]` | Widget _zoneBoundaryModeSwitch(AppLocalizations l) |
| `numberField` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_ZONE_FINISH]` | Widget numberField(String key, bool walls) |
| `materialField` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_ZONE_FINISH]` | Widget materialField(String key) |
| `_initialText` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_ZONE_FINISH]` | String _initialText(String key) |
| `_common` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_ZONE_FINISH]` | Object? _common(String key) |
| `setState` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_ZONE_FINISH]` | void setState(VoidCallback fn) |
| `_candidate` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_CORE_LOGIC]` | ArchitectProject _candidate() |
| `_preview` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_CORE_LOGIC]` | bool _preview( |
| `_save` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_CORE_LOGIC]` | void _save() |
| `dispose` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_CORE_LOGIC]` | void dispose() |
| `_textField` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_CORE_LOGIC]` | Widget _textField(String key, String label) |
| `_scroll` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_CORE_LOGIC]` | Widget _scroll(List<Widget> children) |
| `_wallType` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_CORE_LOGIC]` | ArchitectWallType _wallType() |
| `_pickType` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_CORE_LOGIC]` | Future<void> _pickType() async |
| `_choice` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_CORE_LOGIC]` | Widget _choice(String key, String label, Map<String, String> options) |
| `_textFields` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_TEXT_FIELDS]` | List<Widget> _textFields(AppLocalizations l) |
| `_levelFields` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_TEXT_FIELDS]` | List<Widget> _levelFields(AppLocalizations l) |
| `_title` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_TEXT_FIELDS]` | String _title(AppLocalizations l) |
| `build` | `_ArchitectElementPropertiesDialogState` | `[TAG:ARCH_PROPS_BUILD_LAYOUT]` | Widget build(BuildContext context) |

---

## 5. Key State Fields & Controllers Registry (51 fields)

- `viewKey` (`String?`)
- `drawingScale` (`int?`)
- `project` (`ArchitectProject`)
- `elementIds` (`Set<String>`)
- `onSlabLayers` (`VoidCallback?`)
- `onScheduleTable` (`VoidCallback?`)
- `values` (`var`)
- `texts` (`var`)
- `panelPlacement` (`Map<String, dynamic>`)
- `_lineStyle` (`ArchitectLineStyle?`)
- `_hatchPattern` (`ArchitectHatchPattern?`)
- `_hatchColor` (`ArchitectDrawingColor?`)
- `_hatchBorder` (`bool?`)
- `_preserveDimensionsOnStyleChange` (`bool`)
- `_preserveWallPosition` (`bool`)
- `_supportsHatch` (`bool`)
- `_supportsLineStyle` (`bool`)
- `fields` (`Map<String, double?>`)
- `records` (`List<Map<String, dynamic>>`)
- `isSlopedWall` (`bool`)
- `followsHeight` (`bool`)
- `normalWalls` (`bool`)
- `_form` (`var`)
- `_shell` (`var`)
- `_compositionHandle` (`var`)
- `_initialTexts` (`Map<String, String>`)
- `_timer` (`Timer?`)
- `_tab` (`int`)
- `_typeVersion` (`int`)
- `_error` (`String?`)
- `_composition` (`ArchitectWallType?`)
- `_region` (`ArchitectWallPlinthPatch?`)
- `_compositionChanged` (`bool`)
- `_flipMixed` (`bool`)
- `_session` (`var`)
- `_draft` (`ArchitectProject`)
- `_cleared` (`var`)
- `_textControllers` (`var`)
- `_patch` (`Map<String, String>`)
- `_inputDirty` (`bool`)
- `_dirty` (`bool`)
- `_isText` (`bool`)
- `_isLevel` (`bool`)
- `_projectLevelUnits` (`ArchitectUnit?`)
- `_projectLevelDecimals` (`int?`)
- *+6 additional fields in source*
