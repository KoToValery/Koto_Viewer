---
name: index-large-file
description: >-
  Automatically scans large Dart files (>1,500 or 10,000+ lines), extracts all
  classes, enums, state fields, and methods with exact line ranges, injects or
  updates Top-of-File TOC and [SEC-*] / [TAG:*] markers, and generates or syncs
  the companion <filename>.index.md navigation map in under a second. Use this
  skill whenever creating, indexing, or updating a large file (>1500 lines), or
  when the user asks to index large files.
---

# Index Large File (`index-large-file`)

This skill provides a zero-dependency, ultra-fast Python indexer
([index_large_file.py](./scripts/index_large_file.py)) that scans a 10,000+ line
file in ~0.2 seconds and maintains both:
1. **Top-of-File Table of Contents (TOC) & Grep Anchors** inside the `.dart` file:
   - `// === SECTION: [SEC-ID] <TITLE> ===`
   - `// --- SUBSECTION: [TAG:<NAME>] <DESCRIPTION> ---`
2. **Companion Semantic Navigation Map (`<filename>.index.md`)** (~100–300 lines)
   in the same folder, indexing 100% of sections, classes, methods, and key
   state fields with exact `L<start>–L<end>` ranges.

---

## Quick Commands (One-Line Execution)

### 1. Index a New Large File or Sync an Existing One (Default)
Run with a single command on any `.dart` file:

```powershell
python .agents/skills/index-large-file/scripts/index_large_file.py <path/to/file.dart>
```

**What this does automatically:**
- **If the file has no `[SEC-*]` markers yet**:
  1. Parses all imports, classes, enums, mixins, state fields, and methods.
  2. Auto-partitions the file into semantic sections (`[SEC-01-...]`, `[TAG:...]`) aligned cleanly above declaration/doc-comment boundaries.
  3. Injects the `// === SECTION:` and `// --- SUBSECTION:` anchors plus the `// MASTER ... LLM SEARCH INDEX & TABLE OF CONTENTS` header right after the imports block.
  4. Generates `<filename>.index.md` with 100% exact post-injection line numbers.
- **If the file already has `[SEC-*]` / `[TAG:*]` markers**:
  1. Recomputes the current line spans of every section and updates the Top-of-File TOC inside the `.dart` file in-place.
  2. Updates the total line count and section line ranges in `<filename>.index.md` (preserving any hand-written tool routing matrices or notes), or generates `<filename>.index.md` if missing.

---

### 2. Force Full Regeneration of `<filename>.index.md`
To rebuild `<filename>.index.md` completely from scratch (including the full Class Registry, Method & Action Directory, and State Fields Registry):

```powershell
python .agents/skills/index-large-file/scripts/index_large_file.py <path/to/file.dart> --force-overwrite
```

---

### 3. Generate `<filename>.index.md` Without Touching the `.dart` Source
If you only want to generate or update `<filename>.index.md` without inserting comments into the `.dart` file:

```powershell
python .agents/skills/index-large-file/scripts/index_large_file.py <path/to/file.dart> --no-modify-source
```

---

### 4. Audit All Large Files (`>= 1500` Lines) Across the Workspace
To scan `lib/` and see which large files have a TOC and `.index.md`, which ones are missing an index, and which ones have drifted line numbers:

```powershell
python .agents/skills/index-large-file/scripts/index_large_file.py lib --scan-workspace
```

To **automatically index/sync all missing or out-of-sync large files** across `lib/` in one batch command:

```powershell
python .agents/skills/index-large-file/scripts/index_large_file.py lib --scan-workspace --batch-sync
```

---

## CLI Options Reference

| Flag | Description |
| :--- | :--- |
| `--dry-run` | Preview detected sections, classes, methods, and line spans in the terminal without modifying any files. |
| `--no-modify-source` | Write/update `<filename>.index.md` only; do not modify the `.dart` file. |
| `--force-overwrite` | Overwrite an existing `<filename>.index.md` with a freshly generated full map instead of only syncing line spans. |
| `--force-auto-sections` | Re-partition the file into semantic sections even if some markers already exist. |
| `--prefix <TAG_PREFIX>` | Override the auto-derived tag prefix (e.g. `--prefix ROOF_GEOM`). |
| `--chunk-lines <N>` | Target lines per auto-generated section inside massive classes (default: `850`, or `1400` for `10,000+` line files). |
| `--scan-workspace` | Scan a directory tree for all `.dart` files `>= --min-lines` (default `1500`). |
| `--batch-sync` | Used with `--scan-workspace` to automatically index/sync all missing or drifted files. |
