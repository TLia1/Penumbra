-- Original Penumbra palette, shared with the desktop (lua/penumbra/palette.lua is generated from
-- palette/palette.toml).
vim.cmd('highlight clear')
if vim.g.syntax_on then vim.cmd('syntax reset') end
vim.o.background = 'dark'
vim.g.colors_name = 'penumbra'
package.loaded['penumbra.palette'] = nil
local c = require('penumbra.palette')
local groups = {
  Normal = { fg = c.fg, bg = c.bg }, NormalNC = { fg = c.fg, bg = c.bg },
  NormalFloat = { fg = c.fg, bg = c.panel }, FloatBorder = { fg = c.violet, bg = c.panel },
  FloatTitle = { fg = c.violet, bg = c.panel, bold = true },
  CursorLine = { bg = c.raised }, CursorLineNr = { fg = c.violet, bold = true },
  LineNr = { fg = c.muted }, SignColumn = { bg = c.bg }, EndOfBuffer = { fg = c.border },
  WinSeparator = { fg = c.border }, Visual = { bg = c.selection },
  Search = { fg = c.bg, bg = c.gold }, IncSearch = { fg = c.bg, bg = c.violet }, CurSearch = { fg = c.bg, bg = c.violet },
  Pmenu = { fg = c.fg, bg = c.panel }, PmenuSel = { fg = c.bg, bg = c.violet },
  PmenuSbar = { bg = c.raised }, PmenuThumb = { bg = c.muted },
  StatusLine = { fg = c.fg, bg = c.panel }, StatusLineNC = { fg = c.muted, bg = c.panel },
  TabLine = { fg = c.muted, bg = c.panel }, TabLineSel = { fg = c.violet, bg = c.raised, bold = true },
  TabLineFill = { bg = c.panel }, Directory = { fg = c.violet },
  Title = { fg = c.violet, bold = true }, Comment = { fg = c.dim, italic = true },
  Constant = { fg = c.gold }, String = { fg = c.green }, Character = { fg = c.green },
  Number = { fg = c.gold }, Boolean = { fg = c.gold }, Float = { fg = c.gold },
  Identifier = { fg = c.fg }, Function = { fg = c.blue }, Statement = { fg = c.violet },
  Keyword = { fg = c.violet }, Operator = { fg = c.pink }, PreProc = { fg = c.pink },
  Type = { fg = c.gold }, Special = { fg = c.pink }, Delimiter = { fg = c.muted },
  Underlined = { fg = c.blue, underline = true }, Todo = { fg = c.gold, bold = true },
  Error = { fg = c.rose }, ErrorMsg = { fg = c.rose }, WarningMsg = { fg = c.gold },
  MatchParen = { fg = c.violet, bg = c.border, bold = true }, NonText = { fg = c.border },
  Folded = { fg = c.muted, bg = c.panel }, FoldColumn = { fg = c.muted },
  DiffAdd = { bg = c.diffAdd }, DiffDelete = { bg = c.diffDelete },
  DiffChange = { bg = c.diffChange }, DiffText = { bg = c.diffText },
  GitSignsAdd = { fg = c.green }, GitSignsChange = { fg = c.violet }, GitSignsDelete = { fg = c.rose },
  DiagnosticError = { fg = c.rose }, DiagnosticWarn = { fg = c.gold },
  DiagnosticInfo = { fg = c.blue }, DiagnosticHint = { fg = c.violet },
  NvimTreeNormal = { fg = c.fg, bg = c.panel }, NvimTreeNormalNC = { fg = c.fg, bg = c.panel },
  NvimTreeEndOfBuffer = { fg = c.panel, bg = c.panel },
  NvimTreeRootFolder = { fg = c.violet, bold = true }, NvimTreeFolderName = { fg = c.violet },
  NvimTreeOpenedFolderName = { fg = c.pink, bold = true }, NvimTreeFolderIcon = { fg = c.violet },
  TelescopeBorder = { fg = c.border }, TelescopeSelection = { bg = c.raised },
  TelescopeMatching = { fg = c.violet, bold = true },
  WhichKey = { fg = c.violet }, WhichKeyGroup = { fg = c.blue }, WhichKeyDesc = { fg = c.fg },

  -- Treesitter captures (`:Inspect` shows them under the cursor). Unlisted ones fall back to
  -- Neovim's links to the classic groups above.
  ['@variable'] = { fg = c.fg }, ['@variable.builtin'] = { fg = c.pink, italic = true },
  ['@variable.parameter'] = { fg = c.soft }, ['@variable.member'] = { fg = c.soft },
  ['@property'] = { fg = c.soft }, ['@constant'] = { fg = c.gold }, ['@constant.builtin'] = { fg = c.gold, italic = true },
  ['@module'] = { fg = c.cyan }, ['@label'] = { fg = c.cyan },
  ['@string'] = { fg = c.green }, ['@string.escape'] = { fg = c.pink }, ['@string.regexp'] = { fg = c.pink },
  ['@string.special.url'] = { fg = c.blue, underline = true },
  ['@character'] = { fg = c.green }, ['@number'] = { fg = c.gold }, ['@boolean'] = { fg = c.gold },
  ['@type'] = { fg = c.gold }, ['@type.builtin'] = { fg = c.gold, italic = true },
  ['@attribute'] = { fg = c.cyan }, ['@function'] = { fg = c.blue }, ['@function.builtin'] = { fg = c.blue, italic = true },
  ['@function.method'] = { fg = c.blue }, ['@constructor'] = { fg = c.gold },
  ['@keyword'] = { fg = c.violet }, ['@keyword.function'] = { fg = c.violet, italic = true },
  ['@keyword.return'] = { fg = c.violet, bold = true }, ['@keyword.import'] = { fg = c.pink },
  ['@operator'] = { fg = c.pink }, ['@punctuation'] = { fg = c.muted }, ['@punctuation.bracket'] = { fg = c.muted },
  ['@punctuation.delimiter'] = { fg = c.muted }, ['@punctuation.special'] = { fg = c.pink },
  ['@comment'] = { fg = c.dim, italic = true }, ['@comment.todo'] = { fg = c.gold, bold = true },
  ['@comment.error'] = { fg = c.rose, bold = true }, ['@comment.warning'] = { fg = c.gold, bold = true },
  ['@tag'] = { fg = c.violet }, ['@tag.attribute'] = { fg = c.cyan }, ['@tag.delimiter'] = { fg = c.muted },
  ['@markup.heading'] = { fg = c.violet, bold = true }, ['@markup.strong'] = { bold = true },
  ['@markup.italic'] = { italic = true }, ['@markup.link'] = { fg = c.blue }, ['@markup.link.url'] = { fg = c.blue, underline = true },
  ['@markup.raw'] = { fg = c.green }, ['@markup.list'] = { fg = c.pink }, ['@markup.quote'] = { fg = c.muted, italic = true },
  ['@diff.plus'] = { fg = c.green }, ['@diff.minus'] = { fg = c.rose }, ['@diff.delta'] = { fg = c.violet },
  -- Language servers' semantic tokens use the same colours.
  ['@lsp.type.namespace'] = { link = '@module' }, ['@lsp.type.parameter'] = { link = '@variable.parameter' },
  ['@lsp.type.property'] = { link = '@property' }, ['@lsp.type.enumMember'] = { link = '@constant' },
  ['@lsp.type.macro'] = { link = '@constant' }, ['@lsp.mod.deprecated'] = { strikethrough = true },
}
for name, value in pairs(groups) do vim.api.nvim_set_hl(0, name, value) end
for _, severity in ipairs({ 'Error', 'Warn', 'Info', 'Hint' }) do
  vim.api.nvim_set_hl(0, 'DiagnosticUnderline' .. severity, { sp = groups['Diagnostic' .. severity].fg, undercurl = true })
end
for i, color in ipairs(c.terminal) do vim.g['terminal_color_' .. (i - 1)] = color end
