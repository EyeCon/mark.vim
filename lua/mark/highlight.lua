-- Highlight management for mark.nvim: definition of the Mark1..N highlight
-- groups from the configured colors and per-window matchadd() bookkeeping.

local state = require('mark.state')
local util = require('mark.util')

local M = {}

--- Define the Mark1..N highlight groups from a list of colors. A string entry
-- is shorthand for { bg = ... }; a table entry is passed to nvim_set_hl().
function M.define_colors(colors)
  state.colors = colors
  state.num_groups = #colors
  for i, color in ipairs(colors) do
    local attrs = (type(color) == 'string') and { bg = color } or vim.deepcopy(color)
    -- nvim_set_hl() requires numeric cterm colors as integers.
    for _, key in ipairs({ 'ctermbg', 'ctermfg' }) do
      if type(attrs[key]) == 'string' and attrs[key]:match('^%d+$') then
        attrs[key] = tonumber(attrs[key])
      end
    end
    local ok = pcall(vim.api.nvim_set_hl, 0, 'Mark' .. i, attrs)
    if not ok then
      util.warn('Invalid color definition at index ' .. i)
    end
  end
end

--- Adjust the pattern list to a new number of groups (setup / palette switch).
function M.reinit(new_num_groups)
  local num = math.max(0, new_num_groups)
  if num < state.num_groups then
    for i = num + 1, state.num_groups do
      vim.cmd('silent! highlight clear Mark' .. i)
    end
    state.cycle = math.max(1, math.min(state.cycle, num))
    if state.last_search > num then
      state.last_search = -1
    end
  end
  -- Ensure the pattern list contains exactly num entries.
  for i = #state.patterns, num + 1, -1 do
    state.patterns[i] = nil
  end
  for i = #state.patterns + 1, num do
    state.patterns[i] = ''
  end
  state.num_groups = num
end

local function window_matches(winid)
  local num = state.num_groups
  local matches = vim.w[winid].mw_match
  if matches == nil then
    matches = {}
    for i = 1, num do
      matches[i] = 0
    end
  elseif #matches ~= num then
    if #matches > num then
      -- Truncate the matches.
      for i = num + 1, #matches do
        if matches[i] > 0 then
          pcall(vim.fn.matchdelete, matches[i], winid)
        end
      end
      for i = #matches, num + 1, -1 do
        matches[i] = nil
      end
    else
      -- Expand the matches.
      for i = #matches + 1, num do
        matches[i] = 0
      end
    end
  end
  vim.w[winid].mw_match = matches
  return matches
end

local function apply_index(winid, index, pattern)
  local matches = window_matches(winid)
  if matches[index] > 0 then
    pcall(vim.fn.matchdelete, matches[index], winid)
    matches[index] = 0
  end

  if pattern ~= nil and pattern ~= '' then
    -- matchadd() does not consider 'ignorecase'; make the match according to
    -- the ignorecase config, honoring an explicit \C atom in the pattern.
    local expr = (util.is_ignorecase(pattern) and '\\c' or '') .. pattern
    -- Assign a different priority per group so that the order of highlighting
    -- is deterministic; the highest priority stays below 'hlsearch' (0).
    local priority = -10 - state.num_groups + 1 + (index - 1)
    vim.api.nvim_win_call(winid, function()
      matches[index] = vim.fn.matchadd('Mark' .. index, expr, priority)
    end)
  end
  vim.w[winid].mw_match = matches
end

--- (Re)apply all marks in a single window.
function M.apply_window(winid)
  for index = 1, state.num_groups do
    local pattern = (not state.enabled) and '' or (state.patterns[index] or '')
    apply_index(winid, index, pattern)
  end
end

--- (Re)apply all marks in all windows of the current tabpage.
function M.refresh()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    M.apply_window(winid)
  end
end

--- Set / clear a single mark group in all windows of the current tabpage.
function M.set_index_all_windows(index, pattern)
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    apply_index(winid, index, pattern)
  end
end

--- Remove all mark matches in all windows of the current tabpage.
function M.clear_all_matches()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local matches = vim.w[winid].mw_match
    if matches ~= nil then
      for i, id in ipairs(matches) do
        if id > 0 then
          pcall(vim.fn.matchdelete, id, winid)
        end
        matches[i] = 0
      end
      vim.w[winid].mw_match = matches
    end
  end
end

return M
