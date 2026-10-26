local M = {}
local api = vim.api

local SIDE = 30
local S = { terms = {}, cmds = {}, cur = nil, win = nil, side = nil, sidebuf = nil }

local function valid(w) return w and api.nvim_win_is_valid(w) end

local function set_hl()
  local blues = { '#2547a8', '#2f63d6', '#4a86ef', '#73a7f7', '#a8cdff' }
  for i, c in ipairs(blues) do api.nvim_set_hl(0, 'NtermTitle' .. i, { fg = c, bold = true }) end
end

local function title()
  local t = { { ' ' } }
  for i, ch in ipairs({ 'N', 't', 'e', 'r', 'm' }) do t[#t + 1] = { ch, 'NtermTitle' .. i } end
  t[#t + 1] = { ' ' }
  return t
end

local function geom()
  local w, h = math.floor(vim.o.columns * 0.8), math.floor(vim.o.lines * 0.8)
  return w, h, math.floor((vim.o.lines - h) / 2) - 1, math.floor((vim.o.columns - w) / 2)
end

local function main_cfg()
  local w, h, row, col = geom()
  local off = valid(S.side) and SIDE + 2 or 0
  return { relative = 'editor', width = w - off, height = h, row = row, col = col + off,
    border = 'rounded', title = title(), title_pos = 'center' }
end

local function last_cmd(b)
  local c = S.cmds[b]
  return (c and c ~= '') and c or '—'
end

local function render()
  if not (S.sidebuf and api.nvim_buf_is_valid(S.sidebuf)) then return end
  local lines = {}
  for i, b in ipairs(S.terms) do
    lines[i] = string.format('%s%d  %s', b == S.cur and '▶' or ' ', i, last_cmd(b))
  end
  vim.bo[S.sidebuf].modifiable = true
  api.nvim_buf_set_lines(S.sidebuf, 0, -1, false, lines)
  vim.bo[S.sidebuf].modifiable = false
end

local function relayout()
  if valid(S.win) then api.nvim_win_set_config(S.win, main_cfg()) end
  if valid(S.side) then
    local _, h, row, col = geom()
    api.nvim_win_set_config(S.side, { relative = 'editor', width = SIDE, height = h, row = row, col = col })
  end
end

local function focus_term()
  if not valid(S.win) then return end
  api.nvim_set_current_win(S.win)
  vim.cmd.startinsert()
end

local function close_side()
  if valid(S.side) then api.nvim_win_close(S.side, true) end
  S.side = nil
  relayout()
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
  if cmd ~= '' then S.cmds[buf] = cmd; render() end
end

local function idx(buf)
  for i, b in ipairs(S.terms) do if b == buf then return i end end
end

local function remove(buf)
  local i = idx(buf)
  if not i then return end
  table.remove(S.terms, i)
  S.cmds[buf] = nil
  if #S.terms == 0 then
    S.cur = nil
    M.hide()
  elseif S.cur == buf then
    S.cur = S.terms[math.min(i, #S.terms)]
    if valid(S.win) then api.nvim_win_set_buf(S.win, S.cur) end
  end
  if api.nvim_buf_is_valid(buf) then api.nvim_buf_delete(buf, { force = true }) end
  render()
end

local function term_maps(buf)
  local o = { buffer = buf, nowait = true }
  for _, k in ipairs({ '<C-/>', '<C-_>' }) do vim.keymap.set({ 'n', 't' }, k, M.hide, o) end
  vim.keymap.set('n', '<Space>', M.sidebar, o)
  vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n>]], { buffer = buf })
  vim.keymap.set('t', '<CR>', function() record(buf); return '<CR>' end, { buffer = buf, expr = true })
  api.nvim_create_autocmd('TermClose', { buffer = buf, once = true,
    callback = function() vim.schedule(function() remove(buf) end) end })
end

local function open_win(buf)
  local cfg = main_cfg()
  cfg.style = 'minimal'
  S.win = api.nvim_open_win(buf, true, cfg)
  api.nvim_create_autocmd('WinClosed', { pattern = tostring(S.win), once = true,
    callback = function() vim.schedule(close_side) end })
end

function M.new()
  local buf = api.nvim_create_buf(false, true)
  table.insert(S.terms, buf)
  S.cur = buf
  if valid(S.win) then
    api.nvim_win_set_buf(S.win, buf)
    api.nvim_set_current_win(S.win)
  else
    open_win(buf)
  end
  vim.fn.jobstart(vim.o.shell, { term = true })
  term_maps(buf)
  close_side()
  vim.cmd.startinsert()
end

function M.select(i)
  local b = S.terms[i]
  if not b then return end
  S.cur = b
  api.nvim_win_set_buf(S.win, b)
  close_side()
  focus_term()
end

function M.close_at(i)
  local b = S.terms[i]
  if not b then return end
  if vim.fn.confirm(('¿Cerrar terminal %d (%s)?'):format(i, last_cmd(b)), '&Sí\n&No', 2) == 1 then
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
  for _, k in ipairs({ '<Space>', 'q', '<Esc>' }) do
    vim.keymap.set('n', k, function() close_side(); focus_term() end, o)
  end
  for _, k in ipairs({ '<C-/>', '<C-_>' }) do vim.keymap.set('n', k, M.hide, o) end
  S.sidebuf = b
  return b
end

function M.sidebar()
  if not valid(S.win) then return end
  if valid(S.side) then return api.nvim_set_current_win(S.side) end
  local _, h, row, col = geom()
  S.side = api.nvim_open_win(side_buf(), true, { relative = 'editor', width = SIDE, height = h,
    row = row, col = col, border = 'rounded', title = ' Terminales ', title_pos = 'center', style = 'minimal' })
  vim.wo[S.side].cursorline = true
  relayout()
  render()
  api.nvim_win_set_cursor(S.side, { math.max(idx(S.cur) or 1, 1), 0 })
end

function M.hide()
  if valid(S.side) then api.nvim_win_close(S.side, true) end
  if valid(S.win) then api.nvim_win_close(S.win, true) end
  S.side, S.win = nil, nil
end

function M.toggle()
  if valid(S.win) then return M.hide() end
  if not S.cur then return M.new() end
  open_win(S.cur)
  vim.cmd.startinsert()
end

function M.setup()
  set_hl()
  local g = api.nvim_create_augroup('Nterm', { clear = true })
  api.nvim_create_autocmd('ColorScheme', { group = g, callback = set_hl })
  api.nvim_create_autocmd('VimResized', { group = g, callback = relayout })
  for _, k in ipairs({ '<C-/>', '<C-_>' }) do vim.keymap.set({ 'n', 't' }, k, M.toggle, { desc = 'Nterm' }) end
  api.nvim_create_user_command('NtermHelp', function()
    -- local installs (dir = ..., symlinks) don't get helptags generated for them
    local doc = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h:h') .. '/doc'
    pcall(vim.cmd.helptags, doc)
    vim.cmd.help('nterm')
  end, { desc = 'Nterm: abrir la guía' })
end

return M
