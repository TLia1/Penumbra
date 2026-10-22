-- Original Nocturne palette, shared with the desktop.
vim.cmd('highlight clear')
if vim.g.syntax_on then vim.cmd('syntax reset') end
vim.o.background = 'dark'
vim.g.colors_name = 'nocturne'
local c = { bg = '#0d0a12', panel = '#100d18', raised = '#1b1526', border = '#352a46',
  violet = '#b69af7', fg = '#e4dced', muted = '#8f809f', green = '#a6d4bc',
  rose = '#ed9cad', gold = '#e5c49a', blue = '#a3c5e9', pink = '#d5a4dc' }
local groups = {
  Normal = { fg = c.fg, bg = c.bg }, NormalNC = { fg = c.fg, bg = c.bg },
  NormalFloat = { fg = c.fg, bg = c.panel }, FloatBorder = { fg = c.violet, bg = c.panel },
  FloatTitle = { fg = c.violet, bg = c.panel, bold = true },
  CursorLine = { bg = c.raised }, CursorLineNr = { fg = c.violet, bold = true },
  LineNr = { fg = c.muted }, SignColumn = { bg = c.bg }, EndOfBuffer = { fg = c.border },
  WinSeparator = { fg = c.border }, Visual = { bg = '#3d2d54' },
  Search = { fg = c.bg, bg = c.gold }, IncSearch = { fg = c.bg, bg = c.violet },
  Pmenu = { fg = c.fg, bg = c.panel }, PmenuSel = { fg = c.bg, bg = c.violet },
  PmenuSbar = { bg = c.raised }, PmenuThumb = { bg = c.muted },
  StatusLine = { fg = c.fg, bg = c.panel }, StatusLineNC = { fg = c.muted, bg = c.panel },
  TabLine = { fg = c.muted, bg = c.panel }, TabLineSel = { fg = c.violet, bg = c.raised, bold = true },
  TabLineFill = { bg = c.panel }, Directory = { fg = c.violet },
  Title = { fg = c.violet, bold = true }, Comment = { fg = c.muted, italic = true },
  Constant = { fg = c.gold }, String = { fg = c.green }, Character = { fg = c.green },
  Number = { fg = c.gold }, Boolean = { fg = c.gold }, Float = { fg = c.gold },
  Identifier = { fg = c.fg }, Function = { fg = c.blue }, Statement = { fg = c.violet },
  Keyword = { fg = c.violet }, Operator = { fg = c.pink }, PreProc = { fg = c.pink },
  Type = { fg = c.gold }, Special = { fg = c.pink }, Delimiter = { fg = c.muted },
  Underlined = { fg = c.blue, underline = true }, Todo = { fg = c.gold, bold = true },
  Error = { fg = c.rose }, ErrorMsg = { fg = c.rose }, WarningMsg = { fg = c.gold },
  MatchParen = { fg = c.violet, bg = c.border, bold = true }, NonText = { fg = c.border },
  Folded = { fg = c.muted, bg = c.panel }, FoldColumn = { fg = c.muted },
  DiffAdd = { bg = '#1c3029' }, DiffDelete = { bg = '#38202d' },
  DiffChange = { bg = '#27243f' }, DiffText = { bg = '#403457' },
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
}
for name, value in pairs(groups) do vim.api.nvim_set_hl(0, name, value) end
for _, severity in ipairs({ 'Error', 'Warn', 'Info', 'Hint' }) do
  vim.api.nvim_set_hl(0, 'DiagnosticUnderline' .. severity, { sp = groups['Diagnostic' .. severity].fg, undercurl = true })
end
local terminal = { c.panel, c.rose, c.green, c.gold, c.violet, c.pink, c.blue, c.fg,
  c.muted, '#f5b4c1', '#bce6ce', '#f2d7b3', '#cbb4ff', '#e6bce9', '#bddbf5', '#f7f0ff' }
for i, color in ipairs(terminal) do vim.g['terminal_color_' .. (i - 1)] = color end
