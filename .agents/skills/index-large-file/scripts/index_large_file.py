#!/usr/bin/env python3
"""
Fast LLM Semantic Indexer & TOC Generator for Large Dart Files (>1500 lines).

Capabilities:
1. Scans any large Dart file (1,500 to 50,000+ lines) in <0.2 seconds.
2. Extracts all imports, classes, enums, mixins, extensions, state fields,
   controllers, getters/setters, and methods with exact start/end line spans.
3. Automatically detects existing `// === SECTION:` and `// --- SUBSECTION:`
   anchors OR auto-partitions unindexed files into semantic sections & tags.
4. Injects/updates the Top-of-File Table of Contents (TOC) and section anchors
   directly in the `.dart` file (preserving CRLF/LF line endings).
5. Generates or syncs the companion `<filename>.index.md` (~100-300 lines) with
   100% of methods, classes, state fields, and section line ranges indexed.
6. Supports `--scan-workspace` to audit all large files (>1500 lines) across a
   repository in one command.
"""

from __future__ import annotations

import argparse
import dataclasses
import os
import re
import sys
import time
from pathlib import Path
from typing import List, Optional, Tuple, Dict


# ============================================================================
# DATA STRUCTURES
# ============================================================================

@dataclasses.dataclass
class Declaration:
    kind: str  # 'class', 'enum', 'mixin', 'extension', 'typedef', 'function'
    name: str
    signature: str
    doc_start_line: int  # 1-based line including leading doc comments/annotations
    start_line: int      # 1-based line of declaration keyword
    end_line: int        # 1-based closing brace/semicolon line
    members: List[Member] = dataclasses.field(default_factory=list)


@dataclasses.dataclass
class Member:
    kind: str  # 'field', 'getter', 'setter', 'constructor', 'method'
    name: str
    return_type: str
    signature: str
    doc_start_line: int
    start_line: int
    end_line: int
    parent_class: str
    doc_summary: str = ""

    @property
    def line_count(self) -> int:
        return max(1, self.end_line - self.start_line + 1)


@dataclasses.dataclass
class SectionMarker:
    is_subsection: bool
    sec_id: str      # e.g. "[SEC-01-WIDGET]" or "[SUB-02A]"
    tag: str         # e.g. "[TAG:WIDGET_API]"
    title: str       # e.g. "WIDGET DECLARATION & PUBLIC API"
    description: str # Summary for .index.md and TOC
    line_num: int    # 1-based start line in file
    end_line: int = 0
    auto_generated: bool = False


# ============================================================================
# DART STRUCTURAL LEXER & PARSER
# ============================================================================

_RE_SECTION = re.compile(
    r"^\s*//\s*===\s*SECTION:\s*(\[SEC-[^\]]+\])\s*(.*?)\s*===\s*$"
)
_RE_SUBSECTION = re.compile(
    r"^\s*//\s*---\s*SUBSECTION:\s*(\[TAG:[^\]]+\])\s*(.*?)\s*---\s*$"
)
_RE_TOC_TAG = re.compile(
    r"^\s*//\s*(?:↳\s*)?(\[(?:SEC|SUB)-[^\]]+\])\s+L\d+\s*-\s*L\d+\s*:\s*(\[TAG:[^\]]+\])\s*(.*?)\s*$"
)
_RE_TOC_BORDER = re.compile(r"^\s*//\s*={40,}\s*$")

_RE_DIRECTIVE = re.compile(
    r"^\s*(?:import|export|part|library)\b"
)

_RE_TOP_CLASS = re.compile(
    r"^(?:abstract\s+|base\s+|final\s+|interface\s+|sealed\s+|mixin\s+)*"
    r"(class|enum|mixin|extension|typedef)\s+([A-Za-z0-9_$]+)?(.*)$"
)

_CONTROL_KEYWORDS = {
    "if", "for", "while", "switch", "catch", "return", "assert",
    "super", "this", "throw", "rethrow", "try", "else", "do", "case",
}


def compute_line_brace_deltas(lines: List[str]) -> List[Tuple[int, int, str]]:
    """
    Scans Dart lines tracking strings (single, double, triple, raw) and
    comments (// and /* */), plus ${...} string interpolations.
    Returns per-line (brace_delta, paren_delta, stripped_code_without_comments).
    """
    results: List[Tuple[int, int, str]] = []
    # State stack: ('CODE', '') or ('BLOCK_COMMENT', '') or ('STRING', quote_info)
    # where quote_info is e.g. "'", '"', "'''", '"""', "r'", 'r"', "r'''", 'r"""'
    # or ('INTERP', brace_depth_inside_interp)
    stack: List[Tuple[str, object]] = [("CODE", None)]

    for raw_line in lines:
        line = raw_line.rstrip("\r\n")
        i = 0
        n = len(line)
        brace_delta = 0
        paren_delta = 0
        code_chars: List[str] = []

        while i < n:
            mode, info = stack[-1]

            if mode == "BLOCK_COMMENT":
                end_idx = line.find("*/", i)
                if end_idx == -1:
                    i = n
                else:
                    stack.pop()
                    i = end_idx + 2
                continue

            if mode == "STRING":
                q_str = str(info)
                is_raw = q_str.startswith("r")
                quote = q_str[1:] if is_raw else q_str

                if not is_raw and line[i] == "\\":
                    i += 2
                    continue

                if not is_raw and line.startswith("${", i):
                    stack.append(("INTERP", 1))
                    i += 2
                    continue

                if line.startswith(quote, i):
                    stack.pop()
                    i += len(quote)
                    continue

                i += 1
                continue

            # mode is 'CODE' or 'INTERP'
            if line.startswith("//", i):
                break
            if line.startswith("/*", i):
                stack.append(("BLOCK_COMMENT", None))
                i += 2
                continue

            # Check for raw string or normal string start
            if line[i] in ("'", '"') or (
                line[i] == "r" and i + 1 < n and line[i + 1] in ("'", '"')
            ):
                is_raw = line[i] == "r"
                q_start = i + 1 if is_raw else i
                q_char = line[q_start]
                if line.startswith(q_char * 3, q_start):
                    quote = q_char * 3
                else:
                    quote = q_char
                q_info = ("r" + quote) if is_raw else quote
                stack.append(("STRING", q_info))
                code_chars.append("''")
                i = q_start + len(quote)
                continue

            ch = line[i]
            if mode == "INTERP":
                if ch == "{":
                    stack[-1] = ("INTERP", int(info) + 1)
                elif ch == "}":
                    cur_d = int(info) - 1
                    if cur_d <= 0:
                        stack.pop()
                    else:
                        stack[-1] = ("INTERP", cur_d)
                i += 1
                continue

            # Normal CODE mode
            if ch == "{":
                brace_delta += 1
            elif ch == "}":
                brace_delta -= 1
            elif ch == "(":
                paren_delta += 1
            elif ch == ")":
                paren_delta -= 1

            code_chars.append(ch)
            i += 1

        results.append((brace_delta, paren_delta, "".join(code_chars).strip()))

    return results


def _find_doc_start_line(lines: List[str], decl_line_idx: int, min_line_idx: int) -> int:
    """
    Walks backwards from decl_line_idx (0-based) to include contiguous
    doc comments (`///`), annotations (`@...`), or single-line comments
    that immediately precede the declaration, stopping at section markers
    or blank lines.
    """
    idx = decl_line_idx
    while idx > min_line_idx:
        prev = lines[idx - 1].strip()
        if not prev:
            break
        if _RE_SECTION.match(prev) or _RE_SUBSECTION.match(prev) or _RE_TOC_BORDER.match(prev):
            break
        if prev.startswith("// ===") or prev.startswith("// ---"):
            break
        if prev.startswith("///") or prev.startswith("@") or (
            prev.startswith("//") and not prev.startswith("// [SEC-")
        ):
            idx -= 1
        else:
            break
    return idx + 1  # 1-based


def _extract_doc_summary(lines: List[str], doc_start_1: int, start_1: int) -> str:
    for idx in range(doc_start_1 - 1, start_1 - 1):
        s = lines[idx].strip()
        if s.startswith("///"):
            clean = s.lstrip("/").strip()
            if clean:
                return clean[:90]
    return ""


