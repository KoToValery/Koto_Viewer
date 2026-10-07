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

