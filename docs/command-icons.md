# Command icons

The application uses an original technical outline SVG library. Open
[the bilingual gallery](command-icons.html) to inspect every symbol at 14, 16,
20 and 24 pixels on light and dark backgrounds. The gallery works offline.

[The inventory](command-icon-inventory.json) records assets, ARB labels, semantic
references and command presentation sites. It includes dynamic consumers through
`AppIcon.fromMaterial` and `BimEditingSymbol`, as well as direct SVG consumers.

## Using a symbol

Use `AppIcon(AppIconId.move)` in a button or menu. It inherits `IconTheme` size,
color and opacity. The button owns its localized tooltip and accessible label;
the icon is excluded from semantics unless a standalone `semanticLabel` is supplied.
Use `AppMenuLabel(icon: AppIconId.move, child: Text(context.l10n.architectRadialMove))`
for an entry that previously contained only text. Checked entries retain their
independent selection marker.

Command descriptors use `AppIconId`. Existing canvas/renderer types retain their
`IconData` fields and expose semantic `iconId` adapters where needed. The explicit
`AppIcon.fromMaterial` bridge supports remaining renderer/category data; an
unregistered glyph throws instead of displaying an unrelated fallback symbol.

## Editing the library

1. Author geometry in `tools/generate_command_icons.py` and add the corresponding
   `commandIcon…` label to both ARB files. ARB is the only source for display text.
   Use the 24-unit grid, 1.75-unit main stroke and optional 1.25-unit secondary lines,
   rounded ends/joints, transparent background and `currentColor`. Keep detail
   sparse enough to read at 14 pixels. SVGs contain no fonts, raster data or links.
2. Run `python tools/generate_command_icons.py`, `flutter gen-l10n`, then
   `dart format lib/src/core/icons/app_icon_catalog.dart`.
3. Connect the semantic ID to the actual command. Reuse a symbol for the same
   operation; distinguish operations such as duplicate, mirror-copy and offset.
4. Run `python tools/verify_command_icons.py` to validate resources, localization
   and the inventory, then `flutter test --no-pub test/command_icons_test.dart`.

For native Flutter render contact sheets, run the test with
`UPDATE_COMMAND_ICON_PREVIEWS=true`. It writes PNG inspection sheets under
`scratch/command_icon_previews`; these are QA artifacts, not application assets.

Numeric values, user/preset names, plain confirmation buttons, file thumbnails
and drawing geometry keep their existing presentation. Product labels and
tooltips are sourced from ARB in both supported languages.

Architectural element symbols use distinct construction silhouettes: masonry
with visible thickness, a plan-view door swing, a window frame and sill, a
column prism, a continuous beam section and a thin slab. Glazing divisions,
masonry joints and swing arcs use lighter secondary lines. Roofs and stairs
avoid crossing decorative strokes so they remain legible at small sizes.
