# Project Guidelines & Rules (Koto Viewer)

## 1. Mandatory Localization (i18n / l10n)
- **Zero Hardcoded Strings**: NEVER hardcode Bulgarian, English, or any other natural language text directly in Flutter widgets, bottom sheets, dialogs, or calculation recommendation messages.
- **Always Use ARB Localizations**: All UI strings, tooltips, tab titles, status values, warnings, and architectural/engineering recommendations MUST be defined in:
  - `lib/l10n/app_en.arb` (English - template)
  - `lib/l10n/app_bg.arb` (Bulgarian)
- **Adding New Strings Workflow**:
  1. Add the key and `@key` metadata to `lib/l10n/app_en.arb`.
  2. Add the key and Bulgarian translation to `lib/l10n/app_bg.arb`.
  3. Run `flutter gen-l10n` to regenerate `AppLocalizations`.
  4. Access strings via `context.l10n.<key>` in widgets (via `l10n_extensions.dart`).
- **Calculation Engines & Models (Structural BiM Designer)**:
  - Calculators (`SeismicAnalysisCalculator`, `VerticalCapacityCalculator`, `CantileverDetector`, etc.) must store structured numeric/enum results in models.
  - Recommendation and alert texts must be localized using helper methods taking `AppLocalizations` (e.g. `model.localizedRecommendation(AppLocalizations l10n)`) or formatted in UI widgets with `context.l10n`, rather than baking hardcoded Bulgarian strings into calculation logic.

## 2. Responsive UI & Overflow Prevention
- **TabBars**: When a `TabBar` has multiple tabs or tabs with icons and text, ALWAYS set `isScrollable: true` and `tabAlignment: TabAlignment.start` to prevent horizontal `RenderFlex` overflows on narrow mobile screens.
- **Metrics and Stat Cards**: In horizontal rows with multiple stat cards or metrics, use `Expanded`, `FittedBox(fit: BoxFit.scaleDown)`, and `maxLines: 1, overflow: TextOverflow.ellipsis` with proper padding so cards adapt to varying screen widths and system font sizes without overflowing.

## 3. Geometric-First Element Detection (BIM / CAD Architecture)
- **Always Prefer Geometric-Based Algorithms over Hardcoded Word/Layer Filters**: NEVER rely on hardcoded layer names or dictionary keyword filters as the primary mechanism to identify architectural/structural elements (walls, windows, vitrines, columns, doors, slabs).
- **Rationale**: In real-world BIM/CAD workflows (e.g. Archicad Worksheet exports, unlayered CAD drawings, or arbitrary user conventions), windows and doors frequently share the exact same layer as walls (e.g. `стени`, `A-WALL`, `0`) or are placed on unstandardized layers.
- **Geometric Principles**: Element detection must be driven by physical geometry (parallel pairs at standard thickness, jamb-to-jamb opening corridors, transverse mullion profiles, lineweight contrasts between cut and uncut pen, dimensional markers, etc.).

## 4. Balanced Modular Architecture (Anti-God File & Anti-Ravioli Code)
- **Avoid God Files**: Never dump multiple unrelated features, models, business rules, and UI into massive multi-thousand-line single files.
- **Avoid Over-Fragmentation (Ravioli Code)**: Do NOT scatter tightly coupled logic belonging to a single tool across dozens of micro-files (e.g. separate 40-line files for math helpers, point state, enum results, drafting controllers, and extrusion controllers).
- **Standard 3-Tier Tool / Feature Structure**:
  1. `models/<element>.dart`: Clean data entity, geometry properties, and serialization.
  2. `services/<element>_tool.dart`: Unified tool controller, interaction state machine, and associated geometry/math algorithms for that specific tool.
  3. `rendering/<element>_painter_helper.dart` & `widgets/<element>_bar.dart`: High-performance canvas drawing routines and user-facing HUD widgets.
- **Granularity & Splitting Thresholds**:
  - **Мек праг**: ~1200–1500 реда.
  - **Твърд праг**: ~2000 реда.
  - **Правило за разделяне над мекия праг**: При надхвърляне на ~1200–1500 реда НЕ разделяй автоматично. Първо провери дали файлът съдържа ясни вътрешни секции (`геометрия` / `логика` / `UI`). Ако да, раздели единствено по тези естествени граници.
  - **Правило за споделена геометрия**: Ако дадена математика/геометрия се използва от повече от един инструмент (напр. slab, wall, zone), тя задължително се изнася в отделен споделен геодезичен/геометричен модул, независимо от броя редове.
