-- nvim --headless -u NONE --cmd 'set rtp+=.' -l tests/lazygit.lua
vim.opt.rtp:prepend('.')
local n = require('nterm')
n.setup()

local function buf_map(lhs, mode)
  local m = vim.fn.maparg(lhs, mode, false, true)
  return m.buffer == 1
end

-- a program terminal only takes the keys needed to leave it
n.run('sleep 30')
assert(buf_map('<C-/>', 't') and buf_map('<C-.>', 't'), 'app terminal keeps hide/cycle keys')
assert(not buf_map('<C-b>', 't') and not buf_map('<Esc><Esc>', 't') and not buf_map('<C-q>', 't'),
  'app terminal must not take Ctrl-b / Esc Esc / Ctrl-q')
n.new()
assert(buf_map('<C-b>', 't') and buf_map('<Esc><Esc>', 't'), 'shell terminal keeps all keys')

-- lazygit is reused instead of opened twice
if vim.fn.executable('lazygit') == 1 then
  n.lazygit()
  local lg = vim.api.nvim_get_current_buf()
  n.select(1)
  n.lazygit()
  assert(vim.api.nvim_get_current_buf() == lg, 'second lazygit() should reuse the running one')
end

-- edit() hides Nterm and opens the file at the line
local file = vim.fn.tempname()
vim.fn.writefile({ 'a', 'b', 'c', 'd' }, file)
n.edit(file, 3)
assert(#vim.api.nvim_list_wins() == 1, 'edit should hide Nterm')
assert(vim.api.nvim_buf_get_name(0) == vim.fn.resolve(file) or vim.api.nvim_buf_get_name(0) == file, 'edit opened ' .. vim.api.nvim_buf_get_name(0))
assert(vim.api.nvim_win_get_cursor(0)[1] == 3, 'edit should jump to the line')

-- lazygit's quoted {{filename}}
n.toggle()
n.edit('"' .. file .. '"', 2)
assert(vim.api.nvim_win_get_cursor(0)[1] == 2 and #vim.api.nvim_list_wins() == 1, 'quoted filename')

-- the terminals survive: Ctrl-/ brings them back
n.toggle()
assert(vim.bo.buftype == 'terminal', 'terminals should still be there after edit')
n.hide()
print('ok')
