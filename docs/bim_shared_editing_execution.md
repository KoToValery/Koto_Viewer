# Изпълнение на общия BIM редактор

План: [bim_shared_editing_engine_plan_2026_10_13.md](bim_shared_editing_engine_plan_2026_10_13.md).
Обхват: общ механизъм, отделни модели и файлове за Architect и Construction.

| Етап | Състояние | Проверка / резултат |
|---|---|---|
| 0. Договор и baseline | Завършен | Поправено застъпване на polygon-edit-close и architect-magnet на телефон. Началната серия: 110 успешни теста. |
| 1. Координатна и адаптерна основа | Завършен | Общи координати/pointer правила, идентичност и неизменни снимки. Native адаптери са включени в Architect move и Construction Drag+. 75 успешни теста. |
| 2. Сесии и транзакции | Завършена основа и bridge | Architect използва общи атомарни транзакции; Construction Undo използва общата история. Move и Drag+ са включени в общите сесии. 45 успешни теста. |
| 3. Общ viewport | Завършен | Един BimEditingViewport за двата режима, два camera adapters. 36 успешни теста; чист анализ. |
| 4. Общ snap и scene index | Завършена основа и native providers | Обща bounded/deterministic selection и metre point/bounds indices. Съществуващи серии: 54 и 45 успешни теста. |
| 5. Оси — пълен пилот | Завършен | Общ axis model/geometry/naming/extents, canvas-side offset, compact dialog и Construction transactional endpoint/body drag. 34 финални теста. |
| 6. Колони/греди и Drag+ | Предстои | |
| 7. Контури | Предстои | |
| 8. Стени и специални hosts | Предстои | |
| 9. UI и rendering завършване | Предстои | |
| 10. Премахване на остатъците | Предстои | |

## Правила за следващите промени

- Общите операции работят в моделни метри. Конверсията и native свойствата са отговорност на адаптерите.
- Един собственик на pointer жеста; preview не променя проекта и не записва файл.
- Един commit и едно Undo за реална операция. Cancel и липса на движение не добавят история.
- Извлечена функция се включва в реалните потребители; старите паралелни реализации се премахват поетапно.
- Еквивалентните действия имат общ договор. Архитектурните зависимости и конструктивните проверки остават специфични.
- BG/EN интерфейсът използва ARB. Запазват се кратките менюта и компактният офсет.
- След всяка по-голяма завършена и проверена промяна: отделен commit и push. Паралелни чужди промени не се включват.

## Етап 0

Контурната лента вече има ограничена ширина с отделено място за магнита. Указанието и етикетът за отместване се побират в наличната ширина; двата режима на ръб и затварянето запазват постоянни touch размери.

Начална серия: viewport gestures, workspace core, element snap, polygon editor/distance, radial menu/handles, wall smart edit, Construction compact controls/measurement и BIM frame/alignment. Резултат: 110/110. Провалът от одита вече е отстранен.

## Етап 1

`BimCoordinateFrame` и `BimPrecisionPolicy` са преместени в `bim_editing/geometry`; старият път е compatibility export, без второ копие. `BimPointerInteraction` е единствената реализация на захващане, hold duration, touch offset и capture бюджет; старото Structural име е alias.

Добавени са document-scoped `BimElementRef`, неизменен `BimElementSnapshot` и typed native адаптери. Construction покрива колони, шайби, греди, оси и плочи с отвори; Architect — колони, греди, плочи и зони. Те са основа за последващото разширяване по capabilities, а не замяна на домейн моделите.

Реални потребители: Construction Drag+ и Architect местене на колони/греди/плочи/зони. Векторите се преобразуват без round-trip през далечно начало и без закръгляне на внесените данни. Нулево отместване запазва оригиналния native обект.

Проверки: CAD 1/100/1000, далечен origin, L-форма, rotation/mirror, host/reference настройки, beam secondary, slab holes/types, floor ownership, дебелини/коти/цветове, аналитичен кръг и неизменност на snapshot. Серията с адаптерни и съществуващи interaction тестове: 75/75.

## Етап 2

