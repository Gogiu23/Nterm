-- nvim --headless -u NONE --cmd 'set rtp+=.' -l tests/docked.lua
vim.opt.rtp:prepend('.')
local n = require('nterm')

assert(n._fit('short', 10) == 'short')
assert(n._fit('git log --oneline --graph', 10) == 'git log...')

-- winbar text without its %#Group# highlight codes
local function bar() return (n.winbar():gsub('%%#[^#]*#', '')) end

n.setup({ position = 'bottom' })
n.toggle()
local win = vim.api.nvim_get_current_win()
assert(vim.api.nvim_win_get_config(win).relative == '', 'docked terminal should be a split')
assert(vim.wo[win].winbar ~= '', 'docked terminal should have a winbar')
assert(bar():find('1/1') and bar():find('Nterm'), 'winbar: ' .. bar())
n.new()
assert(bar():find('2/2'), 'winbar after new: ' .. bar())
n.sidebar()
assert(vim.api.nvim_win_get_config(0).relative == 'editor', 'docked sidebar should float')
n.select(1)
assert(bar():find('1/2'), bar())
n.hide()
assert(#vim.api.nvim_list_wins() == 1, 'hide left windows open')

n.setup({ position = 'nope' }) -- warns and falls back to float
n.toggle()
assert(vim.api.nvim_win_get_config(0).relative == 'editor', 'fallback should be float')
n.hide()
print('ok')