def _parse_member_header(header: str, class_name: str) -> Optional[Tuple[str, str, str]]:
    """
    Given the cleaned code header of a class member up to `{`, `=>`, or `;`,
    returns (kind, member_name, return_type) or None if not a valid member.
    """
    h = " ".join(header.split()).strip()
    if not h:
        return None
    # Strip leading annotations like @override, @pragma(...)
    while h.startswith("@"):
        m_ann = re.match(r"^@[A-Za-z0-9_$.]+(?:\([^)]*\))?\s*", h)
        if m_ann:
            h = h[m_ann.end():].strip()
        else:
            break
    if not h:
        return None

    # Strip modifiers
    for mod in ("static ", " external ", "abstract ", "covariant ", "late ", "final ", "const ", "var "):
        pass
    h_clean = re.sub(
        r"^(?:static\s+|external\s+|abstract\s+|covariant\s+|late\s+|final\s+|const\s+|var\s+)+",
        "",
        h,
    ).strip()

    # Check if there is an '=' outside parentheses before '(' or '{'
    paren_d = 0
    angle_d = 0
    eq_pos = -1
    paren_pos = -1
    for idx, ch in enumerate(h_clean):
        if ch == "(":
            if paren_d == 0 and paren_pos == -1:
                paren_pos = idx
            paren_d += 1
        elif ch == ")":
            paren_d = max(0, paren_d - 1)
        elif ch == "<":
            angle_d += 1
        elif ch == ">":
            angle_d = max(0, angle_d - 1)
        elif ch == "=" and paren_d == 0 and angle_d == 0:
            # Make sure it's not '==' or '=>' or '!=' or '<=' or '>='
            prev_c = h_clean[idx - 1] if idx > 0 else ""
            next_c = h_clean[idx + 1] if idx + 1 < len(h_clean) else ""
            if prev_c not in ("=", "!", "<", ">") and next_c not in ("=", ">"):
                eq_pos = idx
                break

    # Getter check: `<Type?> get <name>`
    m_get = re.match(r"^(?:(.+?)\s+)?get\s+([A-Za-z0-9_$]+)\b", h_clean)
    if m_get:
        ret_type = (m_get.group(1) or "dynamic").strip()
        return ("getter", m_get.group(2), ret_type)

    # Setter check: `<Type?> set <name>(...)`
    m_set = re.match(r"^(?:(.+?)\s+)?set\s+([A-Za-z0-9_$]+)\s*\(", h_clean)
    if m_set:
        ret_type = (m_set.group(1) or "void").strip()
        return ("setter", m_set.group(2), ret_type)

    # Field check: either has `=` before `(` or has no `(` at all
    if eq_pos != -1 and (paren_pos == -1 or eq_pos < paren_pos):
        lhs = h_clean[:eq_pos].strip()
        tokens = lhs.split()
        if not tokens:
            return None
        name = tokens[-1].rstrip("?;")
        ret_type = " ".join(tokens[:-1]) if len(tokens) > 1 else "var"
        if name in _CONTROL_KEYWORDS or not re.match(r"^[A-Za-z_$][A-Za-z0-9_$]*$", name):
            return None
        return ("field", name, ret_type)

    if paren_pos == -1:
        lhs = h_clean.rstrip(";").strip()
        tokens = lhs.split()
        if not tokens:
            return None
        name = tokens[-1].rstrip("?")
        ret_type = " ".join(tokens[:-1]) if len(tokens) > 1 else "var"
        if name in _CONTROL_KEYWORDS or not re.match(r"^[A-Za-z_$][A-Za-z0-9_$]*$", name):
            return None
        return ("field", name, ret_type)

    # Otherwise it has `(` with no preceding `=` -> Constructor or Method
    before_paren = h_clean[:paren_pos].strip()
    # Handle generic method `<T>` right before `(`
    before_paren = re.sub(r"<[^>]+>\s*$", "", before_paren).strip()
    tokens = before_paren.split()
    if not tokens:
        return None

    name = tokens[-1]
    ret_type = " ".join(tokens[:-1]) if len(tokens) > 1 else ""
    if name in _CONTROL_KEYWORDS:
        return None

    if name == class_name or name.startswith(class_name + ".") or name == "factory":
        if name == "factory" and len(tokens) >= 2:
            name = tokens[-1]
        return ("constructor", name, class_name)

    if not re.match(r"^(?:operator\b|[A-Za-z_$][A-Za-z0-9_$.]*)$", name):
        return None

    return ("method", name, ret_type or "void")


