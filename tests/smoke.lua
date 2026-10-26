-- nvim --headless -u NONE --cmd 'set rtp+=.' -l tests/smoke.lua
vim.opt.rtp:prepend('.')
local n = require('nterm')
n.setup()

assert(n._parse('user@host ~/dir> git status') == 'git status')
assert(n._parse('❯ ls -la  ') == 'ls -la')
assert(n._parse('bash-5.2$ echo hi') == 'echo hi')

n.toggle()
n.new()
n.sidebar()
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(#lines == 2, 'expected 2 terminals, got ' .. #lines)
n.select(1)

local function header()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if not vim.api.nvim_win_get_config(w).focusable then
      return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, 1, false)[1]
    end
  end
end
assert(header():find('1/2'), 'header should show 1/2: ' .. header())
n.cycle(-1) -- wraps around
assert(header():find('2/2'), 'cycle(-1) should wrap to 2/2: ' .. header())
n.cycle(1)
assert(header():find('1/2'), 'cycle(1) should wrap to 1/2: ' .. header())

local wins = #vim.api.nvim_list_wins()
n.keys()
assert(#vim.api.nvim_list_wins() == wins + 1, 'keys popup not opened')
assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false)):find('Ctrl%-b'), 'keys popup content')
n.keys()
assert(#vim.api.nvim_list_wins() == wins, 'keys popup not closed')
n.hide()
assert(#vim.api.nvim_list_wins() == 1, 'hide left windows open')
n.toggle()
n.hide()
print('ok')
