"""Validate the SVG library and rebuild its source/command inventory.

Run after updating command UI: python tools/verify_command_icons.py
"""
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

from generate_command_icons import ICONS, ROOT, camel, message


def argument_end(source, opening):
    """Find a Dart call's end while ignoring quoted text and comments."""
    token = re.compile(r"//[^\n]*|/\*.*?\*/|r?(?:'''[\s\S]*?'''|\"\"\"[\s\S]*?\"\"\"|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\")|[()]", re.S)
    depth = 0
    for match in token.finditer(source, opening):
        if match[0] == '(':
            depth += 1
        elif match[0] == ')':
            depth -= 1
            if depth == 0:
                return match.end()
    raise ValueError('Unbalanced command call')


def verify():
    arbs = {lang: json.loads((ROOT / f'lib/l10n/app_{lang}.arb').read_text(encoding='utf-8')) for lang in ('en', 'bg')}
    ids = {camel(name): name for name in ICONS}
    references = {name: [] for name in ICONS}
    sites = []
    for file in sorted((ROOT / 'lib').rglob('*.dart')):
        if 'generated' in file.parts or 'icons' in file.parts:
            continue
        source = file.read_text(encoding='utf-8')
        relative = file.relative_to(ROOT).as_posix()
        for match in re.finditer(r'\bAppIconId\.(\w+)', source):
            assert match[1] in ids, f'{relative}: unknown icon {match[1]}'
            references[ids[match[1]]].append(dict(file=relative, line=source.count('\n', 0, match.start()) + 1))
        for match in re.finditer(r'\b(AppIcon(?:\.fromMaterial)?|AppMenuLabel|BimEditingSymbol)\s*\(', source):
            end = argument_end(source, match.end() - 1)
            call = source[match.start():end]
            sites.append(dict(file=relative, line=source.count('\n', 0, match.start()) + 1,
                              widget=match[1], icons=sorted(set(re.findall(r'\bAppIconId\.(\w+)', call))),
                              expression=re.sub(r'\s+', ' ', call)[:240],
                              localization=sorted(set(re.findall(r'\b(?:l|l10n|context\.l10n)\.(\w+)', call)))))
    for name, spec in ICONS.items():
        file = ROOT / f'assets/icons/commands/{name}.svg'
        element = ET.parse(file).getroot()
        assert element.attrib['viewBox'] == '0 0 24 24', name
        assert element.attrib['stroke'] == 'currentColor', name
        for child in element.iter():
            assert child.tag.split('}')[-1] in {'svg', 'g', 'path', 'rect', 'circle', 'line', 'ellipse', 'polygon', 'polyline'}, name
            assert not any('href' in key or 'url(' in value for key, value in child.attrib.items()), name
        for lang, arb in arbs.items():
            assert isinstance(arb.get(message(name)), str) and arb[message(name)].strip(), (name, lang)
    for key in arbs['en']:
        if key.startswith(('commandIcon', 'commandUi', 'commandOption')):
            assert key in arbs['bg'], key
            assert set(re.findall(r'\{(\w+)\}', arbs['en'][key])) == set(re.findall(r'\{(\w+)\}', arbs['bg'][key])), key
    actual = {file.stem for file in (ROOT / 'assets/icons/commands').glob('*.svg')}
    assert actual == set(ICONS), 'Orphan or missing SVG assets'
    inventory = dict(
        assets=[dict(id=camel(name), asset=f'assets/icons/commands/{name}.svg',
                     arbMessage=message(name), labels={lang:arb[message(name)] for lang,arb in arbs.items()},
                     references=references[name]) for name, spec in sorted(ICONS.items())],
        commandSites=sites,
        legacyAliasSource='tools/command_icon_material_aliases.json',
    )
    (ROOT / 'docs/command-icon-inventory.json').write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Validated {len(ICONS)} SVGs, both locales, and {len(sites)} command presentation sites.')


if __name__ == '__main__':
    verify()
