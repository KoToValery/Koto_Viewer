---
name: index-large-file
description: >-
  Automatically scans large Dart files (>1,500 or 10,000+ lines), extracts
  classes, enums, state fields, and methods, injects or updates Top-of-File TOC
  and [SEC-*] / [TAG:*] grep anchors without volatile line ranges, and generates
  or syncs the companion <filename>.index.md reference map. Use this skill
  whenever creating, indexing, or updating a large file (>1500 lines), or when
  the user asks to index large files.
---

# Index Large File (`index-large-file`)

This skill provides a zero-dependency Python indexer
([index_large_file.py](./scripts/index_large_file.py)) that scans large Dart
files and maintains discovery aids without brittle hardcoded line numbers:

1. **Top-of-File Table of Contents (TOC) & Grep Anchors** inside the `.dart` file:
   - `// === SECTION: [SEC-ID] <TITLE> ===`
   - `// --- SUBSECTION: [TAG:<NAME>] <DESCRIPTION> ---`
2. **Companion Semantic Reference Map (`<filename>.index.md`)** in the same
   folder, listing sections, classes, primary methods, and key state fields by
   `[TAG:*]` anchor and symbol name (for verification with `rg -n`).

> **Important**: Companion `.index.md` files and TOCs are discovery aids, not
> specifications or authoritative line-offset tables. Always verify symbols,
> callers/callees, and behavior in the current source with `rg -n` and follow the
> Reference-First protocol in `AGENTS.md` / `GEMINI.md`.

---

## Quick Commands (One-Line Execution)

### 1. Index a New Large File or Sync an Existing One (Default)
Run on any `.dart` file:

```powershell
python .agents/skills/index-large-file/scripts/index_large_file.py <path/to/file.dart>
```

**What this does automatically:**
- **If the file has no `[SEC-*]` markers yet**:
  1. Parses imports, classes, enums, mixins, state fields, and methods.
  2. Auto-partitions the file into semantic sections (`[SEC-01-...]`, `[TAG:...]`) aligned cleanly above declaration/doc-comment boundaries.
  3. Injects `// === SECTION:` and `// --- SUBSECTION:` anchors plus the `// MASTER ... LLM SEARCH INDEX & TABLE OF CONTENTS` header right after the imports block (without volatile `L...` line ranges).
  4. Generates `<filename>.index.md` with `[TAG:*]` anchors and concrete symbol names for `rg -n`.
- **If the file already has `[SEC-*]` / `[TAG:*]` markers**:
  1. Updates the Top-of-File TOC inside the `.dart` file in-place (preserving tag-based navigation without hardcoded line spans).
  2. Leaves hand-curated `<filename>.index.md` reference maps intact, or creates `<filename>.index.md` if missing.

---

### 2. Force Full Regeneration of `<filename>.index.md`
To rebuild `<filename>.index.md` from scratch (e.g., after major refactoring):

```powershell
python .agents/skills/index-large-file/scripts/index_large_file.py <path/to/file.dart> --force-overwrite
```

---

### 3. Generate `<filename>.index.md` Without Touching the `.dart` Source
If you only want to generate `<filename>.index.md` without inserting comments into the `.dart` file:

```powershell
python .agents/skills/index-large-file/scripts/index_large_file.py <path/to/file.dart> --no-modify-source
```

---

### 4. Audit All Large Files (`>= 1500` Lines) Across the Workspace
To scan `lib/` and see which large files have a TOC and `.index.md`:

```powershell
python .agents/skills/index-large-file/scripts/index_large_file.py lib --scan-workspace
```

To **automatically index/sync missing files** across `lib/`:

```powershell
python .agents/skills/index-large-file/scripts/index_large_file.py lib --scan-workspace --batch-sync
```

---

## CLI Options Reference

| Flag | Description |
| :--- | :--- |
| `--dry-run` | Preview detected sections, classes, and methods in the terminal without modifying any files. |
| `--no-modify-source` | Write `<filename>.index.md` only; do not modify the `.dart` file. |
| `--force-overwrite` | Overwrite an existing `<filename>.index.md` with a freshly generated map. |
| `--force-auto-sections` | Re-partition the file into semantic sections even if some markers already exist. |
| `--prefix <TAG_PREFIX>` | Override the auto-derived tag prefix (e.g. `--prefix ROOF_GEOM`). |
| `--chunk-lines <N>` | Target lines per auto-generated section inside massive classes (default: `850`, or `1400` for `10,000+` line files). |
| `--scan-workspace` | Scan a directory tree for all `.dart` files `>= --min-lines` (default `1500`). |
| `--batch-sync` | Used with `--scan-workspace` to automatically index missing files. |
