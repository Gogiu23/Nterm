-- nvim --headless -u NONE --cmd 'set rtp+=.' -l tests/theme.lua
vim.opt.rtp:prepend('.')
local n = require('nterm')

-- a fake colorscheme: Function is pure blue, Keyword pure red
vim.api.nvim_set_hl(0, 'Normal', { fg = '#ffffff', bg = '#000000' })
vim.api.nvim_set_hl(0, 'Function', { fg = '#0000ff' })
vim.api.nvim_set_hl(0, 'Keyword', { fg = '#ff0000' })

local function fg(name) return string.format('#%06x', vim.api.nvim_get_hl(0, { name = name }).fg) end

n.setup({ theme = 'auto' })
-- Function #0000ff blended 35% toward the black background
assert(fg('NtermIcon') == '#0000a6', 'auto title color: ' .. fg('NtermIcon'))

vim.api.nvim_set_hl(0, 'Function', { fg = '#00ff00' })
vim.cmd('doautocmd ColorScheme')
assert(fg('NtermIcon') == '#00a600', 'palette should follow ColorScheme: ' .. fg('NtermIcon'))

n.setup({ theme = 'nterm' })
assert(fg('NtermIcon') == '#2547a8', 'built-in palette: ' .. fg('NtermIcon'))

n.setup({ theme = 'auto', opacity = 0.7, transparent = true })
n.toggle()
local win = vim.api.nvim_get_current_win()
assert(vim.wo[win].winblend == 30, 'opacity 0.7 -> winblend 30, got ' .. vim.wo[win].winblend)
assert(vim.wo[win].winhighlight:find('Normal:NtermNormal'), 'transparent winhighlight')
n.hide()
-- border gradient: default #2391FF, a custom color, a { from, to } pair, and bad input
local function edge(i) return fg('NtermEdge' .. i) end
n.setup({ transparent = false })
assert(edge(1) ~= edge(5), 'border should be a gradient')
n.toggle()
local b = vim.api.nvim_win_get_config(0).border
assert(type(b) == 'table' and b[1][2] == 'NtermEdge1' and b[5][2] == 'NtermEdge5', 'floats use the gradient border')
n.hide()
n.setup({ border_color = { '#000000', '#ffffff' } })
assert(edge(1) == '#000000' and edge(5) == '#ffffff' and edge(3) == '#808080', 'from/to: ' .. edge(3))
n.setup({ border_color = '#ff0000' })
assert(edge(1) == '#8c0000', 'custom color dark end: ' .. edge(1))
n.setup({ border_color = 'blue' }) -- warns, keeps the previous valid color
assert(edge(1) == '#8c0000', 'invalid border_color is ignored')
print('ok')
