# Neovim coding workspace

Neovim has an original Penumbra colorscheme with Treesitter highlighting, a left
file explorer, clickable open-file tabs, fuzzy file/text search, Git change
markers, a status bar and shortcut hints. Requires Neovim 0.12 or newer. Plugin versions are recorded in
`config/nvim/lazy-lock.json`. Initial plugin installation needs GitHub access.

Editor backgrounds inherit the terminal's transparency. Set `vim.g.penumbra_transparent = false`
before loading the colour scheme for an opaque editor; floating menus keep their solid backgrounds.

## Install and open a project

Install only the editor setup (backs up any existing Neovim configuration):

```bash
./tools/install-neovim.sh
nvim /path/to/project
```

The full desktop installer also includes this configuration and the packages
`neovim git ripgrep wl-clipboard unzip nodejs npm tree-sitter-cli gcc`. For an editor-only installation,
install missing dependencies with `sudo pacman -S --needed` followed by those
package names. Open Neovim from your project's root, or pass its directory.
A directory launch opens the file tree. An empty launch shows the Penumbra dashboard: `f` finds
a file, `r` opens recent files, `n` starts a new buffer, and `c` opens the configuration.

Press `i` to type, then `Esc` to return to normal mode. In normal mode, press
**Space and wait** for shortcut hints. Press `Space ?` for the full menu.

## Keyboard shortcuts

| Shortcut (normal mode) | Action |
|---|---|
| Space e | Toggle the left file tree |
| Space o | Reveal current file in the tree |
| Ctrl+p / Space Space | Find a project file |
| Space f g | Search text across the project |
| Space f b | Choose an open file |
| Shift+h / Shift+l | Previous / next open file |
| Space b d | Close current file, protecting unsaved changes |
| Ctrl+s / Space s | Save |
| Space w h/j/k/l | Move between editor panes and the tree |
| Space w v / Space w s | Vertical / horizontal split |
| Space g p | Preview the Git change under the cursor |
| Space c m | Install language tools with Mason |
| gd / K | Definition / documentation (requires a language server) |
| Space c r / Space c a | Rename symbol / code action |
| Space c f | Format using an attached server that supports formatting |
| Space t | Open a terminal; double-Esc returns to normal mode |
| Space p | Plugin manager |
| Space q | Quit, asking about unsaved files |

In the tree, Enter opens files or expands folders; `a` creates, `r` renames,
and `g?` shows tree-specific help. Dotfiles are shown; `.git` is hidden.

## Language tools and completion

Open Mason with `Space c m`, select a server and press `i`, then restart Neovim. This setup automatically enables
installed `lua-language-server`, `pyright`, `typescript-language-server`,
`bash-language-server`, `clangd`, `rust-analyzer` and `gopls`. Servers can also be
installed with your system package manager. Node-based servers require Node/npm;
other servers may require their language runtime. No language servers are bundled.
With a server attached, completion appears as you type; Ctrl+n / Ctrl+p select
suggestions and Ctrl+y accepts. Without one, Ctrl+n still offers buffer words.
Code is coloured by Treesitter: parsers for Bash, C, CSS, Go, HTML, JavaScript,
JSON, Lua, Markdown, Python, QML, Rust, TOML, TypeScript and YAML are compiled
in the background on the first start (this needs `tree-sitter-cli` and a C
compiler); `:TSInstall LANGUAGE` adds others, and other files fall back to
Vim's syntax highlighting. Commenting (`gcc`) works everywhere. No automatic
formatting on save is enabled. Put your own settings in
`~/.config/nvim/lua/user.lua`, which the installers never replace.

## Plugin versions and recovery

Use `:Lazy restore` to return plugins to the recorded versions and `:Lazy update` to update them. The standalone installer prints a backup directory;
to undo, move the installed `~/.config/nvim` aside and restore its saved `nvim`
directory, if one existed. Plugin downloads live separately in
`~/.local/share/nvim/lazy`.

Plugin references: [lazy.nvim installation](https://lazy.folke.io/installation),
[nvim-tree](https://github.com/nvim-tree/nvim-tree.lua),
[nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), and
[which-key](https://github.com/folke/which-key.nvim).
