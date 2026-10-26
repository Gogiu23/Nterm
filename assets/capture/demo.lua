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

local function shot(name)
  local id = vim.trim(vim.fn.system({ 'swift', root .. '/assets/capture/winid.swift', 'NtermDemo' }))
  vim.system({ 'screencapture', '-o', '-x', '-l', id, out .. name })
end

local docked = os.getenv('NTERM_POSITION')
n.setup({ position = docked or 'float' })

local steps = docked and {
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
  steps[i]()
  vim.defer_fn(function() run(i + 1) end, 2500)
end

vim.defer_fn(function() run(1) end, 2000)
