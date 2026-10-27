-- Drives Nterm inside a real terminal and takes screenshots. Run via assets/capture/run.sh.
local root = vim.fn.getcwd()
local out = root .. '/assets/'
-- Load this checkout's code even if a plugin manager installed another copy of Nterm
-- (lazy.nvim resets the runtimepath, so `set rtp^=` alone isn't enough).
local n = dofile(root .. '/lua/nterm/init.lua')
package.loaded.nterm = n

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'm', false)
end

local function winid()
  return vim.trim(vim.fn.system({ 'swift', root .. '/assets/capture/winid.swift', 'NtermDemo' }))
end

local function shot(name)
  vim.system({ 'screencapture', '-o', '-x', '-l', winid(), out .. name })
end

-- Types a string one key at a time; returns how long that takes, so the next step waits for it.
local function type(s)
  for i = 1, #s do
    vim.defer_fn(function() feed(s:sub(i, i)) end, i * 70)
  end
  return #s * 70
end

-- GIF mode: grabs window frames back to back and writes an ffmpeg concat list with each frame's real duration.
local frames, recording = os.getenv('NTERM_FRAMES'), false
local function record()
  local id, list = winid(), {}
  recording = true
  local function grab(i, t)
    local f = ('%s/%04d.png'):format(frames, i)
    vim.system({ 'screencapture', '-o', '-x', '-l', id, f }, {}, function()
      local now = vim.uv.hrtime()
      if t then list[#list].d = (now - t) / 1e9 end
      list[#list + 1] = { f = f }
      if recording then grab(i + 1, now) end
    end)
  end
  grab(1)
  return function()
    recording = false
    local lines = {}
    for _, e in ipairs(list) do
      lines[#lines + 1] = ("file '%s'"):format(e.f)
      lines[#lines + 1] = ('duration %.3f'):format(e.d or 1)
    end
    lines[#lines + 1] = ("file '%s'"):format(list[#list].f) -- concat demuxer ignores the last duration otherwise
    vim.fn.writefile(lines, frames .. '/list.txt')
  end
end

local docked = os.getenv('NTERM_POSITION')
n.setup({ position = docked or 'float' })

local stop
local steps = frames and {
  function() stop = record() end,
  function() n.toggle() end,
  function() return type('ls') end,
  function() feed('<CR>') end,
  function() feed('<C-+>') end,
  function() return type('git log --oneline -3') end,
  function() feed('<CR>') end,
  function() feed('<C-+>') end,
  function() return type('nvim --version | head -1') end,
  function() feed('<CR>') end,
  function() feed('<C-lt>') end,
  function() feed('<C-lt>') end,
  function() feed('<C->>') end,
  function() feed('<C-b>') end,
  function() feed('3') end,
  function() feed('<C-q>') end,
  function() feed('<C-q>') end,
  function() feed('<Esc><Esc>') end,
  function() feed('i') end,
  function() feed('<C-/>') end,
  function() stop() end,
  function() vim.cmd('qa!') end,
} or docked and {
  function() n.toggle() end,
  function() feed('ls') end,
  function() feed('<CR>') end,
  function() feed('<C-+>') end,
  function() feed('git log --oneline -3 --format=%s') end,
  function() feed('<CR>') end,
  function() shot('docked.png') end,
  function() feed('<C-b>') end,
  function() shot('docked-sidebar.png') end,
  function() vim.cmd('qa!') end,
} or {
  function() n.toggle() end,
  function() feed('ls') end,
  function() feed('<CR>') end,
  function() feed('git log --oneline -3') end,
  function() feed('<CR>') end,
  function() shot('terminal.png') end,
  function() feed('<C-+>') end,
  function() feed('nvim --version | head -1') end,
  function() feed('<CR>') end,
  function() feed('<C-+>') end,
  function() feed('ls lua/nterm') end,
  function() feed('<CR>') end,
  function() feed('<C-b>') end,
  function() shot('sidebar.png') end,
  function() feed('<C-q>') end,
  function() shot('keys.png') end,
  function() feed('<C-q>') end, -- back in the sidebar
  function() feed('<C-d>') end,
  function() shot('confirm.png') end,
  function() feed('n') end,
  function() vim.cmd('qa!') end,
}

local function run(i)
  if not steps[i] then return end
  local extra = steps[i]() or 0
  vim.defer_fn(function() run(i + 1) end, (frames and 1300 or 2500) + extra)
end

vim.defer_fn(function() run(1) end, 2000)