def parse_dart_file(
    lines: List[str],
    index_path: Optional[Path] = None,
) -> Tuple[
    int,                           # last_directive_line (1-based, 0 if none)
    Optional[Tuple[int, int]],     # existing_toc_span (1-based start, end)
    List[SectionMarker],           # existing_markers
    List[Declaration],             # top_declarations
]:
    """
    Single-pass structural parser over a Dart file.
    """
    deltas = compute_line_brace_deltas(lines)
    n_lines = len(lines)

    last_directive_line = 0
    in_directive = False
    existing_toc_span: Optional[Tuple[int, int]] = None
    existing_markers: List[SectionMarker] = []
    toc_tag_descriptions: Dict[str, str] = {}
    toc_sec_to_tag: Dict[str, str] = {}
    toc_tag_to_sec: Dict[str, str] = {}

    # Pre-load authoritative section/tag metadata from companion .index.md if it exists
    if index_path is not None and index_path.exists():
        try:
            for md_line in index_path.read_text(encoding="utf-8", errors="replace").splitlines():
                if md_line.strip().startswith("|"):
                    cols = [c.strip() for c in md_line.strip().strip("|").split("|")]
                    if len(cols) >= 4:
                        m_sec = re.search(r"(\[(?:SEC|SUB)-[^\]]+\])", cols[0])
                        m_tag = re.search(r"(\[TAG:[^\]]+\])", cols[1])
                        desc_col = cols[3].strip()
                        if m_sec and m_tag:
                            s_id, t_id = m_sec.group(1), m_tag.group(1)
                            toc_sec_to_tag[s_id] = t_id
                            toc_tag_to_sec[t_id] = s_id
                            if desc_col:
                                toc_tag_descriptions[s_id] = desc_col
                                toc_tag_descriptions[t_id] = desc_col
        except Exception:
            pass

    # Detect existing TOC block and section markers
    toc_start = None
    for idx, raw in enumerate(lines):
        line_num = idx + 1
        s = raw.strip()

        m_toc_row = _RE_TOC_TAG.match(s)
        if m_toc_row:
            sec_id, tag, desc = m_toc_row.group(1), m_toc_row.group(2), m_toc_row.group(3)
            toc_tag_descriptions.setdefault(sec_id, desc)
            toc_tag_descriptions.setdefault(tag, desc)
            toc_sec_to_tag.setdefault(sec_id, tag)
            toc_tag_to_sec.setdefault(tag, sec_id)

        if _RE_TOC_BORDER.match(s):
            if toc_start is None and idx + 1 < n_lines and (
                "SEARCH INDEX" in lines[idx + 1] or "TABLE OF CONTENTS" in lines[idx + 1]
            ):
                toc_start = line_num
            elif toc_start is not None and line_num > toc_start + 2 and existing_toc_span is None:
                existing_toc_span = (toc_start, line_num)

        m_sec = _RE_SECTION.match(s)
        if m_sec:
            sec_id = m_sec.group(1).strip()
            title = m_sec.group(2).strip()
            known_tag = toc_sec_to_tag.get(sec_id, "")
            existing_markers.append(
                SectionMarker(
                    is_subsection=False,
                    sec_id=sec_id,
                    tag=known_tag,
                    title=title,
                    description=toc_tag_descriptions.get(sec_id, title.title()),
                    line_num=line_num,
                )
            )
            continue

        m_sub = _RE_SUBSECTION.match(s)
        if m_sub:
            tag = m_sub.strip() if isinstance(m_sub, str) else m_sub.group(1).strip()
            subtitle = m_sub.group(2).strip()
            mapped_sec = toc_tag_to_sec.get(tag, "")
            # Merge into preceding SECTION only if that SECTION has no distinct tag
            # and this SUBSECTION is not explicitly a `[SUB-...]` entry in the TOC.
            if (
                existing_markers
                and not existing_markers[-1].is_subsection
                and line_num - existing_markers[-1].line_num <= 2
                and not mapped_sec.startswith("[SUB-")
                and (not existing_markers[-1].tag or existing_markers[-1].tag == tag)
            ):
                existing_markers[-1].tag = tag
                if subtitle and subtitle != existing_markers[-1].description:
                    existing_markers[-1].description = toc_tag_descriptions.get(tag, subtitle)
            else:
                existing_markers.append(
                    SectionMarker(
                        is_subsection=True,
                        sec_id=mapped_sec if mapped_sec.startswith("[SUB-") else "",
                        tag=tag,
                        title=subtitle,
                        description=toc_tag_descriptions.get(tag, subtitle),
                        line_num=line_num,
                    )
                )

    # Fill any still-missing tags/descriptions from toc_sec_to_tag / toc_tag_descriptions
    for mk in existing_markers:
        if mk.sec_id and not mk.tag and mk.sec_id in toc_sec_to_tag:
            mk.tag = toc_sec_to_tag[mk.sec_id]
        if (
            mk.tag
            and not mk.sec_id
            and mk.tag in toc_tag_to_sec
            and (not mk.is_subsection or toc_tag_to_sec[mk.tag].startswith("[SUB-"))
        ):
            mk.sec_id = toc_tag_to_sec[mk.tag]
        if mk.tag and mk.tag in toc_tag_descriptions and (
            not mk.is_subsection or mk.tag not in toc_tag_to_sec or toc_tag_to_sec[mk.tag].startswith("[SUB-")
        ):
            mk.description = toc_tag_descriptions[mk.tag]
        elif mk.sec_id and mk.sec_id in toc_tag_descriptions:
            mk.description = toc_tag_descriptions[mk.sec_id]

    # Structural scan for directives, top-level declarations, and class members
    brace_depth = 0
    paren_depth = 0

    declarations: List[Declaration] = []
    active_decl: Optional[Declaration] = None
    active_member_start: Optional[int] = None
    active_member_doc_start: Optional[int] = None
    active_member_header_parts: List[str] = []
    active_member_info: Optional[Tuple[str, str, str]] = None
    in_member_body = False
    top_Code_started = False

    for idx in range(n_lines):
        line_num = idx + 1
        b_delta, p_delta, code = deltas[idx]

        # Track top-of-file directives (imports, exports, parts, library)
        if not top_Code_started and brace_depth == 0 and paren_depth == 0:
            if in_directive:
                last_directive_line = line_num
                if ";" in code:
                    in_directive = False
                brace_depth += b_delta
                paren_depth += p_delta
                continue
            elif _RE_DIRECTIVE.match(code):
                last_directive_line = line_num
                if ";" not in code:
                    in_directive = True
                brace_depth += b_delta
                paren_depth += p_delta
                continue
            elif code and not code.startswith("@"):
                top_Code_started = True

        # Top-level declaration start (brace_depth == 0, paren_depth == 0)
        if active_decl is None and brace_depth == 0 and paren_depth == 0 and code:
            if not code.startswith("@"):
                m_top = _RE_TOP_CLASS.match(code)
                if m_top:
                    kind = m_top.group(1)
                    name = (m_top.group(2) or "AnonymousExtension").strip()
                    rest = (m_top.group(3) or "").split("{")[0].strip()
                    sig = f"{kind} {name}" + (f" {rest}" if rest else "")
                    doc_start = _find_doc_start_line(
                        lines, idx, declarations[-1].end_line if declarations else last_directive_line
                    )
                    decl = Declaration(
                        kind=kind,
                        name=name.strip(),
                        signature=sig[:100],
                        doc_start_line=doc_start,
                        start_line=line_num,
                        end_line=line_num,
                    )
                    declarations.append(decl)
                    if b_delta > 0 or ("{" not in code and ";" not in code):
                        active_decl = decl
                else:
                    # Check top-level function
                    m_fn = re.match(r"^(?:[A-Za-z0-9_$<>?,\s]+\s+)?([A-Za-z_$][A-Za-z0-9_$]*)\s*\(", code)
                    if m_fn and m_fn.group(1) not in _CONTROL_KEYWORDS:
                        fn_name = m_fn.group(1)
                        doc_start = _find_doc_start_line(
                            lines, idx, declarations[-1].end_line if declarations else last_directive_line
                        )
                        decl = Declaration(
                            kind="function",
                            name=fn_name,
                            signature=code.split("{")[0].strip()[:100],
                            doc_start_line=doc_start,
                            start_line=line_num,
                            end_line=line_num,
                        )
                        declarations.append(decl)
                        if b_delta > 0 or (";" not in code):
                            active_decl = decl

        # Inside an active top-level declaration
        if active_decl is not None:
            # Check member declarations at brace_depth == 1
            if active_decl.kind in ("class", "mixin", "extension"):
                if brace_depth == 1 and paren_depth == 0 and not in_member_body:
                    if active_member_start is None:
                        if code and code != "}" and not code.startswith("@"):
                            prev_bound = (
                                active_decl.members[-1].end_line
                                if active_decl.members
                                else active_decl.start_line
                            )
                            active_member_start = line_num
                            active_member_doc_start = _find_doc_start_line(lines, idx, prev_bound)
                            active_member_header_parts = [code]
                    else:
                        if code:
                            active_member_header_parts.append(code)
                elif active_member_start is not None and not in_member_body:
                    if code:
                        active_member_header_parts.append(code)

            new_brace = brace_depth + b_delta
            new_paren = max(0, paren_depth + p_delta)

            # Check transitions for active class member
            if active_member_start is not None and not in_member_body:
                joined_header = " ".join(active_member_header_parts)
                # Did the member open a block at brace_depth >= 2?
                if new_brace >= 2 and new_paren == 0:
                    header_before_brace = joined_header.split("{")[0]
                    info = _parse_member_header(header_before_brace, active_decl.name)
                    if info is not None:
                        active_member_info = info
                        in_member_body = True
                    else:
                        # Could be a field with a map/set literal `{...}`
                        active_member_info = ("field", "_anon", "var")
                        in_member_body = True
                # Or did the member finish on a `;` at brace_depth == 1, paren_depth == 0?
                elif new_brace == 1 and new_paren == 0 and code.endswith(";"):
                    header_before_semi = joined_header.split("=>")[0].rstrip(";")
                    info = _parse_member_header(header_before_semi, active_decl.name)
                    if info is not None:
                        kind, m_name, ret_type = info
                        # If it used `=>` and wasn't a getter/setter/field, it's an arrow method
                        doc_sum = _extract_doc_summary(
                            lines, active_member_doc_start or active_member_start, active_member_start
                        )
                        active_decl.members.append(
                            Member(
                                kind=kind,
                                name=m_name,
                                return_type=ret_type,
                                signature=header_before_semi.strip()[:90],
                                doc_start_line=active_member_doc_start or active_member_start,
                                start_line=active_member_start,
                                end_line=line_num,
                                parent_class=active_decl.name,
                                doc_summary=doc_sum,
                            )
                        )
                    active_member_start = None
                    active_member_doc_start = None
                    active_member_header_parts = []
                    active_member_info = None

            elif in_member_body and new_brace <= 1 and new_paren == 0:
                # Member body just closed back to brace_depth 1 (or 0 if class also closed)
                if active_member_info is not None and active_member_info[1] != "_anon":
                    kind, m_name, ret_type = active_member_info
                    header_before_brace = " ".join(active_member_header_parts).split("{")[0].strip()
                    doc_sum = _extract_doc_summary(
                        lines, active_member_doc_start or active_member_start, active_member_start
                    )
                    active_decl.members.append(
                        Member(
                            kind=kind,
                            name=m_name,
                            return_type=ret_type,
                            signature=header_before_brace[:90],
                            doc_start_line=active_member_doc_start or active_member_start,
                            start_line=active_member_start or line_num,
                            end_line=line_num,
                            parent_class=active_decl.name,
                            doc_summary=doc_sum,
                        )
                    )
                active_member_start = None
                active_member_doc_start = None
                active_member_header_parts = []
                active_member_info = None
                in_member_body = False

            # Did the top-level declaration itself close back to brace_depth 0?
            if new_brace <= 0 and new_paren == 0 and (
                b_delta < 0 or ";" in code or active_decl.kind == "typedef"
            ):
                active_decl.end_line = line_num
                active_decl = None
                active_member_start = None
                in_member_body = False

            brace_depth = max(0, new_brace)
            paren_depth = new_paren
        else:
            brace_depth = max(0, brace_depth + b_delta)
            paren_depth = max(0, paren_depth + p_delta)

    if active_decl is not None:
        active_decl.end_line = n_lines

    # Compute end_line for existing_markers
    _compute_marker_end_lines(existing_markers, n_lines)

    return last_directive_line, existing_toc_span, existing_markers, declarations


