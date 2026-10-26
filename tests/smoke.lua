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
n.hide()
n.toggle()
n.hide()
print('ok')
