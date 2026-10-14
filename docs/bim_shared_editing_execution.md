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
| 6. Колони/греди и Drag+ | Завършен | Общ BimDragSession, native transform adapters, Architect Drag+ и Construction beam move. Серии 52 и 16 успешни теста. |
| 7. Контури | Завършен | Общ BimPolygonEditor/geometry, explicit legacy repair extension, shared outer/hole edge+merge operations. Серии 77 и 53 успешни теста. |
| 8. Стени и специални hosts | Завършен | Common line projections/intersections/host-fit; typed wall/path adapters; wall Drag+ carries independent hosted identities. 112 успешни теста. |
| 9. UI и rendering завършване | Завършен | Общ action catalog/dock control, units, numeric rules/keypads/panels и pointer marks. 148 + 5 успешни теста. |
| 10. Премахване на остатъците | Завършен | Отстранени transform-only InteractiveViewer и дублираните Construction move/release/cancel handlers; zone math е в core. Staged native history, dependency/file-isolation contracts и maintenance guide. Финална серия: 815 успешни теста, 2 пропуснати. |

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

## Етап 6

Move/Drag+ използва `BimDragSession` с model-metre anchor, grab offset, baseline preview и еднократно finish. Construction Drag+ е пренесен към него; Architect Drag+ създава clone project само за preview и превежда само новия element ID през native command adapter. ID се създава веднъж и е стабилен при всички preview движения. Cancel, stale context и no-op не добавят Undo.

Architect column/beam radial actions показват краткия ARB Drag+ и общото указание/cancel. Използва се latest Architect translation snap extension; native underlay providers остават специфични. Construction beam body вече може да се мести с mouse/touch hold през същата сесия, без междинен autosave. При commit/Undo се пазят native beam настройки. Column placement/normal move използват общите pointer правила и native translation адаптери, със съществуващите property panels до UI етапа.

Ротацията е в общ BimTransform2D и typed column/beam adapters. Architect column вече сменя само pose rotation, вместо едновременно dimensions swap + rotation (двойна физическа промяна). Vertical height и local width/depth остават запазени; Construction L profile и mirror flag също.

Проверки: 52/52 core/workspace/compact-control сценария и финални 16/16 с реален Architect Drag+ за column/beam, стабилна identity, preview/cancel/commit/Undo, profile rotation и Construction beam body preview/commit/Undo. Анализът е чист.

## Етап 7

Latest Architect polygon geometry и gesture resolver са в общия модул като BimPolygonGeometry/BimPolygonEditor. Native Architect facade само адаптира snap payload. Construction slab/opening vertex previews вече използват същия editor в метри и неговите resolved polygons на release; feature providers и валидирането на owner/contact topology остават native.

Construction contour repair, dynamic neighbor-preserving extension и merge са общи pure geometry операции. Outer contour и opening извикват една реализация; native copyWith/updateOpening запазват openingTypes и slab properties. Legacy/import cleanup е explicit BimContourRepair policy; нормалните редакции използват strict BimPolygonGeometry. Така import heuristics не се прилагат скрито върху нови Architect контури.

Общи са insert/remove/move vertex и point-in-polygon; stable signedArea работи при далечен origin. Поправена е StructuralSlab.rotate — върти и holes около същия pivot, като пази кота/дебелина/типове/ownership.

Проверки: 77 съществуващи polygon distance/handles/linked-edge/topology сценария, финални 53/53 с actual Construction ownership editing и common/native vertex agreement, outer/opening extension, invalid crossing, hole rotation и area при 1e10 origin. Статичният анализ е чист.

## Етап 8

Общ BimLineGeometry управлява finite/reference projection/intersection и hosted interval fit. Архитектурният wall network и snap, както и Construction hit testing използват него. Typed wall adapters пазят reference line, exterior/insulation, connection flags и embedded openings. Native wall connectivity and wall-layer validation остават след базовата трансформация.

Добавен е generic typed BimPathEditingAdapter за native point/line/contour fields. Architect opening/stair/dimension/annotation/elevation/CAD movement вече използва него вместо отделни point+delta реализации; explicit CAD polygons се превеждат заедно с endpoints. Construction wall rotation използва shared transform adapter.

Architect wall Drag+ копира embedded doors/windows със stable newly generated IDs/UUIDs и нов wallId. Style, ratios и specifications се пазят. Само clone translation bypass-ва старите supports, за да не мести/разтяга оригинала; normal wall moves запазват native connections. Hosted children на преместващите се стени са изключени от self-snap.

