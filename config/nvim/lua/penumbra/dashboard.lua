-- A native start buffer: no new plugin, downloads or background work.
local M = {}
function M.open()
  if vim.bo.modified or vim.api.nvim_buf_get_name(0) ~= '' or vim.bo.buftype ~= '' then return end
  if vim.api.nvim_buf_line_count(0) ~= 1 or vim.api.nvim_get_current_line() ~= '' then return end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'penumbra'
  vim.bo[buf].modifiable = false
  local win = vim.api.nvim_get_current_win()
  local saved = { number = vim.wo.number, relativenumber = vim.wo.relativenumber,
    cursorline = vim.wo.cursorline, signcolumn = vim.wo.signcolumn }
  vim.wo.number, vim.wo.relativenumber, vim.wo.cursorline, vim.wo.signcolumn = false, false, false, 'no'
  local ns = vim.api.nvim_create_namespace('penumbra-dashboard')
  local function draw()
    if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then return end
    local width = vim.api.nvim_win_get_width(win)
    local lines = { '', '◯  ──────  ◌', '', 'P E N U M B R A', 'A quiet place to make things.', '',
      '[f]  Find file', '[r]  Recent files', '[n]  New file', '[c]  Configuration', '[q]  Quit', '',
      vim.fn.fnamemodify(vim.fn.getcwd(), ':~') }
    for i, line in ipairs(lines) do
      lines[i] = string.rep(' ', math.max(0, math.floor((width - vim.fn.strdisplaywidth(line)) / 2))) .. line
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, row in ipairs({ 1, 3 }) do
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { end_row = row + 1, hl_group = 'Title' })
    end
    for _, row in ipairs({ 4, 12 }) do
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { end_row = row + 1, hl_group = 'Comment' })
    end
  end
  local actions = {
    f = function() require('telescope.builtin').find_files() end,
    r = function() require('telescope.builtin').oldfiles() end,
    n = function() vim.cmd.enew(); vim.cmd.startinsert() end,
    c = function() vim.cmd.edit(vim.fn.fnameescape(vim.fn.stdpath('config') .. '/init.lua')) end,
    q = function() vim.cmd.quit() end,
  }
  for key, action in pairs(actions) do vim.keymap.set('n', key, action, { buffer = buf, silent = true }) end
  local resize = vim.api.nvim_create_autocmd('VimResized', { callback = draw })
  vim.api.nvim_create_autocmd('BufWinLeave', { buffer = buf, once = true, callback = function()
    if vim.api.nvim_win_is_valid(win) then
      for name, value in pairs(saved) do vim.wo[win][name] = value end
    end
  end })
  vim.api.nvim_create_autocmd('BufWipeout', { buffer = buf, once = true, callback = function()
    pcall(vim.api.nvim_del_autocmd, resize)
  end })
  draw()
end
return M