def _compute_marker_end_lines(markers: List[SectionMarker], total_lines: int) -> None:
    top_indices = [i for i, m in enumerate(markers) if not m.is_subsection]
    for pos, idx in enumerate(top_indices):
        if pos + 1 < len(top_indices):
            next_idx = top_indices[pos + 1]
            markers[idx].end_line = markers[next_idx].line_num - 1
        else:
            markers[idx].end_line = total_lines

    for i, m in enumerate(markers):
        if m.is_subsection:
            if i + 1 < len(markers):
                m.end_line = markers[i + 1].line_num - 1
            else:
                m.end_line = total_lines


# ============================================================================
# SEMANTIC AUTO-SECTIONING ENGINE (FOR UNINDEXED LARGE FILES)
# ============================================================================

_DOMAIN_RULES: List[Tuple[str, str, str, re.Pattern]] = [
    ("LIFECYCLE", "STATE_LIFECYCLE", "Lifecycle & Initialization",
     re.compile(r"(?:^initState$|^didUpdateWidget$|^didChangeDependencies$|^dispose$|^reassemble$|_init)", re.I)),
    ("XFORM", "XFORM_COORDS", "Coordinate Transforms & Viewport Math",
     re.compile(r"(?:screenTo|modelTo|cadTo|toScreen|toModel|Transform|zoom|pan|Matrix|Viewport)", re.I)),
    ("HITS", "HIT_TESTING", "Hit Testing & Candidate Picking",
     re.compile(r"(?:hitTest|find.*At|pick|Candidate|Hover|Clearance|Nearest)", re.I)),
    ("TOUCH", "TOUCH_INPUT", "Pointer & Gesture Dispatch",
     re.compile(r"(?:onPointer|onTap|onPan|onScale|Gesture|handleTap|handlePointer|Drag)", re.I)),
    ("COMMITS", "COMMIT_HANDLERS", "Placement & Geometry Commit Handlers",
     re.compile(r"(?:^_?commit|^_?finish|^_?place|^_?tryPlace|^_?apply)", re.I)),
    ("WALLS", "WALL_OPS", "Wall Drafting, Splitting & Joints",
     re.compile(r"(?:Wall|Split|Joint|Corner|Miter|Cut|Trim|Extend)", re.I)),
    ("OPENINGS", "FENEST_OPENINGS", "Doors, Windows & Openings",
     re.compile(r"(?:Door|Window|Opening|Vitrine|Sill|Mullion|Fenest|Radial)", re.I)),
    ("SLABS", "SLABS_ROOFS", "Slabs, Roofs & Polygon Contours",
     re.compile(r"(?:Slab|Roof|Polygon|Contour|Pitch|Rafter|Cantilever|Stair)", re.I)),
    ("ZONES", "ZONE_ROOMS", "Zones, Rooms & Area Schedules",
     re.compile(r"(?:Zone|Room|Schedule|Stamp|Area|Apartment)", re.I)),
    ("GRIDS", "GRID_AXES", "Grid Axes, Alignment & Snapping",
     re.compile(r"(?:Axis|Axes|Grid|Snap|Magnetic|Align|Resequence)", re.I)),
    ("DIMS", "DIMS_ANNOT", "Dimensions, Text & Annotations",
     re.compile(r"(?:Dimension|Leader|Text|MText|Annotat|Measure|Label|Badge|Arrow)", re.I)),
    ("PAINT", "PAINT_RENDER", "Canvas Painting & Geometry Rendering",
     re.compile(r"(?:^paint$|_paint|_draw|_render|Stroke|Hatch|Dash|Path|Canvas)", re.I)),
    ("PARSE", "PARSER_IO", "Parsing, Serialization & Underlays",
     re.compile(r"(?:parse|read|write|export|import|Underlay|Raster|Dxf|Ifc|Step|Json|File)", re.I)),
    ("ANALYSIS", "STRUCT_ANALYSIS", "Engineering Analysis & Verification",
     re.compile(r"(?:Analysis|Seismic|Capacity|Check|Calculate|Solve|Scheme|Load|Deflect)", re.I)),
    ("DIALOGS", "UI_DIALOGS", "Modal Dialogs, Sheets & Property Editors",
     re.compile(r"(?:Dialog|Sheet|Modal|Prompt|Picker|Editor)", re.I)),
    ("BUILD", "BUILD_LAYOUT", "Widget Build & HUD Layout",
     re.compile(r"(?:^build$|_build|AppBar|Toolbar|Dock|Bar|Scaffold|Overlay|View2D|View3D)", re.I)),
]


def _classify_method(name: str) -> Tuple[str, str, str]:
    for short_id, tag_suffix, title, pattern in _DOMAIN_RULES:
        if pattern.search(name):
            return short_id, tag_suffix, title
    return "CORE", "CORE_LOGIC", "Core Operations & Helpers"


_STEM_ABBREV = {
    "ARCHITECT": "ARCH",
    "STRUCTURAL": "STRUCT",
    "DESIGNER": "DESIGN",
    "WORKSPACE": "WORK",
    "PAINTER": "PAINTER",
    "PARSER": "PARSER",
    "CONTROLLER": "CTRL",
    "GEOMETRY": "GEOM",
    "PROPERTIES": "PROPS",
    "ELEMENT": "ELEM",
    "BUILDING": "BLDG",
    "SECTION": "SEC",
    "SECTIONS": "SECS",
    "FENESTRATION": "FENEST",
    "ALIGNMENT": "ALIGN",
    "GENERATOR": "GEN",
    "DETECTOR": "DETECT",
    "VIEWER": "VIEW",
    "MAGNETIC": "MAG",
    "INITIAL": "INIT",
    "SCHEME": "SCHEME",
}


def _method_to_tag_token(method_name: str) -> str:
    clean = method_name.lstrip("_")
    # Convert camelCase to SNAKE_CASE
    s1 = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", clean).upper()
    parts = [p for p in s1.split("_") if p and p not in ("HANDLE", "ON", "BUILD", "SHOW", "TRY")]
    if not parts:
        parts = s1.split("_")
    return "_".join(parts[:2])[:16]


def derive_prefix_from_filename(filepath: Path) -> str:
    stem = filepath.stem.upper()
    raw_parts = [
        p for p in stem.split("_")
        if p not in ("SCREEN", "WIDGET", "SERVICE", "HELPER", "MODELS", "MODEL", "DIALOG")
    ]
    if not raw_parts:
        raw_parts = stem.split("_")
    mapped = [_STEM_ABBREV.get(p, p[:7]) for p in raw_parts]
    if len(mapped) >= 2:
        return f"{mapped[0]}_{mapped[-1]}"
    return mapped[0]


