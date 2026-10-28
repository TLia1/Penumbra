return {
  { 'nvim-tree/nvim-web-devicons', opts = {} },
  { 'nvim-tree/nvim-tree.lua', dependencies = { 'nvim-tree/nvim-web-devicons' }, opts = {
    view = { width = 32, side = 'left' },
    renderer = { group_empty = true, highlight_git = 'name' },
    update_focused_file = { enable = true },
    filters = { dotfiles = false, custom = { '^.git$' } },
    actions = { open_file = { quit_on_open = false } },
  } },
  { 'folke/which-key.nvim', opts = { preset = 'modern', delay = 350, spec = {
    { '<leader>f', group = 'Find' }, { '<leader>b', group = 'Buffers' },
    { '<leader>c', group = 'Code' }, { '<leader>g', group = 'Git' },
    { '<leader>w', group = 'Windows' },
  } } },
  { 'nvim-telescope/telescope.nvim', dependencies = { 'nvim-lua/plenary.nvim' }, opts = {
    defaults = { sorting_strategy = 'ascending', layout_config = { prompt_position = 'top' },
      file_ignore_patterns = { 'node_modules/', '%.git/' } },
    pickers = { find_files = { hidden = true } },
  } },
  { 'akinsho/bufferline.nvim', dependencies = { 'nvim-tree/nvim-web-devicons' }, opts = {
    options = { diagnostics = 'nvim_lsp', separator_style = 'thin',
      offsets = { { filetype = 'NvimTree', text = 'PENUMBRA · Files', text_align = 'center' } } },
  } },
  { 'nvim-lualine/lualine.nvim', opts = function()
    local c = require('penumbra.palette')
    return { options = { theme = {
      normal = { a = { fg = c.bg, bg = c.accent, gui = 'bold' }, b = { fg = c.fg, bg = c.raised }, c = { fg = c.muted, bg = c.panel } },
      insert = { a = { fg = c.bg, bg = c.green } },
      visual = { a = { fg = c.bg, bg = c.pink } },
      replace = { a = { fg = c.bg, bg = c.rose } },
      inactive = { a = { fg = c.muted, bg = c.panel }, b = { fg = c.muted, bg = c.panel }, c = { fg = c.muted, bg = c.panel } },
    }, globalstatus = true } }
  end },
  -- Treesitter parsers, so code is coloured by its structure. Building them needs tree-sitter-cli
  -- and a C compiler (both installed by ./install.sh); `:TSInstall LANGUAGE` adds more.
  { 'nvim-treesitter/nvim-treesitter', branch = 'main', lazy = false, build = ':TSUpdate', config = function()
    if vim.fn.executable('tree-sitter') == 1 then
      require('nvim-treesitter').install({ 'bash', 'c', 'css', 'go', 'html', 'javascript', 'json', 'lua',
        'markdown', 'markdown_inline', 'python', 'qmljs', 'rust', 'toml', 'typescript', 'yaml' })
    end
    vim.api.nvim_create_autocmd('FileType', { callback = function(ev)
      -- Treesitter colours and indents wherever a parser is installed; Vim's syntax files elsewhere.
      if pcall(vim.treesitter.start, ev.buf) then
        vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end })
  end },
  { 'lewis6991/gitsigns.nvim', opts = {} },
  { 'windwp/nvim-autopairs', opts = {} },
  { 'mason-org/mason.nvim', opts = { ui = { border = 'rounded' } } },
  { 'neovim/nvim-lspconfig', dependencies = { 'mason-org/mason.nvim' }, config = function()
    -- Enable only installed servers; Mason adds its executables to PATH.
    local servers = {
      lua_ls = 'lua-language-server', pyright = 'pyright-langserver',
      ts_ls = 'typescript-language-server', bashls = 'bash-language-server',
      clangd = 'clangd', rust_analyzer = 'rust-analyzer', gopls = 'gopls',
    }
    vim.lsp.config('lua_ls', { settings = { Lua = { diagnostics = { globals = { 'vim' } } } } })
    for server, executable in pairs(servers) do
      if vim.fn.executable(executable) == 1 then vim.lsp.enable(server) end
    end
    vim.api.nvim_create_autocmd('LspAttach', { callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client:supports_method('textDocument/completion') then
        vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
      end
    end })
  end },
}
