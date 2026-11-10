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

# LLM Navigation & Search Protocol (Large Files >1500 lines)

- **Holistic System Architecture over Local Snippet Editing (Anti-Tunnel-Vision Protocol)**:
  - **The index is a navigational GPS, NOT a substitute for understanding the architecture**: `<filename>.index.md` exists to save tokens and find line numbers in 30k+ line files. It must NEVER be used to make isolated code edits in a vacuum.
  - **Mandatory End-to-End Tracing**: Before modifying any tool or interaction, the agent MUST trace the complete lifecycle:
    `Input Gesture (Pointer/Viewport) -> Gesture Arena Arbitration (isDraggingHandle/Pan Lock) -> Tool State Machine (Controller) -> Standard UI (ArchitectRadialMenu/HUD) -> Model Commit (CommandController with Undo/Redo)`.
  - **Zero Divergent UI Paradigm**: Every drafting entity in Koto BIM (walls, slabs, roofs, zones, underlays) MUST adhere to standard unified UI controls (`ArchitectRadialMenu`, `BimEditAction`). Never introduce disparate local popups (e.g. Material `showMenu`) or alien detached modal windows when a unified mechanism exists.
  - **Gesture Collision Auditing**: When modifying interaction modes, agents MUST verify:
    1. Large bounding boxes (such as CAD drawings or raster underlays) never intercept or hijack clicks/holds meant for underlying elements.
    2. Single-pointer panning (`_canPan` in viewport) is strictly locked out during active dragging or multi-step placement (`isDraggingHandle`).
    3. Stationary hold timers (`onContextHold`) and secondary tap timers never interrupt or abort active placement sessions.

- **Companion Semantic Maps (<filename>.index.md)**:
  - For massive screens and controllers (such as architect_workspace_screen.dart and structural_designer_screen.dart), always check for a companion <filename>.index.md file in the same directory before reading or editing the Dart file.
  - Read <filename>.index.md first (it is compact, ~100-300 lines) to obtain the exact method names, state variables, tool routing matrices, and line number ranges.

- **Top-of-File Table of Contents (TOC) & Grep Anchors**:
  - Large files (>1500 lines) maintain a structured Table of Contents in the header with standardized section markers:
    // === SECTION: [SEC-ID] <NAME> ===
    // --- SUBSECTION: [TAG:<NAME>] <SUBTITLE> ---
  - When searching for specific tools or logic (e.g. wall split, fenestration radial actions, 2D viewport overlays), search for the unique tag (e.g. [TAG:TOUCH_UP], [TAG:WALL_SPLIT]) or use the line ranges indicated in the TOC and .index.md.

- **Mandatory Maintenance (Definition of Done)**:
  - Whenever you add new methods, classes, tool handlers, or structural sections in these large files, updating the corresponding <filename>.index.md and the in-file Table of Contents is a **mandatory completion requirement**:
    1. Register new methods, command classes, or tool handlers in the <filename>.index.md tables/matrices.
    2. Add or maintain // --- SUBSECTION: [TAG:<NAME>] --- grep anchors for new features.
    3. Keep approximate line ranges in TOC and .index.md up to date so subsequent agent invocations do not search blindly.

# Token & Resource Efficiency (Static Analysis & Verification)

- **Avoid Slow Intermediate `flutter analyze` Runs**: Do NOT run `flutter analyze` after intermediate edits or on massive files (>15,000 lines) unless strictly necessary, because slow backgrounded commands force extra agent turns that re-bill the entire conversation context and dump ~100 lines of package resolution logs.
- **Use Fast Targeted `dart analyze` Only When Needed**: When verification is needed, run `dart analyze --no-fatal-infos <changed_new_files>` **once at the very end of the task** (preferring the smaller newly created/modified service, model, and widget files rather than 30,000-line screens unless debugging a specific compile error).