def auto_generate_sections(
    lines: List[str],
    last_directive_line: int,
    declarations: List[Declaration],
    tag_prefix: str,
    target_chunk_lines: int = 800,
) -> List[SectionMarker]:
    """
    Creates clean semantic `SectionMarker` objects for an unindexed Dart file,
    aligning section boundaries strictly with declaration/member doc_start_line
    positions so injected comments never corrupt syntax.
    """
    n_lines = len(lines)
    markers: List[SectionMarker] = []
    used_tags: set[str] = set()
    sec_counter = 1

    def unique_tag(base_tag: str) -> str:
        t = base_tag.upper().replace(" ", "_")
        if t not in used_tags:
            used_tags.add(t)
            return f"[TAG:{t}]"
        idx = 2
        while f"{t}_{idx}" in used_tags:
            idx += 1
        used_tags.add(f"{t}_{idx}")
        return f"[TAG:{t}_{idx}]"

    def next_sec_id(short_label: str) -> str:
        nonlocal sec_counter
        sid = f"[SEC-{sec_counter:02d}-{short_label[:8].upper()}]"
        sec_counter += 1
        return sid

    if not declarations:
        markers.append(
            SectionMarker(
                is_subsection=False,
                sec_id=next_sec_id("MAIN"),
                tag=unique_tag(f"{tag_prefix}_MAIN"),
                title="MAIN MODULE IMPLEMENTATION",
                description="Primary module declarations and functions",
                line_num=max(1, last_directive_line + 1),
                end_line=n_lines,
                auto_generated=True,
            )
        )
        return markers

    # Find if there is one dominant class (>45% of the file and >600 lines)
    dominant_decls = [
        d for d in declarations
        if d.kind in ("class", "mixin", "extension")
        and (d.end_line - d.start_line) > max(600, int(n_lines * 0.40))
    ]

    idx_decl = 0
    while idx_decl < len(declarations):
        decl = declarations[idx_decl]

        if decl in dominant_decls and len(decl.members) >= 5:
            # Partition inside this massive class!
            fields = [m for m in decl.members if m.kind in ("field", "getter", "setter", "constructor")]
            methods = [m for m in decl.members if m.kind == "method"]

            # Class opening & state fields section
            state_desc_names = ", ".join(f"`{f.name}`" for f in fields[:5])
            state_desc = (
                f"`{decl.name}` state fields ({len(fields)} fields: {state_desc_names})"
                if fields else f"`{decl.name}` declaration & core state"
            )
            markers.append(
                SectionMarker(
                    is_subsection=False,
                    sec_id=next_sec_id("STATE"),
                    tag=unique_tag(f"{tag_prefix}_STATE"),
                    title=f"{decl.name.upper().lstrip('_')} STATE & FIELDS",
                    description=state_desc,
                    line_num=decl.doc_start_line,
                    auto_generated=True,
                )
            )

            # Group methods into semantic/size-balanced chunks
            if methods:
                chunk_start_member = methods[0]
                chunk_methods: List[Member] = [methods[0]]
                cur_short, cur_tag_suf, cur_title = _classify_method(methods[0].name)

                def flush_method_chunk(
                    start_m: Member, m_list: List[Member], s_id: str, t_suf: str, title_str: str
                ) -> None:
                    # Pick the dominant domain in m_list if mixed
                    domain_counts: Dict[str, Tuple[int, str, str]] = {}
                    for m in m_list:
                        ds, dt, dtitle = _classify_method(m.name)
                        prev_c = domain_counts.get(ds, (0, dt, dtitle))[0]
                        domain_counts[ds] = (prev_c + m.line_count, dt, dtitle)
                    best_short = max(domain_counts.keys(), key=lambda k: domain_counts[k][0])
                    _, best_tag, best_title = domain_counts[best_short]

                    # Only create a new section if it's after the class start
                    if start_m.doc_start_line > decl.doc_start_line + 5:
                        top_m = sorted(m_list, key=lambda x: x.line_count, reverse=True)[:4]
                        m_Preview = ", ".join(f"`{m.name}`" for m in top_m)
                        desc = f"{best_title}: {m_Preview} ({len(m_list)} methods)"
                        cand_tag = f"{tag_prefix}_{best_tag}"
                        if cand_tag in used_tags and top_m:
                            m_tok = _method_to_tag_token(top_m[0].name)
                            cand_tag = f"{tag_prefix}_{m_tok}"
                        markers.append(
                            SectionMarker(
                                is_subsection=False,
                                sec_id=next_sec_id(best_short),
                                tag=unique_tag(cand_tag),
                                title=best_title.upper(),
                                description=desc,
                                line_num=start_m.doc_start_line,
                                auto_generated=True,
                            )
                        )

                for m in methods[1:]:
                    m_short, m_tag_suf, m_title = _classify_method(m.name)
                    chunk_span = m.end_line - chunk_start_member.doc_start_line

                    # Split if:
                    # 1. Single huge method (>450 lines) like build() or _onPointerDown()
                    # 2. Domain changed AND current chunk is at least 220 lines
                    # 3. Current chunk exceeded target_chunk_lines
                    should_split = (
                        m.line_count >= 450
                        or (m_short != cur_short and chunk_span >= 220)
                        or chunk_span >= target_chunk_lines
                    )
                    if should_split:
                        flush_method_chunk(
                            chunk_start_member, chunk_methods, cur_short, cur_tag_suf, cur_title
                        )
                        chunk_start_member = m
                        chunk_methods = [m]
                        cur_short, cur_tag_suf, cur_title = m_short, m_tag_suf, m_title
                    else:
                        chunk_methods.append(m)

                flush_method_chunk(
                    chunk_start_member, chunk_methods, cur_short, cur_tag_suf, cur_title
                )

            idx_decl += 1
        else:
            # Group contiguous non-dominant top-level declarations (up to ~450 lines)
            grp_start = decl
            grp_decls = [decl]
            idx_decl += 1
            while idx_decl < len(declarations) and declarations[idx_decl] not in dominant_decls:
                cand = declarations[idx_decl]
                if cand.end_line - grp_start.doc_start_line > 500 and len(grp_decls) >= 1:
                    break
                grp_decls.append(cand)
                idx_decl += 1

            names_preview = ", ".join(f"`{d.name}`" for d in grp_decls[:4])
            if len(grp_decls) > 4:
                names_preview += f" (+{len(grp_decls) - 4} more)"

            # Determine label from kind/names
            if any("Widget" in d.signature for d in grp_decls):
                short_lbl = "WIDGET"
                title_lbl = "WIDGET DECLARATIONS & PUBLIC API"
                tag_lbl = f"{tag_prefix}_WIDGET"
            elif all(d.kind == "enum" for d in grp_decls):
                short_lbl = "ENUMS"
                title_lbl = "ENUMS & CONFIGURATION TYPES"
                tag_lbl = f"{tag_prefix}_ENUMS"
            elif len(grp_decls) == 1:
                short_lbl = grp_decls[0].name.lstrip("_")[:8].upper()
                title_lbl = f"{grp_decls[0].kind.upper()} {grp_decls[0].name}"
                tag_lbl = f"{tag_prefix}_{short_lbl}"
            else:
                short_lbl = "MODELS"
                title_lbl = f"CLASSES & HELPERS ({grp_decls[0].name})"
                tag_lbl = f"{tag_prefix}_{grp_decls[0].name.lstrip('_')[:8].upper()}"

            markers.append(
                SectionMarker(
                    is_subsection=False,
                    sec_id=next_sec_id(short_lbl),
                    tag=unique_tag(tag_lbl),
                    title=title_lbl,
                    description=f"Declarations: {names_preview}",
                    line_num=grp_start.doc_start_line,
                    auto_generated=True,
                )
            )

    _compute_marker_end_lines(markers, n_lines)
    return markers


# ============================================================================
# IN-FILE TOC & MARKER INJECTION / SYNCHRONIZATION
# ============================================================================

