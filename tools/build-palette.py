#!/usr/bin/env python3
"""Write every PENUMBRA colour file from palette/palette.toml.

Each file under palette/templates/ is rendered with the dark palette ([colors]) to the same path in
the repository, with {{name}} replaced by that colour as #rrggbb, {{name:hex}} as rrggbb, {{name:rgb}}
as r,g,b and {{name:sgr}} as r;g;b (for terminal colour codes); share/penumbra/palette.py has the
rest of the syntax. penumbra-theme renders the same templates at run time.
`--check` only reports generated files that are out of date (exit status 1).
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
PALETTE = ROOT / 'palette' / 'palette.toml'
TEMPLATES = ROOT / 'palette' / 'templates'
sys.path.insert(0, str(ROOT / 'share' / 'penumbra'))
sys.dont_write_bytecode = True  # No __pycache__ in share/, which install.sh copies.
import palette  # noqa: E402  (share/penumbra/palette.py, shared with penumbra-theme)


def main():
    check = '--check' in sys.argv[1:]
    try:
        palettes = palette.load(PALETTE)
    except ValueError as error:
        sys.exit(str(error))
    stale = []
    for template in sorted(p for p in TEMPLATES.rglob('*') if p.is_file()):
        target = ROOT / template.relative_to(TEMPLATES)
        try:
            text = palette.render(template.read_text(), palettes, 'dark', template.relative_to(ROOT))
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
