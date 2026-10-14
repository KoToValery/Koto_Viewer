# Общ BIM редактор

Architect и Construction използват това ядро за еквивалентните механизми на
редакция. Native моделите, файловете и домейн правилата остават отделни.
Редакция в единия режим не променя документа на другия.

## Къде да правим следващата корекция

| Поведение | Единствена обща реализация |
|---|---|
| Координати, точност, CAD конверсия | `geometry/bim_coordinate_frame.dart` |
| Touch offset, hold, захващане | `interaction/bim_pointer_interaction.dart` |
| Pointer, pan, pinch, trackpad, cancel | `widgets/bim_editing_viewport.dart` |
| Камера в моделни метри / fitted native scene | `interaction/bim_viewport_controller.dart`, `bim_transform_navigation.dart` |
| Preview, stale context, еднократно finish | `interaction/bim_edit_session.dart` |
| Move и Drag+ | `interaction/bim_drag_session.dart` |
| Undo, Redo, atomic batch, semantic no-op | `commands/bim_edit_history.dart` |
| Snap приоритети, радиус, deterministic tie | `snapping/bim_snap_resolver.dart` |
| Spatial point/edge/circle кандидати | `scene/bim_point_index.dart`, `bim_bounds_index.dart` |
| Rotate и mirror | `geometry/bim_transform_2d.dart` |
| Оси, naming, alignment, canvas-side offset | `geometry/bim_grid_axis.dart`, `bim_project_grid_axes.dart`, `operations/bim_axis_operations.dart`, `bim_axis_naming.dart` |
| Контур, върхове, ръбове, изнесени дръжки | `interaction/bim_polygon_editor.dart`, `geometry/bim_polygon_geometry.dart` |
| Explicit legacy/import repair, extend, merge | `geometry/bim_contour_repair.dart` |
| Draft cleanup, orthogonal guides, squarify, whole-boundary offset | `geometry/bim_contour_drafting_geometry.dart` |
| Line projection/intersection и hosted fit | `geometry/bim_line_geometry.dart` |
| Visible measurement segment и closest edge за New point | `geometry/bim_line_geometry.dart` |
| Общи действия, keypad, numeric validation, compact offset | `widgets/`, `properties/` |
| Touch anchor, snap marks, ghost, dimension badge | `rendering/bim_pointer_marks.dart` |

Старите публични имена като `ArchitectViewport`, `ArchitectPolygonEditor`,
`StructuralGridAxis` и старият път на coordinate frame са compatibility
facades/aliases. Те не са място за второ копие на алгоритъма.
`ArchitectZoneGeometry` също е alias към общите contour drafting extensions;
draft cleanup пази origin и се избира отделно от imported stray-origin repair.

## Договор за нов елемент

1. Добавете typed adapter в native режима. Използвайте `BimElementRef` с документ,
   етаж, element ID и при нужда hosted part ID. Изложете snapshot и capabilities.
2. Използвайте моделни метри за операции. Native CAD конверсията е в адаптера;
   translation е вектор, без закръгляне или round-trip през далечен origin.
3. Запазвайте неизвестните за операцията native свойства чрез `copyWith`.
   Construction column `height` е размер в план; Architect column `height`
   е вертикална височина. Адаптерът трябва да уважава тази разлика.
4. Създайте сесия от оригинала. Всяко движение изчислява preview от този оригинал.
   Clone IDs за Drag+ се създават веднъж; hosted children получават собствени IDs
   и правилен parent ID. Preview не пише проектен файл.
5. Проверете домейн валидността преди publish. При cancel, сменен документ/етаж/
   инструмент и no-op не записвайте операция. Реална операция има едно Undo.
6. Snap provider връща точни native кандидати към общия resolver; UI радиусът се
   преобразува в моделни метри. Cache се сменя с immutable revision и unit frame.
7. Еквивалентните числови панели и действия ползват общите widgets и rules.
   Всички UI думи и tooltips се добавят в ARB за всички поддържани езици.
8. Добавете тест на договора и реален native interaction сценарий, когато
   промяната засяга release, cancel, Undo, units или hosted dependencies.

## Граници на ядрото

Ядрото може да зависи от Dart, Flutter и общата localization инфраструктура.
То не импортира Architect, Construction, DXF модели, екрани или анализи.
`bim_module_boundaries_test.dart` проверява това ограничение и независимия запис
на `architectural.json` и `structural.json`, включително еднакви element IDs.

Native hosts управляват wall layers/joints/support relations, structural slab
ownership/contacts/linked offsets, staircase rules, analysis, persistence и
специфичните property schemas. Това са различни домейн операции, които използват
общата геометрия. Не ги заменяйте с универсално пресъздаване на native модел.

Architect публикува команди чрез `BimTransactionController`. Construction използва
staged history bridge: baseline преди операцията, publish при приета промяна и
save, cancel при отказ. Slab correction има вътрешни стъпки за преглед до Save;
те остават native workflow и се обединяват в една финална Undo операция.
Semantic JSON comparison е допустим при commit; не е за pointer/snap/render loops.

Native scene painters запазват материалите и специфичното представяне.
Construction fitted scene използва `BimTransformRenderer`, който само рисува
трансформацията. `BimEditingViewport` е единственият собственик на жестовете;
не добавяйте втори InteractiveViewer или native multi-touch recognizer около него.

## Проверки

Изпълнете `flutter test --no-pub test/features/bim_editing` и съответните native
interaction тестове. При по-голяма промяна включете `test/features/architect`,
`test/features/structural_designer`, `test/features/bim_projects` и основните
`test/bim_*`, `test/structural_*`, `test/slab_*` серии. Анализирайте засегнатите
модули. Дневникът и изходният план са в `docs/bim_shared_editing_execution.md`
и `docs/bim_shared_editing_engine_plan_2026_10_13.md`.