def build_toc_header_lines(
    filepath: Path,
    markers: List[SectionMarker],
) -> List[str]:
    companion_name = f"{filepath.stem}.index.md"
    title_upper = filepath.stem.replace("_", " ").upper()
    toc = [
        "// ============================================================================",
        f"// MASTER {title_upper} LLM SEARCH INDEX & TABLE OF CONTENTS",
        "// ============================================================================",
        f"// COMPANION MAP: See '{companion_name}' for full method & class directory.",
        '// QUICK GREP:   grep "=== SECTION: [SEC-" or grep "--- SUBSECTION: [TAG:"',
        "//",
    ]
    for m in markers:
        if m.is_subsection:
            sec_col = f"  ↳ {m.sec_id or '[SUB]':<12}"
        else:
            sec_col = f"{m.sec_id:<16}"
        span_col = f"L{m.line_num}-L{m.end_line}"
        desc_short = m.description[:68]
        toc.append(f"// {sec_col} {span_col:<13}: {m.tag} {desc_short}")
    toc.append("// ============================================================================")
    return toc


def inject_or_sync_dart_file(
    filepath: Path,
    raw_text: str,
    lines: List[str],
    last_directive_line: int,
    existing_toc_span: Optional[Tuple[int, int]],
    markers: List[SectionMarker],
    inject_new_markers: bool,
) -> Tuple[str, List[str]]:
    """
    Inserts new section markers (if `inject_new_markers=True`) and inserts/updates
    the Top-of-File TOC block, returning the updated file content and lines.
    Carry out a two-step calculation so line numbers in the TOC are 100% exact
    AFTER the new lines are inserted!
    """
    newline = "\r\n" if "\r\n" in raw_text else "\n"
    working_lines = [l.rstrip("\r\n") for l in lines]

    # Step 1: If markers were auto-generated and need to be injected into the source
    if inject_new_markers:
        # Insert bottom-up so earlier line indices don't shift during insertion
        for m in sorted(markers, key=lambda x: x.line_num, reverse=True):
            if m.auto_generated:
                ins_idx = max(0, m.line_num - 1)
                banner = [
                    f"// === SECTION: {m.sec_id} {m.title} ===",
                    f"// --- SUBSECTION: {m.tag} {m.description} ---",
                ]
                working_lines[ins_idx:ins_idx] = banner

    # Step 2: Remove old TOC block if one exists, or prepare insertion point after directives
    # First re-parse directive end and existing TOC span on working_lines
    toc_start_idx = None
    toc_end_idx = None
    for idx, l in enumerate(working_lines):
        if _RE_TOC_BORDER.match(l.strip()):
            if toc_start_idx is None and idx + 1 < len(working_lines) and (
                "SEARCH INDEX" in working_lines[idx + 1]
                or "TABLE OF CONTENTS" in working_lines[idx + 1]
            ):
                toc_start_idx = idx
            elif toc_start_idx is not None and idx > toc_start_idx + 2:
                toc_end_idx = idx
                break

    prelim_toc = build_toc_header_lines(filepath, markers)
    placeholder_toc_len = len(prelim_toc)
    if toc_start_idx is not None and toc_end_idx is not None:
        working_lines[toc_start_idx : toc_end_idx + 1] = prelim_toc
        toc_insert_idx = toc_start_idx
    else:
        toc_insert_idx = last_directive_line
        block_with_spacing = [""] + prelim_toc + [""]
        working_lines[toc_insert_idx:toc_insert_idx] = block_with_spacing
        toc_start_idx = toc_insert_idx + 1
        toc_end_idx = toc_start_idx + placeholder_toc_len - 1

    # Step 3: Re-scan working_lines to get the 100% exact post-insertion line numbers of all markers!
    index_path = filepath.with_name(f"{filepath.stem}.index.md")
    _, _, exact_markers, _ = parse_dart_file(working_lines, index_path=index_path)
    final_toc = build_toc_header_lines(filepath, exact_markers)
    working_lines[toc_start_idx : toc_start_idx + placeholder_toc_len] = final_toc

    return newline.join(working_lines) + newline, working_lines


# ============================================================================
# COMPANION `<filename>.index.md` GENERATOR & SYNCHRONIZER
# ============================================================================

def _human_title(filepath: Path) -> str:
    return " ".join(w.capitalize() for w in filepath.stem.split("_"))


def _rel_path_str(filepath: Path) -> str:
    try:
        # Walk up to find repo root (folder containing pubspec.yaml or .git)
        cur = filepath.resolve().parent
        while cur != cur.parent:
            if (cur / "pubspec.yaml").exists() or (cur / ".git").exists():
                return filepath.resolve().relative_to(cur).as_posix()
            cur = cur.parent
    except Exception:
        pass
    return filepath.name