Извлечени са `BimEditHistory`, `BimTransactionController` и `BimEditSession`. Architect командите публикуват само след успешно завършване на цялата група; семантично еднакви документи и промяна само на timestamp не добавят Undo. Навигацията по етажи запазва Redo и видимия етаж при възстановяване.

Construction използва същата ограничена история през checkpoint bridge към съществуващите native операции. Това не превръща автоматично всички стари handlers в транзакции: те ще се пренасят с елементните етапи. Undo запазва гледания етаж, ако още съществува.

Architect move/wall preview и Construction Drag+ използват обща сесия с документна версия, етаж и инструмент. Preview се получава от оригинала; отказ, стар контекст, повторно потвърждение и Drag+ без преместване не записват операция. Numeric polygon preview остава независим до контурния етап.

Проверки: atomic failure/no-op, лимит на историята, Redo branch, еднократно finish, cancel, контекст, semantic equality и съществуващи реални pointer сценарии в двата режима: 45/45. Статичният анализ на променените екрани, core и тестове е чист.

## Етап 3

`BimEditingViewport` е единствен собственик на pointer/hold/pan/pinch/scroll/trackpad lifecycle. Architect името остава alias. Камерата `BimViewportController` е в общия модул; Construction използва `BimTransformNavigation` към съществуващата fitted scene с CAD Y orientation. Моделите и координатите им не се променят при навигация.

От Construction са премахнати RawGestureDetector, Tap/LongPress recognizers и отделният measurement hold timer. Native handlers получават единствено tool events и адаптирани hold callbacks от общия собственик. InteractiveViewer засега е само transform renderer с изключени pan и scale; ще бъде премахнат в rendering cleanup. Старите native handlers още пазят compatibility flags за последващото си пренасяне.

Проверки: 33 съществуващи сценария (двата екрана, placement, measurement, touch/mouse Drag+, pointer правила) и 3 нови общи camera/pinch контракта. Проверени focal anchoring, scale clamp, invalid scale и повторна работа след отменен жест. Анализът е чист.

## Етап 4

Общи са `BimSnapKind`, `BimSnapResolver`, `BimPointIndex` и `BimBoundsIndex`. Подреждането използва тип, разстояние и координати за deterministic tie; exact object coordinates не се закръглят. Индексите са в моделни метри и обработват големи заявки без обхождане на милиони празни клетки.

Architect geometry provider използва общите индекси за точки, finite edges и аналитични circles. Construction получи revision/unit-scoped cached native scene provider вместо пълно обхождане на всички елементи при всяко движение. Запазени са Construction corner-only колони, slab/opening vertices и ghost references; excluded native IDs се филтрират преди resolver. Advanced wall attachments/alignment и underlay segment extraction остават provider/host extensions до съответните домейн етапи.

Проверки: приоритет независимо от provider order, exact coordinates, anchor exclusion, отрицателни и далечни координати, overflow bounds, cache revision/units. Сериите с реални BIM interaction и snap/ownership сценарии са 54/54 и 45/45; анализът е чист.

## Етап 5

`BimGridAxis` е общата геометрия със старото име StructuralGridAxis като alias. Форматът и отделните project snapshots не се променят. Общи са naming, ProjectGridAxes extent/merge service и BimAxisOperations (alignNew, alignParallel, bounded endpoint resizing, parallel move capture, offset sign/vector). Native storey/underlay и wall-based placement остават адаптери към същите операции.

Construction endpoint и axis-body drag използват BimEditSession: един preview project, без autosave/Undo по време на движение; cancel възстановява оригинала, release публикува веднъж. Запазват се bubble flags и sourceStoreyIds. Наклонени и reversed оси определят offset страна чрез dot с canonical normal. Offset copies използват copyWith вместо нов обект с изгубени настройки.

Диалогът за разстояние е общ BimOffsetDialog, празен, без заглавие, presets и arrows. Architect използва избраната unit scale/symbol, Construction своята native m/cm настройка. Контекстна смяна при активен pointer отменя и native preview.

Проверки: 49 съществуващи workspace/alignment/ownership теста и финална серия 34/34, включително oblique/reversed offset, .30 m minimum, reverse parallel extents, compact Architect dialog и Construction endpoint/body preview/cancel/commit/Undo в 1 и 1000 CAD units/metre. Анализът е чист.
