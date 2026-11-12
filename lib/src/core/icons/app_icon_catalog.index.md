# App Icon Catalog — Reference & Navigation Map
> **Path**: `lib/src/core/icons/app_icon_catalog.dart`  
> **Primary class**: `AppIconDefinition` (+1 more)  
> **Important**: Treat this map as a discovery aid, not a specification. Verify concrete symbols, anchors, and behavior in the current source with `rg -n`.

---

## 1. How to use this map

1. Use this map to find the relevant section tag, class, or method name.
2. Search the current Dart source with `rg -n "\[TAG:<NAME>\]|<SymbolName>" lib/src/core/icons/app_icon_catalog.dart`.
3. For behavior changes, read the target implementation and its immediate callers/callees; follow the Reference-First protocol in `AGENTS.md` / `GEMINI.md`.

---

## 2. Source section registry

| Section ID | Tag | Description & Primary Responsibilities |
| :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:APP_CATALOG_IMPORTS]` | Package, model, service, and widget imports |
| `[SEC-01-ENUMS]` | `[TAG:APP_CATALOG_ENUMS]` | Declarations: `AppIconId` |
| `[SEC-02-APPICOND]` | `[TAG:APP_CATALOG_APPICOND]` | Declarations: `AppIconDefinition` |
| `[SEC-03-APPICONS]` | `[TAG:APP_CATALOG_APPICONS]` | Declarations: `AppIcons` |

---

## 3. Classes, Enums & Top-Level Declarations

| Symbol | Kind | Members | Signature / Heritage |
| :--- | :--- | :--- | :--- |
| `AppIconId` | enum | 0 | `enum AppIconId` |
| `AppIconDefinition` | extension | 2 | `extension AppIconDefinition on AppIconId` |
| `AppIcons` | class | 3 | `class AppIcons` |

---

## 4. Method & Action Directory (3 methods indexed)

| Method / Handler | Class | Section Tag | Summary / Signature |
| :--- | :--- | :--- | :--- |
| `label` | `AppIconDefinition` | `[TAG:APP_CATALOG_APPICOND]` | String label(AppLocalizations l) => switch (this) |
| `isRegistered` | `AppIcons` | `[TAG:APP_CATALOG_APPICONS]` | static bool isRegistered(IconData? icon) |
| `fromMaterial` | `AppIcons` | `[TAG:APP_CATALOG_APPICONS]` | static AppIconId fromMaterial(IconData? icon) |

---

## 5. Key State Fields & Controllers Registry (2 fields)

- `assetPath` (`String`)
- `_material` (`Map<IconData, AppIconId>`)

## Contour edit symbols

`AppIconId.edgePull`, `edgeMove`, and `edgeExtend` use separate local SVGs and
independent ARB-backed labels. The polygon toolbar supplies semantic IDs directly;
Material bridge mappings do not determine these three edit operations.