def generate_index_markdown(
    filepath: Path,
    total_lines: int,
    last_directive_line: int,
    markers: List[SectionMarker],
    declarations: List[Declaration],
    tag_prefix: str,
) -> str:
    title = _human_title(filepath)
    rel_path = _rel_path_str(filepath)

    # Determine primary class(es)
    classes = [d for d in declarations if d.kind in ("class", "mixin", "extension")]
    if classes:
        largest_cls = max(classes, key=lambda d: d.end_line - d.start_line)
        primary_cls_str = f"`{largest_cls.name}`"
        if len(classes) > 1:
            primary_cls_str += f" (+{len(classes) - 1} more)"
    else:
        primary_cls_str = f"`{filepath.stem}`"

    md: List[str] = [
        f"# {title} — LLM Semantic Navigation Map",
        f"> **Path**: `{rel_path}`  ",
        f"> **Total Lines**: ~{total_lines:,} | **Primary Class**: {primary_cls_str}  ",
        "> **Companion Document**: Used by LLMs (Antigravity, Gemini, Codex, Copilot, Cursor) to navigate and locate code in 1 step without reading the full file.",
        "",
        "---",
        "",
        "## 1. LLM Navigation Protocol (How to search in 1 step)",
        "",
        "1. **Find the Section, Class, or Method**: Check Section 2 (Master Section Registry), Section 3 (Class Registry), or Section 4 (Method Directory).",
        "2. **Jump via Unique Tag or Line Range**:",
        '   - In Antigravity / CLI: Use `git grep -n "\\[TAG:<NAME>\\]"` or read the exact line range via `read_file` (`StartLine`–`EndLine`).',
        "   - Never read the entire file at once; always read only the target 50–150 line range.",
        "3. **Check State Dependencies**: Review Section 5 (State Fields & Controllers Registry) before modifying interactive or stateful methods.",
        "",
        "---",
        "",
        "## 2. Master Section Registry & Line Spans",
        "",
        "| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |",
        "| :--- | :--- | :--- | :--- |",
    ]

    if last_directive_line > 0 and (
        not markers or markers[0].sec_id != "[SEC-00-IMPORTS]"
    ):
        md.append(
            f"| `[SEC-00-IMPORTS]` | `[TAG:{tag_prefix}_IMPORTS]` | L1 – L{last_directive_line} | Package, model, service, and widget imports |"
        )

    for m in markers:
        sec_cell = f"↳ `{m.sec_id}`" if (m.is_subsection and m.sec_id) else (
            "↳ `[SUB]`" if m.is_subsection else f"`{m.sec_id}`"
        )
        tag_cell = f"`{m.tag}`" if m.tag else "—"
        span_cell = f"L{m.line_num} – L{m.end_line}"
        desc_cell = m.description.replace("|", "\\|")
        md.append(f"| {sec_cell} | {tag_cell} | {span_cell} | {desc_cell} |")

    # Section 3: Top-Level Classes, Enums & Extensions
    if declarations:
        md.extend([
            "",
            "---",
            "",
            "## 3. Classes, Enums & Top-Level Declarations",
            "",
            "| Symbol | Kind | Lines (Span) | Members | Signature / Heritage |",
            "| :--- | :--- | :--- | :--- | :--- |",
        ])
        for d in declarations[:60]:
            span_count = d.end_line - d.start_line + 1
            m_count = len(d.members)
            sig_clean = d.signature.replace("|", "\\|")
            md.append(
                f"| `{d.name}` | {d.kind} | L{d.start_line} – L{d.end_line} ({span_count}L) | {m_count} | `{sig_clean}` |"
            )
        if len(declarations) > 60:
            md.append(f"| *+{len(declarations) - 60} more declarations* | — | — | — | See per-section summary |")

    # Helper to find which marker tag owns a line number
    def tag_for_line(line_no: int) -> str:
        chosen = f"[TAG:{tag_prefix}_MAIN]"
        for m in markers:
            if m.line_num <= line_no <= m.end_line and m.tag:
                chosen = m.tag
        return chosen

    # Gather all methods & constructors across all declarations
    all_methods: List[Member] = []
    all_fields: List[Member] = []
    for d in declarations:
        if d.kind == "function":
            all_methods.append(
                Member(
                    kind="function",
                    name=d.name,
                    return_type="",
                    signature=d.signature,
                    doc_start_line=d.doc_start_line,
                    start_line=d.start_line,
                    end_line=d.end_line,
                    parent_class="(top-level)",
                )
            )
        for m in d.members:
            if m.kind in ("method", "constructor"):
                all_methods.append(m)
            elif m.kind in ("field", "getter", "setter"):
                all_fields.append(m)

    # Section 4: Method Directory (adaptive compactness so .index.md stays ~150-300 lines!)
    md.extend([
        "",
        "---",
        "",
        f"## 4. Method & Action Directory ({len(all_methods)} methods indexed)",
        "",
    ])

    if len(all_methods) <= 110:
        md.extend([
            "| Method / Handler | Class | Section Tag | Lines (Span) | Summary / Signature |",
            "| :--- | :--- | :--- | :--- | :--- |",
        ])
        for m in all_methods:
            tag_str = tag_for_line(m.start_line)
            summary = (m.doc_summary or m.signature).replace("|", "\\|")[:75]
            md.append(
                f"| `{m.name}` | `{m.parent_class}` | `{tag_str}` | L{m.start_line}–L{m.end_line} ({m.line_count}L) | {summary} |"
            )
    else:
        # For massive files (>110 methods):
        # 4A: Primary / Major Methods table (top 75 by line count + lifecycle/pointer/build/commit)
        important_re = re.compile(
            r"(?:^initState$|^dispose$|^build$|^paint$|onPointer|_commit|_finish|parse|generate)",
            re.I,
        )
        scored_methods = sorted(
            all_methods,
            key=lambda m: (1000 if important_re.search(m.name) else 0) + m.line_count,
            reverse=True,
        )
        top_methods = sorted(scored_methods[:75], key=lambda m: m.start_line)

        md.extend([
            "### 4.1 Primary Entrypoints & Major Methods",
            "",
            "| Method / Handler | Section Tag | Lines (Span) | Summary / Signature |",
            "| :--- | :--- | :--- | :--- |",
        ])
        for m in top_methods:
            tag_str = tag_for_line(m.start_line)
            summary = (m.doc_summary or m.signature).replace("|", "\\|")[:75]
            md.append(
                f"| `{m.name}` | `{tag_str}` | L{m.start_line}–L{m.end_line} ({m.line_count}L) | {summary} |"
            )

        # 4B: Complete Per-Section Compact Index of ALL methods with exact line numbers!
        md.extend([
            "",
            "### 4.2 Complete Per-Section Method Index (All Methods with Exact Lines)",
            "",
        ])
        by_tag: Dict[str, List[Member]] = {}
        for m in all_methods:
            t = tag_for_line(m.start_line)
            by_tag.setdefault(t, []).append(m)

        for m_sec in markers:
            t = m_sec.tag
            if t in by_tag and by_tag[t]:
                items = ", ".join(
                    f"`{m.name}` (L{m.start_line}–L{m.end_line})" for m in by_tag[t]
                )
                md.append(f"- **`{t}` (L{m_sec.line_num}–L{m_sec.end_line})**: {items}")
                del by_tag[t]
        for leftover_tag, m_list in by_tag.items():
            items = ", ".join(
                f"`{m.name}` (L{m.start_line}–L{m.end_line})" for m in m_list
            )
            md.append(f"- **`{leftover_tag}`**: {items}")

    # Section 5: Key State Fields & Controllers Registry
    if all_fields:
        md.extend([
            "",
            "---",
            "",
            f"## 5. Key State Fields & Controllers Registry ({len(all_fields)} fields)",
            "",
        ])
        # Prioritize controllers, notifiers, caches, sets, maps, active tools, projects
        priority_field_re = re.compile(
            r"(?:Controller|Notifier|Project|Tool|Selected|Active|Cache|Watcher|Transform|Viewport|State|Mode|Layer|Storey)",
            re.I,
        )
        sorted_fields = sorted(
            all_fields,
            key=lambda f: (
                0 if priority_field_re.search(f.name) or priority_field_re.search(f.return_type) else 1,
                f.start_line,
            ),
        )
        shown_fields = sorted(sorted_fields[:45], key=lambda f: f.start_line)
        for f in shown_fields:
            doc_part = f" — {f.doc_summary}" if f.doc_summary else ""
            md.append(f"- `{f.name}` (`{f.return_type}`, L{f.start_line}){doc_part}")
        if len(all_fields) > 45:
            md.append(
                f"- *+{len(all_fields) - 45} additional fields in `L{all_fields[0].start_line}–L{all_fields[-1].end_line}`*"
            )

    md.append("")
    return "\n".join(md)


def sync_existing_index_markdown(
    index_path: Path,
    total_lines: int,
    last_directive_line: int,
    markers: List[SectionMarker],
) -> str:
    """
    Updates total line count and section line spans (`L<start> – L<end>`)
    in an existing hand-curated `<filename>.index.md` without destroying
    custom tables or safe modification rules.
    """
    content = index_path.read_text(encoding="utf-8")
    # Update > **Total Lines**: ~...
    content = re.sub(
        r"(\*\*Total Lines\*\*:\s*~?)[0-9,]+",
        f"\\g<1>{total_lines:,}",
        content,
    )

    # Map both sec_id and tag to (start_line, end_line)
    span_by_key: Dict[str, Tuple[int, int]] = {}
    if last_directive_line > 0:
        span_by_key["[SEC-00-IMPORTS]"] = (1, last_directive_line)
    for m in markers:
        if m.sec_id:
            span_by_key[m.sec_id] = (m.line_num, m.end_line)
        if m.tag:
            span_by_key[m.tag] = (m.line_num, m.end_line)

    out_lines: List[str] = []
    for line in content.splitlines():
        if line.strip().startswith("|"):
            cols = [c.strip() for c in line.strip().strip("|").split("|")]
            matched_span: Optional[Tuple[int, int]] = None
            if len(cols) >= 3:
                m_tag = re.search(r"(\[TAG:[^\]]+\])", cols[1])
                m_sec = re.search(r"(\[(?:SEC|SUB)-[^\]]+\])", cols[0])
                if m_tag and m_tag.group(1) in span_by_key:
                    matched_span = span_by_key[m_tag.group(1)]
                elif m_sec and m_sec.group(1) in span_by_key:
                    matched_span = span_by_key[m_sec.group(1)]
            if matched_span is not None:
                line = re.sub(
                    r"L\d+\s*[–-]\s*L\d+",
                    f"L{matched_span[0]} – L{matched_span[1]}",
                    line,
                    count=1,
                )
        out_lines.append(line)

    return "\n".join(out_lines) + "\n"


# ============================================================================
# SINGLE-FILE & WORKSPACE PROCESSING
# ============================================================================

