# UI preferences

- On phones, use the shortest clear labels. Avoid repeated names, explanatory phrases in menus, and duplicate elevations in storey tabs.
- This app is multilingual. Put all product UI words, including default preset labels, descriptions and tooltips, in the existing ARB localization system for every supported language. Do not hardcode language checks or translated strings in widgets or model catalogs. User-entered names and numeric/unit symbols are not translations.
- Treat localization as a standing user requirement: every new or changed UI label must use an ARB message in every supported language, including temporary controls and category names. Check this before finishing UI work.
- Do not derive UI labels by splitting or replacing translated text. Use ARB messages or dedicated localized labels.
- Keep detailed guidance in tooltips or help; preserve space for the drawing.

# Collaboration preferences

- Tell the user when a requested correction appears illogical, unusually inconsistent, or incorrect. Explain the concrete issue and suggest a sensible alternative before implementing that part.

# Architectural & Structural Drawing Philosophy

- Use a print-first visual style for all architectural drawing elements and future PDF, DXF, and plot output. Room stamps and schedules use dark text on white paper, thin neutral rules, and at most very light shading. Avoid solid dark annotation backgrounds and dense fills that become black patches in monochrome print. Preserve clear lineweight hierarchy and sparse material hatching; colour must never be the only way to read an element.

- The primary goal of the architectural and structural BIM module is to automatically produce the cleanest, most accurate, publication-ready architectural and structural drawings/details without requiring the user to manually trim or delete redundant lines.
- When generating sections, elevations, plans, or 3D views, intersecting elements (e.g., roofs, walls, slabs, ring beams, wall plates, rafters, fascia, flashing) must form structurally and architecturally accurate junctions with boolean-clean geometry (no overlapping hatches, crossing lines, or protruding wall slivers).

# LLM Navigation & Reference-First Implementation (Large / Interactive Features)

- **Indexes are discovery aids, not specifications.** A companion <filename>.index.md or in-file TOC can suggest relevant tags, methods, state, and related UI. Verify every lead against the current source with rg and read the implementation before relying on it. Do not use line numbers in a map as authoritative locations; prefer stable [TAG:...] anchors and method names.
- **Reference-first for behavior changes:** When a change affects interaction, tool behavior, model mutation, or introduces a new user-facing flow, identify the closest existing feature with the same interaction pattern. Inspect its relevant implementation and immediate callers/callees. Inspect a second example only when the first leaves ambiguity or several established patterns may apply. For isolated presentation, localization, copy, or layout changes that do not alter behavior, use a targeted check of the nearest control; full lifecycle tracing is not required.
- **Trace the applicable path.** For behavior changes, follow the relevant input and viewport hit/gesture routing, tool or screen state, preview/rendering, contextual UI, model mutation, undo/redo, and persistence. These parts may be split across files and need not form one fixed sequence. Do not inspect unrelated layers merely to satisfy a checklist. Record which existing pattern the change follows and explain any meaningful deviation.
- **Reuse the closest fitting UI archetype.** Preserve established behavior for comparable operations, but do not force every tool into one widget such as ArchitectRadialMenu. Placement HUDs, selection actions, property bars, dialogs, and multi-step overlays are distinct existing patterns; choose by the operation and verify the analogous implementation.
- **Audit gesture conflicts when changing interaction or viewport behavior.** Check hit testing, large underlay bounds, active drag/placement pan locks, and hold/secondary-tap timers where relevant. Verify the actual mechanism and names in the code instead of assuming every viewport uses _canPan or isDraggingHandle.
- **Follow the domain's real mutation path.** Inspect the analogous feature to determine its command, undo/redo, and persistence flow. Use the owning module's established mechanisms; do not assume every operation must call a particular command controller or save hook.
- **Navigation markers and maintenance:** For large files, use an existing companion map if present, then verify its entries in source. Add or update stable section/tag markers when they materially improve navigation. Update a companion map when its feature relationships or reference patterns change; manual line-range maintenance is not required. Treat any line spans in existing in-file TOCs as hints and verify them before use.

# Token & Resource Efficiency (Static Analysis & Verification)

- **Avoid Slow Intermediate `flutter analyze` Runs**: Do NOT run `flutter analyze` after intermediate edits or on massive files (>15,000 lines) unless strictly necessary, because slow backgrounded commands force extra agent turns that re-bill the entire conversation context and dump ~100 lines of package resolution logs.
- **Use Fast Targeted `dart analyze` Only When Needed**: When verification is needed, run `dart analyze --no-fatal-infos <changed_new_files>` **once at the very end of the task** (preferring the smaller newly created/modified service, model, and widget files rather than 30,000-line screens unless debugging a specific compile error).