- **LLM Navigation & Reference-First Implementation (Large / Interactive Features)**:
  - **Картите са за ориентация, не са спецификация.** Съпътстващият <filename>.index.md или вграденият TOC може да насочи към тагове, методи, състояния и UI. Провери всяка следа в актуалния код чрез rg и прочети имплементацията, преди да разчиташ на нея. Не използвай номерата на редове в карта като авторитетни позиции; предпочитай стабилните [TAG:...] маркери и имената на методите.
  - **Аналог преди код при промени в поведението:** Когато промяната засяга взаимодействие, поведение на инструмент, промяна на модела или въвежда нов потребителски поток, намери най-близката съществуваща функция със същия модел на взаимодействие. Прегледай релевантната имплементация и непосредствените ѝ извиквания. Провери втори аналог само ако първият оставя неяснота или има няколко приложими модела. При изолирана визуална, локализационна, текстова или layout корекция без промяна в поведението направи насочена проверка на най-близкия контрол; пълно проследяване не е нужно.
  - **Проследи приложимия път.** При промени в поведението провери релевантните входни събития и hit/gesture маршрути във viewport-а, състоянието на инструмента или екрана, preview/rendering, контекстното UI, промяната на модела, undo/redo и persistence. Тези части може да са в различни файлове и не е задължително да следват една фиксирана последователност. Не преглеждай несвързани слоеве само за да изпълниш списък. Посочи кой съществуващ модел следва промяната и обясни съществените отклонения.
  - **Използвай най-близкия подходящ UI архетип.** Запази установеното поведение за сходни операции, но не налагай един уиджет като ArchitectRadialMenu за всеки инструмент. Лентите за чертане, действията при селекция, лентите за свойства, диалозите и многостъпковите overlay-и са различни съществуващи модели; избери според операцията и провери аналога в кода.
  - **Проверявай конфликтите между жестове при промени във взаимодействието или viewport-а.** Когато е приложимо, провери hit testing, големите граници на подложки, блокирането на pan при активно влачене/чертане и таймерите за задържане/вторичен тап. Провери реалния механизъм и имената в кода; не приемай, че всеки viewport използва _canPan или isDraggingHandle.
  - **Следвай реалния път за промяна на модела в съответния домейн.** Прегледай аналога, за да установиш използваните command, undo/redo и persistence механизми. Не приемай, че всяка операция трябва да извиква един и същ command controller или save hook.
  - **Маркери и поддръжка:** При големи файлове използвай наличната съпътстваща карта, ако има такава, и сверявай записите ѝ в кода. Добавяй или обновявай стабилни маркери за раздели/тагове, когато реално подобряват навигацията. Обновявай съпътстващата карта при промяна на връзките между функции или референтните модели; ръчна поддръжка на диапазони от редове не се изисква. Съществуващите диапазони във вградените TOC са ориентир и трябва да се проверяват преди употреба.

## 5. Automated Clean Architectural & Structural Drawings (Zero Manual Cleanup)
- **Core Philosophy**: Целта на програмата е автоматично да генерира възможно най-изчистените, точни и конструктивно издържани архитектурни чертежи и детайли, без да се налага потребителят ръчно да трие излишни или пресичащи се линии.
- **Constructive Junctions & Boolean Clipping**: При генериране на разрези, фасади, планове и 3D детайли, пресичащите се елементи (покриви, стени, плочи, стоманобетонни пояси, мауерлати, ребра, челни дъски, обшивки) трябва автоматично да се прикрепят, подрязват и обединяват булево в завършен архитектурен и конструктивен детайл без дублирани контури, стърчащи стени или пресичащи се щриховки.

## 6. Token & Resource Efficiency (`dart analyze` vs `flutter analyze`)
- **Без междинни и тежки извиквания на `flutter analyze`**: НЕ стартирай `flutter analyze` след междинни редакции или върху огромни файлове (>15 000 реда) без крайна необходимост, тъй като бавните фонови задачи предизвикват двойни стъпки (turns) на агента и повторно таксуване на целия контекст, плюс ~100 реда шум от `Resolving dependencies...`.
- **Еднократен и лек `dart analyze` само при необходимост**: Когато е необходима проверка на кода, използвай бързата команда `dart analyze --no-fatal-infos <конкретни_нови/променени_файлове>` **само веднъж в самия край на задачата** (приоритетно върху по-малките модулни файлове — модели, сервизи, уиджети).
