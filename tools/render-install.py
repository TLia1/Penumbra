"""Prepare the stock files in the user's selected palette before comparing install destinations."""
from pathlib import Path
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
import os
import shutil
import subprocess
import sys

root, stage = map(Path, sys.argv[1:])
# Only load the renderer shipped with this checkout. Its colour choices come from the live user.
sys.dont_write_bytecode = True
sys.path.insert(0, str(root / 'share/penumbra'))
import palette

def helper(name):
    loader = SourceFileLoader(name, str(root / 'bin' / name))
    module = module_from_spec(spec_from_loader(name, loader))
    loader.exec_module(module)
    return module


for name in ('config', 'apps', 'share'):
    shutil.copytree(root / name, stage / name)

theme = helper('penumbra-theme')
theme.SHARE = root / 'share/penumbra'
theme.CACHE = stage / 'cache'
choice = theme.load()
picked = theme.accent(choice)
mode = theme.shown_mode(choice)
palettes = theme.resolved_palettes(choice, picked, root / 'palette/palette.toml')
for template in (root / 'palette/templates').rglob('*'):
    rel = template.relative_to(root / 'palette/templates')
    if not template.is_file() or rel.as_posix().startswith(theme.SKIPPED):
        continue
    dest = stage / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(palette.render(template.read_text(), palettes, mode, rel.as_posix()))

theme.ICONS = root / 'share/icons/Penumbra'
theme.ICONS_LIVE = stage / 'share/icons/Penumbra'
theme.recolor_icons(picked)
theme.write_gtk_mode(stage / 'config', mode)

# The installed corner helper edits both generated colours and application-specific CSS.
state = theme.STATE / 'corners'
env = dict(os.environ, HOME=str(stage), XDG_CONFIG_HOME=str(stage / 'config'),
           XDG_STATE_HOME=str(stage / '.local/state'), MANGO_INSTANCE_SIGNATURE='')
if state.exists():
    dest = stage / '.local/state/penumbra/corners'
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(state, dest)
subprocess.run([root / 'bin/penumbra-corners', 'restore'], env=env, check=True)
# Lia Files is optional, so render its corners alongside its app configuration.
app_config = stage / 'apps/lia-files/config'
subprocess.run([root / 'bin/penumbra-corners', 'restore'], env={**env, 'XDG_CONFIG_HOME': str(app_config)}, check=True)

# The proposed settings are passed on disk so a preview can render them before saving.
settings = helper('penumbra-settings')
settings.SETTINGS = stage.parent / 'settings.conf'
values = settings.load()
(stage / 'config/mango/settings.conf').write_text(settings.mango_settings(values))
idle = stage / 'config/penumbra/swayidle.conf'
idle.parent.mkdir(parents=True, exist_ok=True)
idle.write_text(settings.idle_config(values))