Проверки: final 112/112 за wall smart edit, insulation/core, supports/openings, placement, snap, special paths и slab ownership. Новите host тестове проверяват copied child rebinding/identity/properties и source wall immutability. Анализът е чист.

## Етап 9

BimEditAction/BimEditActions са общ action ID/label/icon/capability договор. Architect radial factory и Construction dock използват него; специфичните native действия (opening type, L-profile mirror cycle, wall topology) остават адаптирани. BimActionButton е общият кратък dock control с ARB Drag+ tooltip.

BimDistanceUnit, BimNumericRule, BimNumericKeypad, BimShapeDimensionPanel и BimDistanceDraftingPanel са единствени реализации. Старите Architect имена са alias-и. Construction offset/linked slab offset и Architect local panels използват общото finite parsing/validation. Native property catalogs пазят различните 2D/vertical semantics и localized field labels.

Touch anchor/stem, snap glyphs, ghost contour и dimension badges са в BimPointerMarks. Native painter подава screen-space geometry, localized dimension text и специфичните previews; същите marks обслужват двата BIM режима.

Проверки: 148/148 interaction/phone/pointer/core сценария и 5/5 unit serialization, display/model bounds, integer/nonfinite input, BG/EN action ARB и read-only capability проверки. Анализът е чист. Не са добавяни hardcoded product UI думи; common labels използват съществуващите ARB messages.

## Етап 10

Construction използва BimTransformRenderer за fitted scene; InteractiveViewer,
старият pointer counter и multi-touch flag са премахнати. BimEditingViewport
управлява навигацията и lifecycle. Native tool input има един move/release/cancel
път за мишка и touch hold; премахнати са над 300 реда дублирани long-press handlers.
Normal column/wall move използва typed translation adapters и пази wall reference
baseline. Cancel изчиства и opening grips/vertex/edge previews. Axis no-op сравнява
с метрична numerical tolerance, за да не добавя Undo от CAD round-trip шум.

Историята на Construction използва staged baseline/publish. Подготовката,
невалидният резултат и semantic no-op не променят Undo/Redo и не изместват реална
стъпка от ограничения буфер. Сравнението игнорира гледания етаж. Вътрешните slab
correction стъпки остават native workflow до Save; финалната операция има една
Undo baseline. Премахнати са и неизползваните palette параметри за Lock X/Y и
Generate supports.

Останалата ArchitectZoneGeometry е compatibility alias към общата
BimContourDraftingGeometry: orthogonal guides, whole-boundary offset, squarify,
chain intersection и legacy drafting repair. Area/normal/rotate/line intersection
използват същите primitives като останалите контури. Draft repair запазва своята
policy и не прилага imported stray-origin heuristic. Area и normals са проверени
при origin 1e10. Специфичният zone controller продължава да управлява собствените
drafting/properties и документа си.

Разширените тестове откриха повторно умножаване на Construction beam.depth в
3D при CAD units/metre != 1. Поправено е: depth вече е native CAD размер и се
изважда директно от CAD zTop. Съществуващият тест за сантиметри проверява таван
275 cm и долен ръб 225 cm.

Добавени са dependency guard и реален disk persistence contract: shared core не
импортира native features; edit/save/Undo в Architect не променя structural.json,
а Construction save не променя architectural.json, включително при еднакви IDs.
Обновени са остарелите тестове за отстранения генератор и кратките общи действия.
Hold polygon тестът има видима touch anchor над долния dock; не натиска върху
контролите при проверка на рисуване.

Финална разширена серия: 96 тестови файла, 815 успешни теста, 2 предварително
пропуснати external CAD scenarios (липсващ fixture / изключен integration run).
След последното премахване на unused palette параметри: още 56 успешни проверки.
Статичен анализ на bim_editing, Architect, Construction, bim_projects и засегнатите
тестове; git diff --check. Логовете са в build/bim_editing_stage10_*.log.

Ръководство за поддръжка: [bim_editing/README.md](../lib/src/features/bim_editing/README.md).
Native модели, wall/support topology, slab ownership/contacts/linked offsets,
analysis, persistence и property schemas са запазени. Compatibility aliases и
typed boundary adapters са постоянни интерфейси; няма втори алгоритъм за
извлечените механизми. Новите общи корекции се правят в bim_editing и се проверяват
през реалните потребители в двата режима.

## Git етапи

Всички завършени големи промени са commit-нати и качени поотделно в origin/main:
02aa94c, 732013e, da3d94e, 6d5417c, 3abdb6d, fae3ec7, 129324e, f854f8e,
a059a9d, 992e4f7 и финалният cleanup commit. Чуждата корекция 259609f е запазена
като отделен commit и не е включвана в нашите етапи.
