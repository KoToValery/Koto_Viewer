# DXF Parser — LLM Semantic Navigation Map
> **Path**: `lib/src/features/dxf_viewer/parser/dxf_parser.dart`  
> **Total Lines**: ~2,587 | **Primary Class**: `DxfParser`  
> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step.

---

## 1. LLM Navigation Protocol (How to search in 1 step)

1. **Find the Parsing Stage / Entity**: Look at Section 2 (Master Section Registry) or Section 3 (Entity Parsing Directory).
2. **Jump via Unique Tag or Line Range**:
   - In Antigravity / CLI: Use `git grep -n "\[TAG:<NAME>\]"` or read the specified line range via `read_file`.
   - In Copilot / Codex / Cursor: Mention the tag `[TAG:<NAME>]` or target method name in your prompt.

---

## 2. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:DXF_P_IMPORTS]` | L1 – L12 | IO, math, foundation, KCAD binary cache, UniversalEncoding |
| `[SEC-01-PAIRS]` | `[TAG:DXF_P_PAIRS]` | L13 – L24 | `_DxfPair` group code & value tokenizer |
| `[SEC-02-API]` | `[TAG:DXF_P_API]` | L25 – L150 | `DxfParser` class, `parseFromFile`, KCAD cache fast-path |
| `[SEC-03-HEADER]` | `[TAG:DXF_P_HEADER]` | L151 – L398 | HEADER section parsing, `$EXTMIN`, `$EXTMAX`, `$INSUNITS` |
| `[SEC-04-TABLES]` | `[TAG:DXF_P_TABLES]` | L399 – L737 | TABLES section: LAYER, LTYPE, STYLE, DIMSTYLE, VPORT |
| `[SEC-05-BLOCKS]` | `[TAG:DXF_P_BLOCKS]` | L738 – L814 | BLOCKS section: BLOCK headers, base points, nested entity lists |
| `[SEC-06-ENTITIES]` | `[TAG:DXF_P_ENTITIES]`| L815 – L944 | ENTITIES main dispatch switch loop |
| `[SEC-07-PRIMITIVES]`| `[TAG:DXF_P_GEOM]` | L945 – L1353 | LINE, CIRCLE, ARC, LWPOLYLINE, POLYLINE, SPLINE |
| `[SEC-08-TEXT]` | `[TAG:DXF_P_TEXT]` | L1354 – L1640 | TEXT, MTEXT, formatting codes, alignments, Cyrillic fix |
| `[SEC-09-HATCH-INS]`| `[TAG:DXF_P_HATCH]` | L1641 – L1886 | HATCH boundary loops, INSERT block references & scales |
| `[SEC-10-DIMS-MISC]`| `[TAG:DXF_P_DIMS]` | L1887 – L2238 | DIMENSION, LEADER, SOLID, TRACE, ELLIPSE |
| `[SEC-11-HELPERS]` | `[TAG:DXF_P_HELPERS]` | L2239 – L2587 | `_stripMTextFormattingCodes`, color decoding, point parsing |

---

## 3. Entity Parsing Directory

| DXF Entity | Case Handler Line | Section Tag |
| :--- | :--- | :--- |
| `LINE` | L945 | `[TAG:DXF_P_GEOM]` |
| `CIRCLE` | L1006 | `[TAG:DXF_P_GEOM]` |
| `ARC` | L1039 | `[TAG:DXF_P_GEOM]` |
| `LWPOLYLINE` | L1125 | `[TAG:DXF_P_GEOM]` |
| `POLYLINE` | L1206 | `[TAG:DXF_P_GEOM]` |
| `SPLINE` | L1293 | `[TAG:DXF_P_GEOM]` |
| `TEXT` | L1354 | `[TAG:DXF_P_TEXT]` |
| `MTEXT` | L1477 | `[TAG:DXF_P_TEXT]` |
| `HATCH` | L1641 | `[TAG:DXF_P_HATCH]` |
| `INSERT` | L1737 | `[TAG:DXF_P_HATCH]` |
| `DIMENSION` | L1887 | `[TAG:DXF_P_DIMS]` |
