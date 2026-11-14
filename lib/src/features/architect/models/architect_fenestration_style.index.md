# Architect Fenestration Style — Reference & Navigation Map
> **Path**: `lib/src/features/architect/models/architect_fenestration_style.dart`  
> **Primary class**: `ArchitectFenestrationStyle` (+4 more)  
> **Important**: Treat this map as a discovery aid, not a specification. Verify concrete symbols, anchors, and behavior in the current source with `rg -n`.

---

## 1. How to use this map

1. Use this map to find the relevant section tag, class, or method name.
2. Search the current Dart source with `rg -n "\[TAG:<NAME>\]|<SymbolName>" lib/src/features/architect/models/architect_fenestration_style.dart`.
3. For behavior changes, read the target implementation and its immediate callers/callees; follow the Reference-First protocol in `AGENTS.md` / `GEMINI.md`.

---

## 2. Source section registry

| Section ID | Tag | Description & Primary Responsibilities |
| :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:ARCH_STYLE_IMPORTS]` | Package, model, service, and widget imports |
| `[SEC-01-MODELS]` | `[TAG:ARCH_STYLE_FENESTRA]` | Declarations: `FenestrationKind`, `PaneType`, `GlazingType`, `FenestrationInfill` (+4 more) |
| `[SEC-02-FENESTRA]` | `[TAG:ARCH_STYLE_FENESTRA_2]` | Declarations: `FenestrationLayout` |
| `[SEC-03-STATE]` | `[TAG:ARCH_STYLE_STATE]` | `ArchitectFenestrationStyle` state fields (29 fields: `id`, `name`, `kind`, `defaultWidth`, `defaultHeight`) |
| `[SEC-04-CORE]` | `[TAG:ARCH_STYLE_CORE_LOGIC]` | Core Operations & Helpers: `resolveLayout`, `copyWith`, `setPaneMetricDimension`, `splitPane` (7 methods) |
| `[SEC-05-XFORM]` | `[TAG:ARCH_STYLE_XFORM_COORDS]` | Coordinate Transforms & Viewport Math: `collapsePane`, `updatePane`, `getPaneRect` (3 methods) |
| `[SEC-06-CORE]` | `[TAG:ARCH_STYLE_PAINT_PLAN2]` | Core Operations & Helpers: `paintPlan2D`, `paintElevation2D` (2 methods) |
| `[SEC-07-PAINT]` | `[TAG:ARCH_STYLE_PAINT_RENDER]` | Canvas Painting & Geometry Rendering: `_renderSubdivisionElevation` (1 methods) |
| `[SEC-08-DIMS]` | `[TAG:ARCH_STYLE_DIMS_ANNOT]` | Dimensions, Text & Annotations: `_drawElevationDimensions`, `localizedName` (2 methods) |
| `[SEC-09-CORE]` | `[TAG:ARCH_STYLE_STANDARD_CATALOG]` | Core Operations & Helpers: `standardCatalog` (1 methods) |
| `[SEC-10-PARSE]` | `[TAG:ARCH_STYLE_PARSER_IO]` | Parsing, Serialization & Underlays: `toJson` (1 methods) |

---

## 3. Classes, Enums & Top-Level Declarations

| Symbol | Kind | Members | Signature / Heritage |
| :--- | :--- | :--- | :--- |
| `FenestrationKind` | enum | 0 | `enum FenestrationKind` |
| `PaneType` | enum | 0 | `enum PaneType` |
| `GlazingType` | enum | 0 | `enum GlazingType` |
| `FenestrationInfill` | enum | 0 | `enum FenestrationInfill` |
| `CasingPlacement` | enum | 0 | `enum CasingPlacement` |
| `FenestrationPane` | class | 16 | `class FenestrationPane` |
| `FenestrationSubdivision` | class | 19 | `class FenestrationSubdivision` |
| `FenestrationTransom` | class | 6 | `class FenestrationTransom` |
| `FenestrationLayout` | class | 2 | `class FenestrationLayout` |
| `ArchitectFenestrationStyle` | class | 46 | `class ArchitectFenestrationStyle` |

---

## 4. Method & Action Directory (41 methods indexed)

| Method / Handler | Class | Section Tag | Summary / Signature |
| :--- | :--- | :--- | :--- |
| `FenestrationPane` | `FenestrationPane` | `[TAG:ARCH_STYLE_FENESTRA]` | const FenestrationPane({ required this.id, this.paneType = PaneType.fixedGl |
| `copyWith` | `FenestrationPane` | `[TAG:ARCH_STYLE_FENESTRA]` | FenestrationPane copyWith({ String? id, PaneType? paneType, double? sashPro |
| `toJson` | `FenestrationPane` | `[TAG:ARCH_STYLE_FENESTRA]` | Map<String, dynamic> toJson() => |
| `FenestrationPane.fromJson` | `FenestrationPane` | `[TAG:ARCH_STYLE_FENESTRA]` | factory FenestrationPane.fromJson( Map<String, dynamic> json, ) |
| `FenestrationSubdivision` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | const FenestrationSubdivision({ required this.id, this.isSplit = false, thi |
| `copyWith` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | FenestrationSubdivision copyWith({ String? id, bool? isSplit, bool? isVerti |
| `findPane` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | Recursively finds a pane by ID. |
| `updatePane` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | Replaces a pane in the tree with an updated pane. |
| `collectPanes` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | Collects all leaf panes. |
| `split` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | Splits this node into [count] parts along [vertical]. |
| `splitPane` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | Splits an individual leaf pane identified by [targetPaneId]. |
| `collapsePane` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | Collapses an individual division or pane back to a single leaf pane. |
| `setChildMetricDimension` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | Sets the exact metric dimension of a child leaf pane along [isWidth]. |
| `collectPaneRects` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | Collects metric bounding rects for every leaf pane. |
| `collapse` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | Collapses children and resets to a single leaf pane. |
| `toJson` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | Map<String, dynamic> toJson() => |
| `FenestrationSubdivision.fromJson` | `FenestrationSubdivision` | `[TAG:ARCH_STYLE_FENESTRA]` | factory FenestrationSubdivision.fromJson( Map<String, dynamic> json, ) |
| `FenestrationTransom` | `FenestrationTransom` | `[TAG:ARCH_STYLE_FENESTRA]` | const FenestrationTransom({ this.height = .40, this.subdivision = const Fen |
| `copyWith` | `FenestrationTransom` | `[TAG:ARCH_STYLE_FENESTRA]` | FenestrationTransom copyWith({ double? height, FenestrationSubdivision? sub |
| `toJson` | `FenestrationTransom` | `[TAG:ARCH_STYLE_FENESTRA]` | Map<String, dynamic> toJson() => |
| `FenestrationTransom.fromJson` | `FenestrationTransom` | `[TAG:ARCH_STYLE_FENESTRA]` | factory FenestrationTransom.fromJson(Map<String, dynamic> json) |
| `FenestrationLayout` | `FenestrationLayout` | `[TAG:ARCH_STYLE_FENESTRA_2]` | const FenestrationLayout(this.panes, this.dividers) |
| `ArchitectFenestrationStyle` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_STATE]` | const ArchitectFenestrationStyle({ required this.id, required this.name, th |
| `centimeters` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_CORE_LOGIC]` | static String centimeters(double meters) |
| `withTransom` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_CORE_LOGIC]` | ArchitectFenestrationStyle withTransom(FenestrationTransom? next) |
| `subdivisionForHeight` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_CORE_LOGIC]` | Nominal zones are used for metric editing; physical profiles use resolveLay |
| `resolveLayout` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_CORE_LOGIC]` | FenestrationLayout resolveLayout( |
| `copyWith` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_CORE_LOGIC]` | ArchitectFenestrationStyle copyWith({ String? id, String? name, Fenestratio |
| `setPaneMetricDimension` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_CORE_LOGIC]` | Sets the exact metric dimension for a child leaf pane along [isWidth]. |
| `splitPane` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_CORE_LOGIC]` | Splits an individual leaf pane identified by [paneId]. |
| `collapsePane` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_XFORM_COORDS]` | Collapses an individual division or pane back to a single leaf pane. |
| `updatePane` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_XFORM_COORDS]` | Updates a specific pane with new properties. |
| `getPaneRect` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_XFORM_COORDS]` | Gets the metric rect for a given pane ID. |
| `paintPlan2D` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_PAINT_PLAN2]` | Draws the horizontal 2D architectural CAD plan cut of the window/door in th |
| `paintElevation2D` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_PAINT_PLAN2]` | Draws the interactive 2D facade elevation in the editor workspace. |
| `_renderSubdivisionElevation` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_PAINT_RENDER]` | void _renderSubdivisionElevation( |
| `_drawElevationDimensions` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_DIMS_ANNOT]` | void _drawElevationDimensions(Canvas canvas, Offset origin, double scale) |
| `localizedName` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_DIMS_ANNOT]` | Returns the localized display name for preset styles, or [name] for custom  |
| `standardCatalog` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_STANDARD_CATALOG]` | static List<ArchitectFenestrationStyle> standardCatalog() |
| `toJson` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_PARSER_IO]` | Map<String, dynamic> toJson() => |
| `ArchitectFenestrationStyle.fromJson` | `ArchitectFenestrationStyle` | `[TAG:ARCH_STYLE_PARSER_IO]` | factory ArchitectFenestrationStyle.fromJson( Map<String, dynamic> json, ) |

---

## 5. Key State Fields & Controllers Registry (48 fields)

- `id` (`String`)
- `paneType` (`PaneType`)
- `sashProfileWidth` (`double`)
- `hasHandle` (`bool`)
- `infill` (`FenestrationInfill?`)
- `muntinCols` (`int`)
- `muntinRows` (`int`)
- `muntinWidth` (`double`)
- `isOpenable` (`bool`)
- `isGlazed` (`bool`)
- `isSolidPanel` (`bool`)
- `hasMuntins` (`bool`)
- `id` (`String`)
- `isSplit` (`bool`)
- `isVertical` (`bool`)
- `ratios` (`List<double>`)
- `children` (`List<FenestrationSubdivision>`)
- `pane` (`FenestrationPane?`)
- `height` (`double`)
- `subdivision` (`FenestrationSubdivision`)
- `dividers` (`List<Rect>`)
- `id` (`String`)
- `name` (`String`)
- `kind` (`FenestrationKind`)
- `defaultWidth` (`double`)
- `defaultHeight` (`double`)
- `defaultSillHeight` (`double`)
- `frameDepth` (`double`)
- `frameFaceWidth` (`double`)
- `centerInCore` (`bool`)
- `glazingType` (`GlazingType`)
- `glazingThickness` (`double`)
- `glassColorValue` (`int`)
- `hasCasing` (`bool`)
- `casingWidth` (`double`)
- `casingProjection` (`double`)
- `casingPlacement` (`CasingPlacement`)
- `casingColorValue` (`int`)
- `includeBottomCasing` (`bool`)
- `rootSubdivision` (`FenestrationSubdivision`)
- `transom` (`FenestrationTransom?`)
- `glassColor` (`Color`)
- `casingColor` (`Color`)
- `_presetIds` (`var`)
- `isPreset` (`bool`)
- *+3 additional fields in source*
