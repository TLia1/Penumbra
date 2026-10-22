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
      offsets = { { filetype = 'NvimTree', text = 'NOCTURNE · Files', text_align = 'center' } } },
  } },
  { 'nvim-lualine/lualine.nvim', opts = {
    options = { theme = {
      normal = { a = { fg = '#0d0a12', bg = '#b69af7', gui = 'bold' }, b = { fg = '#e4dced', bg = '#292035' }, c = { fg = '#8f809f', bg = '#100d18' } },
      insert = { a = { fg = '#0d0a12', bg = '#a6d4bc' } },
      visual = { a = { fg = '#0d0a12', bg = '#d5a4dc' } },
      replace = { a = { fg = '#0d0a12', bg = '#ed9cad' } },
      inactive = { a = { fg = '#8f809f', bg = '#100d18' }, b = { fg = '#8f809f', bg = '#100d18' }, c = { fg = '#8f809f', bg = '#100d18' } },
    }, globalstatus = true },
  } },
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
