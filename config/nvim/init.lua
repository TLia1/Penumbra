vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
local o = vim.opt
o.termguicolors = true
o.number = true
o.relativenumber = true
o.mouse = 'a'
o.clipboard = 'unnamedplus'
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.signcolumn = 'yes'
o.cursorline = true
o.wrap = false
o.scrolloff = 6
o.splitright = true
o.splitbelow = true
o.undofile = true
o.updatetime = 250
o.timeoutlen = 400
o.completeopt = { 'menu', 'menuone', 'noselect' }
o.laststatus = 3
vim.cmd.colorscheme('nocturne')
local path = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(path) then
  local result = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', path })
  if vim.v.shell_error ~= 0 then
    vim.notify('Plugin download failed. Check your connection and restart Neovim.\n' .. result, vim.log.levels.ERROR)
    return
  end
end
vim.opt.rtp:prepend(path)
require('lazy').setup('nocturne.plugins', {
  change_detection = { notify = false },
  checker = { enabled = false },
  local_spec = false,
  ui = { border = 'rounded' },
})
require('nocturne.keys')
vim.diagnostic.config({ virtual_text = false, float = { border = 'rounded' }, severity_sort = true })
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    if #vim.api.nvim_list_uis() == 0 or vim.fn.argc() > 1 then return end
    local arg = vim.fn.argv(0)
    if vim.fn.argc() == 0 or vim.fn.isdirectory(arg) == 1 then
      if vim.fn.isdirectory(arg) == 1 then vim.cmd.cd(vim.fn.fnameescape(arg)) end
      require('nvim-tree.api').tree.open()
    end
  end,
})
