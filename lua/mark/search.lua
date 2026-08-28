-- Search and jump functionality for mark.nvim: behaves like the built-in
-- search commands (counts, wrap messages, jumplist, fold opening).

local state = require('mark.state')
local util = require('mark.util')
local marks = require('mark.marks')

local M = {}

local function trim(message)
  local half = math.floor(vim.o.columns / 2)
  if #message > half then
    return message:sub(1, half) .. '...'
  end
  return message
end

local function wrap_message(search_type, pattern, is_backward)
  vim.cmd('redraw')
  local message = string.format(
    '%s search hit %s, continuing at %s',
    search_type,
    is_backward and 'TOP' or 'BOTTOM',
    is_backward and 'BOTTOM' or 'TOP'
  )
  vim.api.nvim_echo({ { trim(message), 'WarningMsg' } }, true, {})
end

local function echo_search_pattern(search_type, pattern, is_backward)
  vim.api.nvim_echo({
    { search_type, 'MoreMsg' },
    { ' ' .. trim((is_backward and '?' or '/') .. pattern) },
  }, true, {})
end

local function error_message(search_type, pattern, is_backward)
  if vim.o.wrapscan then
    util.error(search_type .. ' not found: ' .. pattern)
  else
    util.error(string.format(
      '%s search hit %s without match for: %s',
      search_type,
      is_backward and 'TOP' or 'BOTTOM',
      pattern
    ))
  end
end

local function any_mark()
  local parts = {}
  for _, pattern in ipairs(state.patterns) do
    if pattern ~= '' then
      parts[#parts + 1] = pattern
    end
  end
  return table.concat(parts, '\\|')
end

--- Wrapper around searchpos() with count, backward search, wrap detection,
-- jumplist update, fold opening and search / error messages.
function M.search(pattern, count, is_backward, current_mark_position, search_type)
  if pattern == nil or pattern == '' then
    util.error('No marks defined')
    return false
  end

  local save_view = vim.fn.winsaveview()

  -- searchpos() obeys 'smartcase', which doesn't make sense for mark search;
  -- force the correct case-matching behavior via \c / \C instead.
  local search_pattern = (util.is_ignorecase(pattern) and '\\c' or '\\C') .. pattern

  local remaining = count
  local is_wrapped = false
  local is_match = false
  local line, col = 0, 0

  while remaining > 0 do
    local prev_line, prev_col = vim.fn.line('.'), vim.fn.col('.')

    local found = vim.fn.searchpos(search_pattern, is_backward and 'b' or '')
    line, col = found[1], found[2]

    if is_backward
      and line > 0
      and util.eq_pos({ line, col }, current_mark_position)
      and remaining == count
    then
      -- On a backward search, the first match is the start of the current
      -- mark (if the cursor was anywhere inside the mark text). The mark text
      -- is one entity, so the search is retried without decreasing the count,
      -- but only if this is the first match; if we have been here before
      -- (l:is_match), there is only the current mark in the buffer and the
      -- search wrapped around without finding another mark.
      if is_match then
        is_wrapped = true
        break
      end
      is_match = true
    elseif line > 0 then
      is_match = true
      remaining = remaining - 1

      -- Note: no need to check 'wrapscan'; the wrapping can only occur if
      -- 'wrapscan' is actually on.
      if not is_backward and (prev_line > line or (prev_line == line and prev_col >= col)) then
        is_wrapped = true
      elseif is_backward and (prev_line < line or (prev_line == line and prev_col <= col)) then
        is_wrapped = true
      end
    else
      break
    end
  end

  -- We're not stuck when the search wrapped around and landed on the current
  -- mark; that's why a possible wrap-around via count == 1 is excluded.
  local is_stuck = count == 1 and util.eq_pos({ line, col }, current_mark_position)

  if line > 0 and not is_stuck then
    local match_position = vim.fn.getpos('.')

    -- Open the fold at the search result, like the built-in commands.
    vim.cmd('normal! zv')

    -- Add the original cursor position to the jump list, like the built-in
    -- [/?*#nN] commands: memorize the match position, restore the view to the
    -- state before the search, set the jump, then jump to the match.
    vim.fn.winrestview(save_view)
    vim.cmd("normal! m'")
    vim.fn.setpos('.', match_position)

    -- Enable marks (in case they were disabled) after arriving at the mark.
    marks.enable(true)

    if is_wrapped then
      wrap_message(search_type, pattern, is_backward)
    else
      echo_search_pattern(search_type, pattern, is_backward)
    end
    return true
  else
    if is_match then
      -- The view has been changed by moving through matches until the end /
      -- start of file, when 'nowrapscan' forced a stop of searching before
      -- the count'th match was found. Restore the view.
      vim.fn.winrestview(save_view)
    end

    marks.enable(true)

    if line > 0 and is_stuck and is_wrapped then
      wrap_message(search_type, pattern, is_backward)
      return true
    else
      error_message(search_type, pattern, is_backward)
      return false
    end
  end
end

--- Search any mark.
function M.search_any_mark(is_backward)
  local _, mark_position = marks.current_mark()
  state.last_search = -1
  return M.search(any_mark(), vim.v.count1, is_backward, mark_position, 'mark-*')
end

--- Search the mark the cursor is on; falls back to any-mark / last search.
function M.search_current_mark(is_backward)
  local mark_text, mark_position, mark_index = marks.current_mark()
  if mark_text == '' then
    if state.last_search == -1 then
      local result = M.search_any_mark(is_backward)
      state.last_search = (select(3, marks.current_mark()))
      return result
    end
    return M.search(state.patterns[state.last_search], vim.v.count1, is_backward, {},
      'mark-' .. state.last_search)
  end

  local result = M.search(mark_text, vim.v.count1, is_backward, mark_position,
    'mark-' .. mark_index .. (mark_index == state.last_search and '' or '!'))
  state.last_search = mark_index
  return result
end

--- Like the built-in * / #, but for marks; without a search type, the type
-- depends on the last use of the current / any-mark search. Returns false
-- when the cursor is not on a mark (so the mapping can fall back to the
-- built-in * / #).
function M.search_next(is_backward, search_fn)
  local mark_text = marks.current_mark()
  if mark_text == '' then
    return false
  end
  local fn = search_fn or (state.last_search == -1 and M.search_any_mark or M.search_current_mark)
  fn(is_backward)
  return true
end

--- Search a particular mark group (or the current / last search when
-- group_num is 0).
function M.search_group_mark(group_num, count, is_backward, set_last_search)
  local mark_index, mark_text, mark_position

  if group_num == 0 then
    -- No mark group number specified; use the last search, and fall back to
    -- the current mark if possible.
    if state.last_search == -1 then
      mark_text, mark_position, mark_index = marks.current_mark()
      if mark_text == '' then
        return false
      end
    else
      mark_index = state.last_search
      mark_text = state.patterns[mark_index]
      mark_position = {}
    end
  else
    local group = group_num
    if group > state.num_groups then
      -- This highlight group does not exist; query the user.
      marks.query_group(function(chosen)
        if chosen then
          M.search_group_mark(chosen, count, is_backward, set_last_search)
        end
      end)
      return
    end

    mark_index = group
    mark_text = state.patterns[mark_index]
    mark_position = {}
  end

  local result = M.search(mark_text, count, is_backward, mark_position,
    'mark-' .. mark_index .. (mark_index == state.last_search and '' or '!'))
  if set_last_search then
    state.last_search = mark_index
  end
  return result
end

return M
