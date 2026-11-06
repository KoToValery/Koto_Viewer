# Architectural tools, mobile forms and sheet publication

The tool palette now uses one localized catalog for category membership, icons,
labels, shortcuts and search. The category button opens a touch-sized overview;
search selects a tool directly. Pan stays available beside every category.
Switching to another category stops the previous drawing mode. Drawing-only
views expose only selection, annotations and 2D drafting.

| Category | Tools |
| --- | --- |
| Select | Single/multiple selection, navigation; contextual selection actions remain in the palette |
| Plan | Axes, rooms, room schedule |
| Building | Walls, doors, windows, roofs, openings, stairs |
| Structure | Columns, beams, slabs |
| Furnishing | Component library, floor drain |
| Views | Sections, elevations |
| Dimensions & text | Dimensions, level markers, text, measurement |
| 2D drawing | Lines, rectangles, circles, hatches; terrain remains a contextual action |

Roofs belong to the architectural building group. Floor drains have one category
instead of appearing in both building and structure. Catalog names and default
fenestration names resolve through ARB; BG and EN both include every new message.

## Mobile readability

The palette, component library and room preset/finish forms follow the app's
light/dark theme. Component names have two lines, and grid heights grow with text
scaling. Wall-layer numeric fields leave room for both the value and unit.

56 alert call sites share `architectAlertDialog`: 16 px outside margins, scrolling
title/content when height is limited, persistent field labels and 48 px action
targets. The existing property shell and keyboard-aware property route remain
responsible for the large element editors. Room preset guidance lives in help;
the title and reset labels are shorter.

The screenshot matrix covers BG/EN, light/dark, 320 px with 1.4x text, and a
260 px keyboard inset for editable forms: settings, wall types/composition,
slabs, roofs, stairs, library, project wizard, room presets, schedules and section
properties. Sheet creation/placement, placement properties, visibility and export
selection are also exercised at 360 px with 1.4x text.

## Sheet layout and PDF

`ArchitectSheetLayout` owns paper margins, title-block bounds, title height,
available drawing areas, source fitting and publication checks. New and duplicated
views use free space above the title block. Fitting rebuilds annotations at each
supported scale (1:20, 1:50, 1:100, 1:200, 1:500), keeps rotation, and refuses a
space too small to fit the source and its fixed paper lettering. It never silently
crops as a fallback. Manual frame cropping remains available in Properties.

The sheet editor fits the complete paper on opening/format changes and exposes
Fit sheet, Fit view, PDF and Check layout directly. Moving placements converts
pointer deltas to paper coordinates through the current zoom transform. Preview
source scenes are reused while moving; changing the project, locale or underlay
source invalidates that cache. PDF builds independently from its project snapshot.

Placement coordinates display three decimals, retaining full stored values when
saved unchanged. Sheet format labels track custom width/height edits. View names
avoid repeating the storey elevation in source choices.

Preview and PDF use the same checks for invalid geometry, missing sources or title
templates, off-margin frames/titles, overlapping placements, title-block overlap
and overflowing title-block text. PDF reports the affected sheet number. Empty
title cells and zero-size rule elements remain valid. Titles wrap to the frame
width; title blocks have a white background. PDF preserves vector geometry,
embedded Cyrillic text, physical annotation sizes and independent page sizes.

## Verification

The focused acceptance run passes **52 tests**:

```powershell
flutter test --no-pub --dart-define=ARCHITECT_MOBILE_QA=true test/features/architect/architect_mobile_publication_test.dart test/features/architect/architect_publication_test.dart test/features/architect/architect_categories_and_visible_clearances_test.dart test/features/architect/architect_settings_and_wall_axes_test.dart
```

The changed implementation files and the new test file pass targeted analysis
without diagnostics. The full architectural module still has pre-existing lint
suggestions. A localization audit found all 155 referenced messages in both ARBs.

Artifacts are regenerated under ignored `build/architect_mobile_qa/` and
`build/architect_publication/`. `sheets.pdf` and `screen.png` come from the real
publication pipeline. Poppler inspection confirms exact A3 and A4 media boxes;
both rendered pages were visually checked, including Cyrillic, schedules and
title blocks. A4 uses a fitted placement rather than clipping an inherited A3
frame. The existing Extend test now confirms the preview before asserting its
single Undo transaction.

A broader editor regression run has seven failures reproduced against the
unchanged HEAD implementation, with the same failures and assertions:

- `architect_special_wall_ui_test`: deleted panel support controls; log course
  contour assertion.
- `architect_roof_ui_optimization_test`: obsolete roof preset control lookup in
  BG and EN.
- `architect_properties_redesign_test`: door ID field lookup; workspace property
  action lookup.
- `architect_wall_picker_test`: draft catalog count expectation (7 versus 9).

Evidence: `build/architect_final_regression.log` and
`build/architect_preexisting_regression.log`. Native Android/iOS file dialogs,
printer-driver scaling and a physical 100% print require a device/printer run;
widget tests and PDF rendering do not substitute for that check.
