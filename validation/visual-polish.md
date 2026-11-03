# Visual polish validation — 3 November 2026

The README gallery uses the actual updated Quickshell components and animated wallpaper
shaders in an isolated, nested Hyprland session. Captures are not composited mockups. The
session had its own HOME, configuration, state, D-Bus and Wayland sockets under `/tmp`;
the installed desktop configuration was not replaced. Account/network labels were replaced
with demonstration values in the capture copy. Firefox, Neovim and Lia Files opened local
sample content in the working-desktop capture.

## Coverage

| Check | Result |
|---|---|
| Penumbra, Solar Corona, Starlight | Live stills captured; matching animated textures and scene tint inspected |
| Shader surfaces | Glass edge, card lighting and eclipse aurora rendered in the nested session |
| 1920×1080 at 125% | Desktop, Control Center, launcher and light mode inspected |
| 1024×768 at 100%, text at 130% | Control Center, launcher and wallpaper gallery inspected; content remains within the output |
| Multiple outputs | Nested Wayland output plus a headless output; panels follow the focused monitor |
| Rapid interruption | Six cycles of opening/closing Control Center and launcher before animations finish; layer-shell input surfaces disappear after settling |
| Reduced motion | Toggled during the live sequence; regression test verifies active palette fades settle immediately |
| Icons | Real installed application logos in the launcher/dock; name/file/URL handling shared; lunar phase rendered without emoji |
| Motion | 60 fps source recorded; 24 fps, 960 px WebP supplied for a compact preview |

The live checks found an invalid QML `onAccent` color property despite a valid palette value.
Renaming the shell-facing token to `accentInk` restores white selection text in light mode.
`test_theme_render.py` checks both inks, interrupted fade continuity and reduced-motion settling.
`test_artwork.py` checks every preset's generated SVG, lock image, texture dimensions and layer
geometry. The palette tests cover contrast and preset selection.

The working-desktop capture also exposed obsolete Firefox toolbar token names. The stylesheet
now supplies the current names alongside the older names, checked against installed Firefox
CSS and [Mozilla's browser color definitions](https://github.com/mozilla-firefox/firefox/blob/main/browser/themes/shared/browser-colors.css).

The final Python suite passed all **91 tests**; the standalone Node runner passed all
**5 test files**. Generated palette/configuration/shader checks and `git diff --check` passed.

## Reproduce

```bash
python tools/build-wallpapers.py
python tools/build-palette.py
python tools/build-configuration.py
PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s tests -v
node --test tests/shell/*.test.mjs
python tools/preview-widgets.py
python tools/preview-widgets.py previews/widgets-light.png --light
python tools/preview-polish.py
```

For live screenshots on an installed desktop, use `penumbra-showcase --output previews`
and `penumbra-showcase --output previews --video 15`. The helper captures the selected output
and restores its temporary workspace. Choose the preset in Look before each capture; open
the Control Center and launcher with their normal shortcuts during recording.

These are visual/lifecycle checks, not a frame-pacing benchmark or a test on two physical
monitors. The isolated session had no PipeWire server, so audio-device behavior was not tested;
Qt emitted text-input focus warnings while overlays were rapidly reversed. No QML binding,
shader compilation or missing-texture errors remained in the final captures.
