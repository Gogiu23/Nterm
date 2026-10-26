local M = {}
local api = vim.api

local SIDE = 30
local HEAD = 4 -- header rows: border + title + guide + border
local ICON = '\u{f36f}' -- nf-linux-neovim, needs a Nerd Font
local TICON = '\u{e795}' -- nf-dev-terminal
local POSITIONS = { float = true, bottom = true, left = true, right = true }
local C = {
  position = 'float', -- 'float', 'bottom', 'left' or 'right'
  size = 0.3,         -- docked positions: fraction of the editor
  theme = 'auto',     -- 'auto': colors from the colorscheme, 'nterm': built-in palette
  opacity = 1,        -- floating windows, 0..1 (winblend)
  transparent = false, -- no background, so the terminal emulator's own transparency shows
  lazygit_key = '<leader>gg', -- false to disable
  border_color = '#2391FF', -- border gradient: a color (dark -> light shades of it) or { from, to }
}
local S = { terms = {}, cmds = {}, apps = {}, cur = nil, win = nil, side = nil, head = nil, sidebuf = nil, keys = nil }
local ns = api.nvim_create_namespace('nterm')

local KEYS = {
  { 'Global', 'Ctrl-/', 'Show / hide Nterm' },
  { 'Global', '<leader>gg', 'Open lazygit' },
  { 'Terminal', 'Ctrl-b', 'Open the sidebar' },
  { 'Terminal', 'Ctrl-+', 'New terminal (also Ctrl-=)' },
  { 'Terminal', 'Ctrl-> / Ctrl-<', 'Next / previous terminal (also Ctrl-. / Ctrl-,)' },
  { 'Terminal', 'Esc Esc', 'Switch to normal mode' },
  { 'Terminal', 'Ctrl-q', 'Show this keymap list' },
  { 'Sidebar', '1-9 / Enter', 'Switch to that terminal' },
  { 'Sidebar', 'Ctrl-+', 'New terminal (also Ctrl-= and +)' },
  { 'Sidebar', 'Ctrl-d', 'Close terminal (asks first)' },
  { 'Sidebar', 'Ctrl-b / q / Esc', 'Close the sidebar' },
  { 'Sidebar', 'Ctrl-q', 'Show this keymap list' },
  { 'Command', ':Nterm [cmd]', 'Toggle Nterm, or run cmd in a new terminal' },
  { 'Command', ':NtermHelp', 'Open the full guide' },
}

local function valid(w) return w and api.nvim_win_is_valid(w) end
local function floating() return C.position == 'float' end

local function idx(buf)
  for i, b in ipairs(S.terms) do if b == buf then return i end end
end

local BLUE = { '#2547a8', '#a8cdff' } -- title gradient, dark to light
local TAB_BG = '#1b2440' -- background of the title tab in docked positions (recomputed by set_hl)
local GUIDE = 'Ctrl-/ hide · Ctrl-+ new · Ctrl-< Ctrl-> switch · Ctrl-b sidebar · Ctrl-q keymaps · Esc Esc normal mode'
local MODES = { -- first char of nvim_get_mode().mode -> label, gradient
  n = { 'NORMAL', '#2f63d6', '#8fb8ff' },
  i = { 'INSERT', '#1f8a4c', '#8be0a4' },
  v = { 'VISUAL', '#7a35c4', '#d4a8ff' },
  V = { 'V-LINE', '#7a35c4', '#d4a8ff' },
  ['\22'] = { 'V-BLOCK', '#7a35c4', '#d4a8ff' },
  s = { 'SELECT', '#7a35c4', '#d4a8ff' },
  R = { 'REPLACE', '#b3263d', '#ff9db0' },
  c = { 'COMMAND', '#c26a12', '#ffd08a' },
  t = { 'TERMINAL', '#b0127a', '#ff8ad8' },
}

