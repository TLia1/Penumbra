#!/usr/bin/env python3
"""Write every PENUMBRA colour file from palette/palette.toml.

Each file under palette/templates/ is rendered to the same path in the repository, with
{{name}} replaced by that colour as #rrggbb, {{name:hex}} as rrggbb, {{name:rgb}} as r,g,b and {{name:sgr}} as r;g;b (for terminal colour codes).
`--check` only reports generated files that are out of date (exit status 1).
"""
from pathlib import Path
import re
import sys
import tomllib

ROOT = Path(__file__).resolve().parent.parent
PALETTE = ROOT / 'palette' / 'palette.toml'
TEMPLATES = ROOT / 'palette' / 'templates'
TOKEN = re.compile(r'\{\{\s*([A-Za-z]+)(?::(hex|rgb|sgr))?\s*\}\}')


def load_palette():
    colors = tomllib.loads(PALETTE.read_text())['colors']
    for name, value in colors.items():
        if not re.fullmatch(r'#[0-9a-f]{6}', value):
            sys.exit(f'{PALETTE}: {name} should be a lowercase #rrggbb colour, not {value!r}')
    return colors


def render(template, colors):
    def color(match):
        name, form = match.groups()
        if name not in colors:
            raise KeyError(f'{template.relative_to(ROOT)}: unknown colour {name!r}')
        value = colors[name]
        if form == 'hex':
            return value[1:]
        if form in ('rgb', 'sgr'):
            return (',' if form == 'rgb' else ';').join(str(int(value[i:i + 2], 16)) for i in (1, 3, 5))
        return value
    return TOKEN.sub(color, template.read_text())


def main():
    check = '--check' in sys.argv[1:]
    colors = load_palette()
    stale = []
    for template in sorted(p for p in TEMPLATES.rglob('*') if p.is_file()):
        target = ROOT / template.relative_to(TEMPLATES)
        try:
            text = render(template, colors)
        except KeyError as error:
            sys.exit(error.args[0])
        if target.exists() and target.read_text() == text:
            continue
        stale.append(target.relative_to(ROOT))
        if not check:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)
    for path in stale:
        print(f'{"out of date" if check else "wrote"}: {path}')
    return 1 if check and stale else 0


if __name__ == '__main__':
    sys.exit(main())