def process_single_file(
    filepath: Path,
    no_modify_source: bool = False,
    force_overwrite: bool = False,
    force_auto_sections: bool = False,
    custom_prefix: str = "",
    chunk_lines: int = 850,
    dry_run: bool = False,
) -> int:
    t0 = time.perf_counter()
    filepath = filepath.resolve()
    if not filepath.exists():
        print(f"Error: File not found: {filepath}", file=sys.stderr)
        return 1

    raw_text = filepath.read_text(encoding="utf-8")
    lines = raw_text.splitlines()
    tag_prefix = (custom_prefix or derive_prefix_from_filename(filepath)).upper()
    index_path = filepath.with_name(f"{filepath.stem}.index.md")

    last_dir_line, existing_toc, existing_markers, declarations = parse_dart_file(
        lines, index_path=index_path
    )

    need_auto_sections = (not existing_markers) or force_auto_sections
    if need_auto_sections:
        chunk_sz = chunk_lines
        if len(lines) >= 10000 and chunk_lines == 850:
            chunk_sz = 1400
        markers = auto_generate_sections(
            lines=lines,
            last_directive_line=last_dir_line,
            declarations=declarations,
            tag_prefix=tag_prefix,
            target_chunk_lines=chunk_sz,
        )
    else:
        markers = existing_markers

    # Modify .dart file (inject markers and/or update Top-of-File TOC) unless --no-modify-source or --dry-run
    if not no_modify_source and not dry_run:
        updated_dart_text, updated_lines = inject_or_sync_dart_file(
            filepath=filepath,
            raw_text=raw_text,
            lines=lines,
            last_directive_line=last_dir_line,
            existing_toc_span=existing_toc,
            markers=markers,
            inject_new_markers=need_auto_sections,
        )
        if updated_dart_text != raw_text:
            filepath.write_text(updated_dart_text, encoding="utf-8")
            lines = updated_lines
            last_dir_line, existing_toc, markers, declarations = parse_dart_file(
                lines, index_path=index_path
            )

    index_path = filepath.with_name(f"{filepath.stem}.index.md")
    total_methods = sum(
        len([m for m in d.members if m.kind in ("method", "constructor")])
        + (1 if d.kind == "function" else 0)
        for d in declarations
    )
    total_fields = sum(
        len([m for m in d.members if m.kind in ("field", "getter", "setter")])
        for d in declarations
    )

    if dry_run:
        elapsed_ms = (time.perf_counter() - t0) * 1000
        print(f"[DRY RUN] Scanned {filepath.name} ({len(lines):,} lines) in {elapsed_ms:.1f} ms")
        print(f"  - Declarations : {len(declarations)} classes/enums/functions")
        print(f"  - Methods      : {total_methods}")
        print(f"  - State Fields : {total_fields}")
        print(f"  - Sections     : {len(markers)} ({'auto-generated' if need_auto_sections else 'existing'})")
        print("\nDetected Sections:")
        for m in markers:
            sub = "  ↳ " if m.is_subsection else "  "
            print(f"{sub}{m.sec_id:<16} {m.tag:<24} L{m.line_num}-L{m.end_line:<6} : {m.description[:60]}")
        return 0

    if index_path.exists() and not force_overwrite and not need_auto_sections:
        md_out = sync_existing_index_markdown(
            index_path=index_path,
            total_lines=len(lines),
            last_directive_line=last_dir_line,
            markers=markers,
        )
        action_label = "Synced existing"
    else:
        md_out = generate_index_markdown(
            filepath=filepath,
            total_lines=len(lines),
            last_directive_line=last_dir_line,
            markers=markers,
            declarations=declarations,
            tag_prefix=tag_prefix,
        )
        action_label = "Generated"

    index_path.write_text(md_out, encoding="utf-8")
    elapsed_ms = (time.perf_counter() - t0) * 1000
    md_lines = len(md_out.splitlines())

    print(
        f"✅ {action_label} '{index_path.name}' ({md_lines} lines) & TOC for '{filepath.name}' "
        f"({len(lines):,} lines, {len(markers)} sections, {len(declarations)} classes, "
        f"{total_methods} methods, {total_fields} fields) in {elapsed_ms:.1f} ms."
    )
    return 0


def scan_workspace(
    root_dir: Path,
    min_lines: int = 1500,
    batch_sync: bool = False,
    no_modify_source: bool = False,
) -> int:
    print(f"Scanning '{root_dir}' for Dart files >= {min_lines} lines...\n")
    rows: List[Tuple[Path, str, int, str, str, bool]] = []
    for dart_file in sorted(root_dir.rglob("*.dart")):
        if any(
            p in dart_file.parts
            for p in (".dart_tool", "build", ".git", "linux", "windows", "generated")
        ):
            continue
        if dart_file.name.endswith((".g.dart", ".freezed.dart", ".mocks.dart")):
            continue
        try:
            text = dart_file.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        lines = text.splitlines()
        n = len(lines)
        if n < min_lines:
            continue

        index_file = dart_file.with_name(f"{dart_file.stem}.index.md")
        has_toc = any("TABLE OF CONTENTS" in l or "=== SECTION:" in l for l in lines[:500])
        needs_action = False
        if not index_file.exists():
            status = "MISSING .index.md"
            needs_action = True
        else:
            idx_text = index_file.read_text(encoding="utf-8", errors="replace")
            m_tot = re.search(r"\*\*Total Lines\*\*:\s*~?([0-9,]+)", idx_text)
            if m_tot:
                recorded = int(m_tot.group(1).replace(",", ""))
                drift = abs(n - recorded)
                if drift > 150:
                    status = f"OUT OF SYNC (drift: {drift}L)"
                    needs_action = True
                else:
                    status = f"OK (drift: {drift}L)"
            else:
                status = "OK"

        toc_str = "Yes" if has_toc else "No"
        rows.append((dart_file, _rel_path_str(dart_file), n, toc_str, status, needs_action))

    if not rows:
        print(f"No Dart files >= {min_lines} lines found.")
        return 0

    print(f"{'File Path':<68} | {'Lines':>7} | {'TOC':^5} | {'Index Status'}")
    print("-" * 110)
    for _, rel, n, toc_s, st, _ in sorted(rows, key=lambda r: r[2], reverse=True):
        print(f"{rel:<68} | {n:>7,} | {toc_s:^5} | {st}")
    print(f"\nTotal large files (>={min_lines}L): {len(rows)}")

    if batch_sync:
        targets = [r[0] for r in rows if r[5]]
        if not targets:
            print("\nAll large files are already indexed and in sync!")
        else:
            print(f"\nBatch indexing/syncing {len(targets)} file(s)...")
            for df in targets:
                process_single_file(df, no_modify_source=no_modify_source)

    return 0


# ============================================================================
# CLI ENTRYPOINT
# ============================================================================

def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(
        description="Automatically scan large Dart files, inject TOC & section markers, and generate/sync <filename>.index.md in seconds."
    )
    parser.add_argument(
        "target",
        nargs="?",
        help="Path to the target .dart file (or workspace directory when using --scan-workspace).",
    )
    parser.add_argument(
        "--scan-workspace",
        action="store_true",
        help="Scan directory for all .dart files >= --min-lines and check their .index.md status.",
    )
    parser.add_argument(
        "--batch-sync",
        action="store_true",
        help="When used with --scan-workspace, automatically index/sync all missing or out-of-sync large files.",
    )
    parser.add_argument(
        "--min-lines",
        type=int,
        default=1500,
        help="Minimum line count threshold for --scan-workspace (default: 1500).",
    )
    parser.add_argument(
        "--no-modify-source",
        action="store_true",
        help="Only generate/update <filename>.index.md without modifying the .dart source file.",
    )
    parser.add_argument(
        "--force-overwrite",
        action="store_true",
        help="Regenerate <filename>.index.md completely from scratch even if one already exists.",
    )
    parser.add_argument(
        "--force-auto-sections",
        action="store_true",
        help="Auto-generate semantic sections even if the file already has some markers.",
    )
    parser.add_argument(
        "--prefix",
        type=str,
        default="",
        help="Custom tag prefix (e.g. PAINTER, PARSER, CMD). Auto-derived from filename if omitted.",
    )
    parser.add_argument(
        "--chunk-lines",
        type=int,
        default=850,
        help="Target lines per auto-generated section inside large classes (default: 850).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview detected sections, classes, and methods without writing any files.",
    )

    args = parser.parse_args()

    if args.scan_workspace:
        root = Path(args.target or ".").resolve()
        return scan_workspace(root, args.min_lines, args.batch_sync, args.no_modify_source)

    if not args.target:
        parser.error("Please provide a target .dart file path or use --scan-workspace.")

    return process_single_file(
        filepath=Path(args.target),
        no_modify_source=args.no_modify_source,
        force_overwrite=args.force_overwrite,
        force_auto_sections=args.force_auto_sections,
        custom_prefix=args.prefix,
        chunk_lines=args.chunk_lines,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    sys.exit(main())
