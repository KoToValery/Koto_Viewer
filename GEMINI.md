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
- **Top-of-File Section Indexing & Companion Maps (Level 1 LLM Navigation)**:
  - **Заглавен индекс (TOC)**: В началото на всеки обединен/голям файл (>1500 реда) задължително се поддържа структуриран коментарен Table of Contents с унифицирани тагове:
    // === SECTION: [SEC-ID] <NAME> ===
    // --- SUBSECTION: [TAG:<NAME>] <SUBTITLE> ---
  - **Съпътстваща семантична карта (<filename>.index.md)**: За ключовите големи екрани и контролери (напр. architect_workspace_screen.dart, structural_designer_screen.dart) задължително се поддържа съпътстващ <filename>.index.md навигационен файл в същата папка.
  - **LLM Search & Navigation Protocol (Задължително за Antigravity & Codex)**:
    1. **Holistic System Architecture over Local Snippet Editing (Anti-Tunnel-Vision Protocol)**:
       - **Индексът е само GPS за редове, НЕ замества системната архитектура**: `<filename>.index.md` служи единствено за пестене на токени и навигация в 30k+ редови файлове. Забранено е да се правят локални редакции „на парче“ без разбиране на цялостната система.
       - **Задължително проследяване от край до край (End-to-End Tracing)**: Преди промяна на инструмент или взаимодействие, агентът задължително проследява цялата верига:
         `Жест (Pointer/Viewport) -> Арбитраж на жестовете (Gesture Arena/isDraggingHandle) -> Интерактивно състояние (Tool Controller) -> Стандартно UI (ArchitectRadialMenu/HUD) -> Модел (Command/Undo-Redo)`.
       - **Единна UX парадигма (Zero Divergent UI)**: Всички чертожни елементи в Koto BIM (стени, плочи, покриви, подложки, зони) задължително използват общите за Koto BIM контроли (`ArchitectRadialMenu`, `BimEditAction`). Забранено е въвеждането на локални падащи Material менюта или отделни чужди прозорци.
       - **Одит за конфликти между жестове (Gesture Collision Auditing)**: При интерактивни режими задължително се верифицира:
         a) Големи граници (CAD bounding boxes) да не прихващат целия екран или да пречат на селекция на обекти под тях.
         b) Панорамирането (`_canPan` / `singlePointerPan` във вюпорта) да се блокира при активно влачене или позициониране (`isDraggingHandle`).
         c) Таймери за задържане (`onContextHold`) и вторични жестове да не прекъсват активно чертане или местене.
    2. Преди да чете или променя голям файл (>1500 реда), LLM агентът задължително първо проверява за съпътстващ `<filename>.index.md` и го прочита, за да получи точната карта на методите, състоянието и зависимостите.
    3. Използва grep по унифицираните тагове `[TAG:*]` или чете точния диапазон от редове вместо цялостно четене на файла.
    4. Задължителна поддръжка при дописване (Definition of Done):
       - При добавяне на нови методи, класове, инструменти или раздели, обновяването на съответния `.index.md` и заглавния TOC е **задължително изискване за завършеност на задачата**:
         a) Регистрира новия метод/клас в таблиците на съответния `<filename>.index.md`.
         b) Поставя унифициран коментарен маркер `// --- SUBSECTION: [TAG:<NAME>] ---` над новия блок.
         c) Актуализира приблизителните диапазони на редовете в заглавния TOC и `.index.md`, за да се предотврати десинхронизация при следващи итерации.

## 5. Automated Clean Architectural & Structural Drawings (Zero Manual Cleanup)
- **Core Philosophy**: Целта на програмата е автоматично да генерира възможно най-изчистените, точни и конструктивно издържани архитектурни чертежи и детайли, без да се налага потребителят ръчно да трие излишни или пресичащи се линии.
- **Constructive Junctions & Boolean Clipping**: При генериране на разрези, фасади, планове и 3D детайли, пресичащите се елементи (покриви, стени, плочи, стоманобетонни пояси, мауерлати, ребра, челни дъски, обшивки) трябва автоматично да се прикрепят, подрязват и обединяват булево в завършен архитектурен и конструктивен детайл без дублирани контури, стърчащи стени или пресичащи се щриховки.

## 6. Token & Resource Efficiency (`dart analyze` vs `flutter analyze`)
- **Без междинни и тежки извиквания на `flutter analyze`**: НЕ стартирай `flutter analyze` след междинни редакции или върху огромни файлове (>15 000 реда) без крайна необходимост, тъй като бавните фонови задачи предизвикват двойни стъпки (turns) на агента и повторно таксуване на целия контекст, плюс ~100 реда шум от `Resolving dependencies...`.
- **Еднократен и лек `dart analyze` само при необходимост**: Когато е необходима проверка на кода, използвай бързата команда `dart analyze --no-fatal-infos <конкретни_нови/променени_файлове>` **само веднъж в самия край на задачата** (приоритетно върху по-малките модулни файлове — модели, сервизи, уиджети).