-- theme = 'auto': each gradient is built from the fg of one of the colorscheme's groups
local AUTO = { title = 'Function', n = 'Function', i = 'String', v = 'Type', V = 'Type', ['\22'] = 'Type',
  s = 'Type', R = 'DiagnosticError', c = 'Number', t = 'Keyword' }
local BUILTIN = vim.deepcopy({ title = BLUE, modes = MODES, tab = TAB_BG })

local function mode() return MODES[api.nvim_get_mode().mode:sub(1, 1)] or MODES.n end
local function term_label() return string.format('%s %d/%d', TICON, idx(S.cur) or 0, #S.terms) end

local function lerp(a, b, t)
  local function ch(h, i) return tonumber(h:sub(i, i + 1), 16) end
  return string.format('#%02x%02x%02x', ch(a, 2) + (ch(b, 2) - ch(a, 2)) * t + 0.5,
    ch(a, 4) + (ch(b, 4) - ch(a, 4)) * t + 0.5, ch(a, 6) + (ch(b, 6) - ch(a, 6)) * t + 0.5)
end

local function hl_color(name, key)
  local c = api.nvim_get_hl(0, { name = name, link = false })[key]
  return c and string.format('#%06x', c)
end

-- Fills BLUE, MODES and TAB_BG from the colorscheme (theme = 'auto') or the built-in palette.
local function load_palette()
  local function set(dst, a, b) dst[1], dst[2] = a, b end
  set(BLUE, BUILTIN.title[1], BUILTIN.title[2])
  for k, m in pairs(BUILTIN.modes) do MODES[k][2], MODES[k][3] = m[2], m[3] end
  TAB_BG = BUILTIN.tab
  if C.theme ~= 'auto' then return end
  local bg = hl_color('Normal', 'bg') or '#000000'
  -- darker end blends toward the background, lighter end toward white
  local function ends(group)
    local c = hl_color(group, 'fg')
    if c then return lerp(c, bg, 0.35), lerp(c, '#ffffff', 0.3) end
  end
  local a, b = ends(AUTO.title)
  if a then set(BLUE, a, b); TAB_BG = lerp(bg, a, 0.25) end
  for k, group in pairs(AUTO) do
    if MODES[k] then
      a, b = ends(group)
      if a then MODES[k][2], MODES[k][3] = a, b end
    end
  end
end

-- Corners and sides in order ╭ ─ ╮ │ ╯ ─ ╰ │; shades 1..5 run diagonally from top-left to bottom-right.
local BORDER = {}
for i, ch in ipairs({ '╭', '─', '╮', '│', '╯', '─', '╰', '│' }) do
  BORDER[i] = { ch, 'NtermEdge' .. ({ 1, 2, 3, 4, 5, 4, 3, 2 })[i] }
end

local function is_hex(c) return type(c) == 'string' and c:match('^#%x%x%x%x%x%x$') ~= nil end

local function set_border_hl()
  local bc, from, to = C.border_color
  if type(bc) == 'table' then
    from, to = bc[1], bc[2]
  else
    from, to = lerp(bc, '#000000', 0.45), lerp(bc, '#ffffff', 0.35)
  end
  local bg = (not C.transparent) and (hl_color('FloatBorder', 'bg') or hl_color('NormalFloat', 'bg')) or nil
  for i = 1, 5 do api.nvim_set_hl(0, 'NtermEdge' .. i, { fg = lerp(from, to, (i - 1) / 4), bg = bg }) end
end

local function set_hl()
  set_border_hl()
  load_palette()
  api.nvim_set_hl(0, 'NtermIcon', { fg = BLUE[1], bold = true })
  api.nvim_set_hl(0, 'NtermTab', { bg = TAB_BG })
  api.nvim_set_hl(0, 'NtermTabIcon', { fg = BLUE[1], bg = TAB_BG, bold = true })
  api.nvim_set_hl(0, 'NtermNormal', { fg = hl_color('Normal', 'fg'), bg = 'NONE' })
  api.nvim_set_hl(0, 'NtermBorder', { fg = hl_color('FloatBorder', 'fg') or hl_color('Normal', 'fg'), bg = 'NONE' })
end

-- Applies opacity / transparency to one of Nterm's windows.
local function style_win(w)
  if C.transparent then
    vim.wo[w].winhighlight = 'Normal:NtermNormal,NormalFloat:NtermNormal,FloatBorder:NtermBorder,NormalNC:NtermNormal'
  end
  if api.nvim_win_get_config(w).relative ~= '' then
    vim.wo[w].winblend = math.floor((1 - math.min(math.max(C.opacity, 0), 1)) * 100 + 0.5)
  end
end

-- Calls fn(char, group) for each character of `text`, colored along the gradient a -> b.
local function gradient(text, a, b, style, fn)
  local chars = vim.fn.split(text, [[\zs]])
  for i, c in ipairs(chars) do
    local fg = lerp(a, b, #chars > 1 and (i - 1) / (#chars - 1) or 0)
    local group = 'Nterm_' .. fg:sub(2) .. (style.italic and 'i' or '') .. (style.bold and 'b' or '')
      .. (style.bg and 'g' or '')
    api.nvim_set_hl(0, group, { fg = fg, bg = style.bg, bold = style.bold, italic = style.italic })
    fn(c, group)
  end
end

local function paint(buf, row, col, text, a, b, style)
  gradient(text, a, b, style, function(c, group)
    api.nvim_buf_set_extmark(buf, ns, row, col, { end_col = col + #c, hl_group = group })
    col = col + #c
  end)
end

-- Same gradient, as a statusline/winbar string.
local function bar(text, a, b, style)
  local out = {}
  gradient(text, a, b, style, function(c, group) out[#out + 1] = '%#' .. group .. '#' .. c end)
  return table.concat(out)
end

-- Truncates to `n` display cells, ending in "..." when it doesn't fit.
local function fit(s, n)
  if vim.fn.strdisplaywidth(s) <= n then return s end
  return vim.fn.strcharpart(s, 0, math.max(n - 3, 0)) .. '...'
end
M._fit = fit

-- Docked positions: one tab with the title, the terminal number and the mode.
function M.winbar()
  local m = mode()
  return '%#NtermTabIcon# ' .. ICON .. ' ' .. bar('Nterm ', BLUE[1], BLUE[2], { bold = true, bg = TAB_BG })
    .. '%#Normal#  ' .. bar(term_label(), BLUE[1], BLUE[2], { bold = true })
    .. '%=' .. bar(m[1], m[2], m[3], { bold = true }) .. ' '
end

-- outer box (header + body); body is what sits under the header
local function geom()
  local w, h = math.floor(vim.o.columns * 0.8), math.floor(vim.o.lines * 0.8)
  return w, h, math.floor((vim.o.lines - h) / 2) - 1, math.floor((vim.o.columns - w) / 2)
end

local function head_cfg()
  local w, _, row, col = geom()
  return { relative = 'editor', width = w, height = HEAD - 2, row = row, col = col, border = BORDER }
end

local function side_cfg()
  local cfg = { relative = 'editor', width = SIDE, border = BORDER, title = ' Terminals ', title_pos = 'center' }
  if floating() then
    local _, h, row, col = geom()
    cfg.height, cfg.row, cfg.col = h - HEAD, row + HEAD, col
  else -- docked terminal: the sidebar floats in the middle of the editor
    cfg.height = math.min(math.max(#S.terms, 3), vim.o.lines - 4)
    cfg.row = math.floor((vim.o.lines - cfg.height) / 2) - 1
    cfg.col = math.floor((vim.o.columns - SIDE) / 2)
  end
  return cfg
end

local function main_cfg()
  local w, h, row, col = geom()
  local off = valid(S.side) and SIDE + 2 or 0
  return { relative = 'editor', width = w - off, height = h - HEAD, row = row + HEAD, col = col + off,
    border = BORDER }
end

local function draw_head()
  if not valid(S.head) then return end
  local buf = api.nvim_win_get_buf(S.head)
  local width = api.nvim_win_get_width(S.head)
  local w = vim.fn.strdisplaywidth
  local m = mode()
  local term = term_label()
  local title = ICON .. '  Nterm'
  local tcol = math.max(math.floor((width - w(title)) / 2), w(term) + 2)
  local left = ' ' .. term .. string.rep(' ', tcol - w(term) - 1) .. title
  local top = left .. string.rep(' ', math.max(width - w(left) - #m[1] - 1, 1)) .. m[1]
  local guide = fit(GUIDE, width - 2)
  local gpad = string.rep(' ', math.max(math.floor((width - w(guide)) / 2), 0))
  api.nvim_buf_set_lines(buf, 0, -1, false, { top, gpad .. guide })
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local icon = #left - #title
  api.nvim_buf_set_extmark(buf, ns, 0, icon, { end_col = icon + #ICON, hl_group = 'NtermIcon' })
  paint(buf, 0, #left - 5, 'Nterm', BLUE[1], BLUE[2], { bold = true })
  paint(buf, 0, 1, term, BLUE[1], BLUE[2], { bold = true })
  paint(buf, 0, #top - #m[1], m[1], m[2], m[3], { bold = true })
  paint(buf, 1, #gpad, guide, BLUE[1], BLUE[2], { italic = true })
end

local function last_cmd(b)
  local c = S.cmds[b]
  return (c and c ~= '') and c or '—'
end

local function render()
  if not (S.sidebuf and api.nvim_buf_is_valid(S.sidebuf)) then return end
  local lines, prefixes = {}, {}
  for i, b in ipairs(S.terms) do
    prefixes[i] = string.format('%s%d  ', b == S.cur and '▶' or ' ', i)
    lines[i] = prefixes[i] .. fit(last_cmd(b), SIDE - vim.fn.strdisplaywidth(prefixes[i]) - 1)
  end
  vim.bo[S.sidebuf].modifiable = true
  api.nvim_buf_set_lines(S.sidebuf, 0, -1, false, lines)
  vim.bo[S.sidebuf].modifiable = false
  api.nvim_buf_clear_namespace(S.sidebuf, ns, 0, -1)
  for i, l in ipairs(lines) do
    paint(S.sidebuf, i - 1, #prefixes[i], l:sub(#prefixes[i] + 1), BLUE[1], BLUE[2], {})
  end
end

local function relayout()
  if valid(S.head) then api.nvim_win_set_config(S.head, head_cfg()); draw_head() end
  if valid(S.win) and floating() then api.nvim_win_set_config(S.win, main_cfg()) end
  if valid(S.side) then api.nvim_win_set_config(S.side, side_cfg()) end
end

local function focus_term()
  if not valid(S.win) then return end
  api.nvim_set_current_win(S.win)
  vim.cmd.startinsert()
end

local function close(w)
  -- pcall: a docked terminal can be the last window, which Neovim refuses to close
  if valid(w) then pcall(api.nvim_win_close, w, true) end
end

local function close_side()
  close(S.side)
  S.side = nil
  relayout()
end

-- Shows `buf` in the terminal window; docked windows need their options set on every buffer switch.
local function show(buf)
  api.nvim_win_set_buf(S.win, buf)
  if floating() then return end
  local wo = vim.wo[S.win]
  wo.winbar = "%{%v:lua.require'nterm'.winbar()%}"
  wo.number, wo.relativenumber, wo.signcolumn = false, false, 'no'
  wo.winfixheight, wo.winfixwidth = true, true
end

-- Strips the prompt from the cursor line: "user@host ~/dir> git status" -> "git status".
-- ponytail: heuristic on common prompt chars ($ > # % ❯); exotic prompts show the whole line.
function M._parse(line)
  line = line:gsub('❯', '>')
  local cmd = line:match('^.-[%$>#%%]%s+(.-)%s*$') or vim.trim(line)
  return cmd
end

local function record(buf)
  local col = api.nvim_win_get_cursor(0)[2]
  -- cut at cursor so shell autosuggestions (fish) are ignored
  local cmd = M._parse(api.nvim_get_current_line():sub(1, col))
  if cmd ~= '' then S.cmds[buf] = cmd; vim.schedule(render) end
end

local function remove(buf)
  local i = idx(buf)
  if not i then return end
  table.remove(S.terms, i)
  S.cmds[buf], S.apps[buf] = nil, nil
  if #S.terms == 0 then
    S.cur = nil
    M.hide()
  elseif S.cur == buf then
    S.cur = S.terms[math.min(i, #S.terms)]
    if valid(S.win) then show(S.cur) end
  end
  if api.nvim_buf_is_valid(buf) then api.nvim_buf_delete(buf, { force = true }) end
  render()
  relayout()
end

function M.keys()
  if valid(S.keys) then return close(S.keys) end
  local from = api.nvim_get_current_win()
  local lines = {}
  for _, k in ipairs(KEYS) do lines[#lines + 1] = string.format(' %-9s %-18s %s', k[1], k[2], k[3]) end
  local width = 0
  for _, l in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(l) + 1) end
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  S.keys = api.nvim_open_win(buf, true, { relative = 'editor', width = width, height = #lines,
    row = math.floor((vim.o.lines - #lines) / 2), col = math.floor((vim.o.columns - width) / 2),
    border = BORDER, title = ' Nterm keymaps ', title_pos = 'center', style = 'minimal', zindex = 60 })
  style_win(S.keys)
  local function back()
    close(S.keys)
    S.keys = nil
    if valid(from) then
      api.nvim_set_current_win(from)
      if vim.bo[api.nvim_win_get_buf(from)].buftype == 'terminal' then vim.cmd.startinsert() end
    end
  end
  for _, k in ipairs({ 'q', '<Esc>', '<C-q>' }) do vim.keymap.set('n', k, back, { buffer = buf, nowait = true }) end
end

-- `app`: the terminal runs a program (e.g. lazygit) instead of a shell, so only the keys needed to
-- leave it are taken; Esc, Ctrl-b, Ctrl-q... reach the program untouched.
local function term_maps(buf, app)
  local o = { buffer = buf, nowait = true }
  for _, k in ipairs({ '<C-/>', '<C-_>' }) do vim.keymap.set({ 'n', 't' }, k, M.hide, o) end
  -- Ctrl-> / Ctrl-< arrive in different shapes depending on layout and keyboard protocol
  for _, k in ipairs({ '<C->>', '<C-S->>', '<C-S-lt>', '<C-.>' }) do
    vim.keymap.set({ 'n', 't' }, k, function() M.cycle(1) end, o)
  end
  for _, k in ipairs({ '<C-lt>', '<C-,>' }) do vim.keymap.set({ 'n', 't' }, k, function() M.cycle(-1) end, o) end
  if not app then
    vim.keymap.set({ 'n', 't' }, '<C-b>', M.sidebar, o)
    vim.keymap.set({ 'n', 't' }, '<C-q>', M.keys, o)
    for _, k in ipairs({ '<C-+>', '<C-=>' }) do vim.keymap.set({ 'n', 't' }, k, M.new, o) end
    vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n>]], { buffer = buf })
  end
  api.nvim_create_autocmd('TermClose', { buffer = buf, once = true,
    callback = function() vim.schedule(function() remove(buf) end) end })
end

local function open_win(buf)
  if floating() then
    local cfg = head_cfg()
    cfg.style, cfg.focusable = 'minimal', false
    S.head = api.nvim_open_win(api.nvim_create_buf(false, true), false, cfg)
    vim.bo[api.nvim_win_get_buf(S.head)].bufhidden = 'wipe'
    style_win(S.head)
    draw_head()
    cfg = main_cfg()
    cfg.style = 'minimal'
    S.win = api.nvim_open_win(buf, true, cfg)
    style_win(S.win)
  else
    local vert = C.position ~= 'bottom'
    local size = math.floor((vert and vim.o.columns or vim.o.lines) * C.size)
    S.win = api.nvim_open_win(buf, true, { split = vert and C.position or 'below', win = -1,
      width = vert and size or nil, height = (not vert) and size or nil })
    style_win(S.win)
    show(buf)
  end
  api.nvim_create_autocmd('WinClosed', { pattern = tostring(S.win), once = true,
    callback = function() vim.schedule(function() close(S.head); close_side() end) end })
end

local function open_term(cmd, cwd)
  local buf = api.nvim_create_buf(false, true)
  table.insert(S.terms, buf)
  S.cur = buf
  if cmd then S.cmds[buf], S.apps[buf] = cmd, true end
  if valid(S.win) then
    show(buf)
    api.nvim_set_current_win(S.win)
  else
    open_win(buf)
  end
  vim.fn.jobstart(cmd or vim.o.shell, { term = true, cwd = cwd })
  term_maps(buf, cmd ~= nil)
  close_side()
  vim.cmd.startinsert()
  return buf
end

function M.new() open_term() end

-- Runs `cmd` in a new terminal; it closes when the program exits.
function M.run(cmd, cwd) return open_term(cmd, cwd) end

-- Opens lazygit at the git root of the current file, reusing a running one.
function M.lazygit()
  if vim.fn.executable('lazygit') == 0 then
    return vim.notify('Nterm: lazygit not found in PATH', vim.log.levels.ERROR)
  end
  for i, b in ipairs(S.terms) do
    if S.apps[b] and S.cmds[b] == 'lazygit' then
      if not valid(S.win) then S.cur = b; open_win(b) end
      return M.select(i)
    end
  end
  M.run('lazygit', vim.fs.root(0, '.git') or vim.fn.getcwd())
end

-- Called by lazygit (see the README) to open a file in this Neovim: hides Nterm, keeping lazygit
-- running in the background, so Ctrl-/ brings it back where it was.
function M.edit(file, line)
  -- lazygit passes {{filename}} double-quoted, with \ " $ ` escaped
  local quoted = file:match('^"(.*)"$')
  if quoted then file = quoted:gsub('\\([\\"$`])', '%1') end
  M.hide()
  vim.cmd.edit(vim.fn.fnameescape(file))
  if line then pcall(api.nvim_win_set_cursor, 0, { tonumber(line), 0 }) end
end

function M.select(i)
  local b = S.terms[i]
  if not b then return end
  S.cur = b
  show(b)
  close_side()
  focus_term()
end

function M.cycle(d)
  if #S.terms < 2 or not valid(S.win) then return end
  M.select((idx(S.cur) - 1 + d) % #S.terms + 1)
end

function M.close_at(i)
  local b = S.terms[i]
  if not b then return end
  if vim.fn.confirm(('Close terminal %d (%s)?'):format(i, last_cmd(b)), '&Yes\n&No', 2) == 1 then
    remove(b)
  end
end

local function side_buf()
  if S.sidebuf and api.nvim_buf_is_valid(S.sidebuf) then return S.sidebuf end
  local b = api.nvim_create_buf(false, true)
  vim.bo[b].filetype = 'nterm'
  local o = { buffer = b, nowait = true }
  local line = function() return api.nvim_win_get_cursor(0)[1] end
  for i = 1, 9 do vim.keymap.set('n', tostring(i), function() M.select(i) end, o) end
  vim.keymap.set('n', '<CR>', function() M.select(line()) end, o)
  -- <C-+> needs a terminal with the kitty keyboard protocol; <C-=> and + are fallbacks
  for _, k in ipairs({ '<C-+>', '<C-=>', '+' }) do vim.keymap.set('n', k, M.new, o) end
  vim.keymap.set('n', '<C-d>', function() M.close_at(line()) end, o)
  vim.keymap.set('n', '<C-q>', M.keys, o)
  for _, k in ipairs({ '<C-b>', 'q', '<Esc>' }) do
    vim.keymap.set('n', k, function() close_side(); focus_term() end, o)
  end
  for _, k in ipairs({ '<C-/>', '<C-_>' }) do vim.keymap.set('n', k, M.hide, o) end
  S.sidebuf = b
  return b
end

function M.sidebar()
  if not valid(S.win) then return end
  if valid(S.side) then return api.nvim_set_current_win(S.side) end
  local cfg = side_cfg()
  cfg.style = 'minimal'
  S.side = api.nvim_open_win(side_buf(), true, cfg)
  vim.wo[S.side].cursorline = true
  style_win(S.side)
  relayout()
  render()
  api.nvim_win_set_cursor(S.side, { math.max(idx(S.cur) or 1, 1), 0 })
end

function M.hide()
  close(S.keys)
  close(S.side)
  close(S.win)
  close(S.head)
  S.keys, S.side, S.win, S.head = nil, nil, nil, nil
end

function M.toggle()
  if valid(S.win) then return M.hide() end
  if not S.cur then return M.new() end
  open_win(S.cur)
  vim.cmd.startinsert()
end

-- See C above for the options and their defaults.
function M.setup(opts)
  opts = opts or {}
  if opts.position and not POSITIONS[opts.position] then
    vim.notify(("Nterm: unknown position '%s', using 'float'"):format(opts.position), vim.log.levels.WARN)
    opts.position = 'float'
  end
  local bc = opts.border_color
  if bc ~= nil and not (is_hex(bc) or (type(bc) == 'table' and is_hex(bc[1]) and is_hex(bc[2]))) then
    vim.notify("Nterm: border_color must be '#rrggbb' or { '#rrggbb', '#rrggbb' }, using the default",
      vim.log.levels.WARN)
    opts.border_color = nil
  end
  C = vim.tbl_extend('force', C, opts)
  set_hl()
  local g = api.nvim_create_augroup('Nterm', { clear = true })
  api.nvim_create_autocmd('ColorScheme', { group = g, callback = set_hl })
  api.nvim_create_autocmd('VimResized', { group = g, callback = relayout })
  api.nvim_create_autocmd('ModeChanged', { group = g, callback = function()
    vim.schedule(function()
      draw_head()
      if valid(S.win) and not floating() then vim.cmd.redrawstatus({ bang = true }) end
    end)
  end })
  -- Watches Enter without mapping it, so the key always reaches the shell untouched.
  vim.on_key(function(key)
    local buf = api.nvim_get_current_buf()
    if key == '\r' and api.nvim_get_mode().mode == 't' and idx(buf) and not S.apps[buf] then
      record(buf)
    end
  end, ns)
  for _, k in ipairs({ '<C-/>', '<C-_>' }) do vim.keymap.set({ 'n', 't' }, k, M.toggle, { desc = 'Nterm' }) end
  -- setup() can run twice (plugin/ and the user's opts): drop the old lazygit key first
  if S.lazygit_key then pcall(vim.keymap.del, 'n', S.lazygit_key) end
  S.lazygit_key = C.lazygit_key or nil
  if S.lazygit_key then vim.keymap.set('n', S.lazygit_key, M.lazygit, { desc = 'Nterm: lazygit' }) end
  api.nvim_create_user_command('Nterm', function(a)
    if a.args == '' then M.toggle()
    elseif a.args == 'lazygit' then M.lazygit()
    else M.run(a.args) end
  end, { nargs = '*', complete = 'shellcmd', desc = 'Nterm: toggle, or run a command in a new terminal' })
  api.nvim_create_user_command('NtermHelp', function()
    -- local installs (dir = ..., symlinks) don't get helptags generated for them
    local doc = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h:h') .. '/doc'
    pcall(vim.cmd.helptags, doc)
    vim.cmd.help('nterm')
  end, { desc = 'Nterm: open the guide' })
end

return M
