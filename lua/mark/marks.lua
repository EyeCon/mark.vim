-- Core mark operations for mark.nvim: setting, clearing, toggling, listing
-- and current-mark detection.

local state = require('mark.state')
local util = require('mark.util')
local highlight = require('mark.highlight')

local M = {}

local function echo(chunks)
  vim.api.nvim_echo(chunks, true, {})
end

local function echo_mark(group_num, regexp)
  echo({ { 'mark-' .. group_num, 'MoreMsg' }, { ' ' .. regexp } })
end

local function echo_mark_cleared(group_num)
  echo({ { 'mark-' .. group_num, 'MoreMsg' }, { ' cleared' } })
end

local function used_count()
  local count = 0
  for _, pattern in ipairs(state.patterns) do
    if pattern ~= '' then
      count = count + 1
    end
  end
  return count
end

local function set_pattern(index, pattern)
  state.patterns[index] = pattern
  require('mark.persistence').auto_save()
end

--- Enable / disable mark display (patterns are kept when disabled).
function M.enable(enable, do_refresh)
  if state.enabled ~= enable then
    state.enabled = enable
    require('mark.persistence').auto_save()
    if do_refresh ~= false then
      highlight.refresh()
    end
  end
end

--- Index (1-based) of the next mark group: first unused group, or the cycling
-- group when all are in use.
function M.next_group_index()
  for index = 1, state.num_groups do
    if state.patterns[index] == '' then
      return index
    end
  end
  return state.cycle
end

local function group_label(index, next_index)
  local marker = ''
  if state.last_search == index then
    marker = marker .. '/'
  end
  if index == next_index then
    marker = marker .. '>'
  end
  local count = #util.split_alternatives(state.patterns[index])
  local count_text = count == 0 and '' or (count == 1 and '*' or count .. '*')
  return string.format('%s%s%2d', marker, count_text, index)
end

--- Let the user select a mark group interactively; calls cb(group_num | nil).
function M.query_group(cb)
  local next_index = M.next_group_index()
  vim.ui.select(vim.fn.range(1, state.num_groups), {
    prompt = 'Mark group:',
    format_item = function(index)
      return group_label(index, next_index)
    end,
  }, cb)
end

--- Set or clear a mark pattern.
-- group_num 0 = automatic group choice (or a query when a count exceeded the
-- number of groups), 1..num_groups addresses a specific group. An empty
-- regexp with group_num 0 disables all marks; with a group number it clears
-- that group. Returns (success, group_num_used); when an interactive group
-- query is needed, cb(success, group_num_used) is invoked asynchronously.
function M.do_mark(group_num, regexp, cb)
  local done = cb or function() end
  if state.num_groups <= 0 then
    util.error('No mark highlight groups are defined')
    done(false, 0)
    return false, 0
  end

  local group = group_num or 0
  if group > state.num_groups then
    M.query_group(function(chosen)
      if chosen then
        M.do_mark(chosen, regexp, cb)
      else
        done(false, 0)
      end
    end)
    return
  end

  regexp = regexp or ''

  if regexp == '' then
    if group == 0 then
      M.enable(false)
      echo({ { 'All marks disabled' } })
    else
      M.clear_group(group)
      echo_mark_cleared(group)
    end
    done(true, 0)
    return true, 0
  end

  if group == 0 then
    -- Clear the mark if the pattern has already been marked (toggle-off).
    for index = 1, state.num_groups do
      if regexp == state.patterns[index] then
        M.clear_group(index)
        echo_mark_cleared(index)
        done(true, 0)
        return true, 0
      end
    end
  else
    -- Add / subtract the pattern as an alternative of the group.
    local existing = state.patterns[group]
    if existing ~= '' then
      local alternatives = util.split_alternatives(existing)
      if not vim.list_contains(alternatives, regexp) then
        regexp = existing .. '\\|' .. regexp
      else
        local kept = vim.tbl_filter(function(alternative)
          return alternative ~= regexp
        end, alternatives)
        if #kept == 0 then
          M.clear_group(group)
          echo_mark_cleared(group)
          done(true, 0)
          return true, 0
        end
        regexp = table.concat(kept, '\\|')
      end
    end
  end

  if state.config.history then
    vim.fn.histadd('/', regexp)
  end

  local index
  if group == 0 then
    local free = -1
    for i = 1, state.num_groups do
      if state.patterns[i] == '' then
        free = i
        break
      end
    end
    if free ~= -1 then
      -- Choose an unused highlight group; the last search is kept untouched.
      index = free
      state.cycle = (free % state.num_groups) + 1
      set_pattern(index, regexp)
    else
      -- Choose a highlight group by cycle; the last search is reset.
      index = state.cycle
      state.cycle = (index % state.num_groups) + 1
      if state.last_search == index then
        state.last_search = -1
      end
      set_pattern(index, regexp)
    end
  else
    -- Use and extend the passed highlight group.
    index = group
    set_pattern(index, regexp)
  end

  if state.enabled then
    highlight.set_index_all_windows(index, regexp)
  else
    M.enable(true)
  end

  echo_mark(index, regexp)
  done(true, index)
  return true, index
end

--- Clear a single mark group (and reset the last search when it pointed at it).
function M.clear_group(index)
  if state.last_search == index then
    state.last_search = -1
  end
  set_pattern(index, '')
  if state.enabled then
    highlight.set_index_all_windows(index, '')
  else
    -- Like the original plugin, clearing a group re-enables the display of
    -- the remaining marks.
    M.enable(true)
  end
end

--- Clear all marks in all groups.
function M.clear_all()
  local indices = {}
  for index = 1, state.num_groups do
    if state.patterns[index] ~= '' then
      set_pattern(index, '')
      indices[#indices + 1] = index
    end
  end
  state.last_search = -1

  -- Not strictly necessary (all marks have just been cleared), but keeps the
  -- enabled state consistent for persistence.
  M.enable(false, false)

  highlight.clear_all_matches()

  if #indices > 0 then
    echo({ { 'Cleared all ' .. #indices .. ' marks' } })
  else
    echo({ { 'All marks cleared' } })
  end
end

--- Returns nil when the regexp is valid, else the error text.
function M.validate_regexp(regexp)
  local ok, err = pcall(vim.fn.match, '', regexp)
  if not ok then
    return util.vim_error_text(err)
  end
  return nil
end

--- Like do_mark(), but also sets the current mark to the used group and
-- validates the regexp first. Returns (success, group_num_used, error_text).
function M.do_mark_and_set_current(group_num, regexp, cb)
  if regexp and regexp ~= '' then
    local err = M.validate_regexp(regexp)
    if err then
      if cb then
        cb(false, 0)
      end
      return false, 0, 'Invalid regular expression: ' .. err
    end
  end

  return M.do_mark(group_num, regexp, function(success, group)
    if success and group > 0 then
      state.last_search = group
    end
    if cb then
      cb(success, group)
    end
  end)
end

--- Like do_mark_and_set_current(), but for Ex commands: never queries for a
-- mark group, returns an error text instead. With force, an already marked
-- pattern is kept (no toggle-off). Returns (success, group_num_used, error).
function M.set_mark(group_num, regexp, force)
  if state.num_groups > 0 and group_num > state.num_groups then
    return false, 0, string.format('Only %d mark highlight groups are defined', state.num_groups)
  end
  if regexp and regexp ~= '' then
    local err = M.validate_regexp(regexp)
    if err then
      return false, 0, 'Invalid regular expression: ' .. err
    end
  end
  if force and (group_num or 0) == 0 then
    for index = 1, state.num_groups do
      if regexp == state.patterns[index] then
        -- Already marked: keep it, just make it the current mark.
        state.last_search = index
        echo_mark(index, regexp)
        return true, index
      end
    end
  end
  return M.do_mark_and_set_current(group_num, regexp)
end

--- Return [pattern, {line, col}, index] of the mark under the cursor
-- (or ['', {}, -1]). Marks that span multiple lines are not supported.
function M.current_mark()
  local line = vim.api.nvim_get_current_line() .. '\n'
  local col = vim.fn.col('.')

  -- Higher group numbers take precedence; to retrieve the visible mark in
  -- case of overlapping marks, check from highest to lowest group.
  for index = state.num_groups, 1, -1 do
    local pattern = state.patterns[index]
    if pattern ~= nil and pattern ~= '' then
      local match_pattern = (util.is_ignorecase(pattern) and '\\c' or '\\C') .. pattern
      -- Note: col() is 1-based, the match() start is 0-based.
      local start = 0
      while start >= 0 and start < #line and start < col do
        local b = vim.fn.match(line, match_pattern, start)
        local e = vim.fn.matchend(line, match_pattern, start)
        if b < col and col <= e then
          return pattern, { vim.fn.line('.'), b + 1 }, index
        end
        if b == e then
          break
        end
        start = e
      end
    end
  end
  return '', {}, -1
end

--- Mark the word under the cursor (like the star command); if the cursor is
-- on an existing mark, remove that mark instead.
function M.mark_current_word(group_num)
  local regexp = (group_num == 0) and (M.current_mark()) or ''
  if regexp == '' then
    local cword = vim.fn.expand('<cword>')
    if cword ~= '' then
      regexp = util.escape_text(cword)
      -- Like the star command, only create a \<whole word\> pattern when the
      -- word consists solely of keyword characters.
      if vim.fn.match(cword, [[^\k\+$]]) == 0 then
        regexp = '\\<' .. regexp .. '\\>'
      end
    end
  end
  if regexp == '' then
    return false
  end
  return (M.do_mark(group_num, regexp))
end

--- Clear the mark under the cursor (or the passed group, or disable all
-- marks when there is neither).
function M.clear_current(group_num)
  if group_num > 0 then
    M.do_mark(group_num, '')
  else
    M.do_mark(0, (M.current_mark()))
  end
end

--- Return the visually selected text (without clobbering any register).
function M.visual_text()
  local mode = vim.fn.mode()
  local pos1, pos2
  if mode == 'v' or mode == 'V' or mode == '\22' then
    -- Active Visual selection: the '< / '> marks are not set until Visual
    -- mode ends; use the visual start mark and the cursor position instead.
    pos1, pos2 = vim.fn.getpos('v'), vim.fn.getpos('.')
  else
    -- Called after Visual mode has ended; fall back to the last selection.
    mode = vim.fn.visualmode()
    pos1, pos2 = vim.fn.getpos("'<"), vim.fn.getpos("'>")
  end
  pos1[1] = vim.api.nvim_get_current_buf()
  pos2[1] = pos1[1]
  -- getregion() expects the region bounds in order.
  if pos2[2] < pos1[2] or (pos2[2] == pos1[2] and pos2[3] < pos1[3]) then
    pos1, pos2 = pos2, pos1
  end
  local ok, lines = pcall(vim.fn.getregion, pos1, pos2, { type = mode })
  if not ok or type(lines) ~= 'table' then
    return ''
  end
  local text = table.concat(lines, '\n')
  if mode == 'V' then
    text = text .. '\n'
  end
  return text
end

function M.visual_text_regexp()
  return (M.visual_text():gsub('\n', ''))
end

--- Mark the visual selection as a literal pattern.
function M.mark_selection(group_num)
  return (M.do_mark(group_num, util.escape_text(M.visual_text())))
end

--- Mark the visual selection as a regular expression.
function M.mark_selection_regexp(group_num)
  return (M.do_mark(group_num, M.visual_text_regexp()))
end

--- Mark the visual selection as a literal whitespace-indifferent pattern.
function M.mark_selection_whitespace_indifferent(group_num)
  return (M.do_mark(group_num, util.escape_text_whitespace_indifferent(M.visual_text())))
end

--- Query a pattern interactively and mark it.
function M.mark_regex(group_num, regexp_preset)
  vim.ui.input({ prompt = 'Input pattern to mark: ', default = regexp_preset or '' }, function(regexp)
    if regexp ~= nil and regexp ~= '' then
      vim.cmd('redraw')
      M.do_mark_and_set_current(group_num, regexp)
    end
  end)
end

--- Toggle display of all marks (patterns are kept).
function M.toggle()
  if state.enabled then
    M.enable(false)
    echo({ { 'Disabled marks' } })
  else
    M.enable(true)
    local count = used_count()
    echo({ { count > 0 and ('Enabled ' .. count .. ' marks') or 'Enabled marks' } })
  end
end

--- Print all mark highlight groups and their patterns.
function M.list()
  local next_index = M.next_group_index()
  local chunks = {
    { 'mark  cnt  Pattern', 'Title' },
    { '\n  (> next mark group   / current search mark)' },
  }
  for index = 1, state.num_groups do
    local count = #util.split_alternatives(state.patterns[index])
    local marker = (state.last_search == index and '/' or '') .. (index == next_index and '>' or '')
    local count_text = count > 1 and ('(' .. count .. ')') or ''
    chunks[#chunks + 1] = {
      string.format('\n%1s%3d%4s %s', marker, index, count_text, state.patterns[index]),
      'Mark' .. index,
    }
  end
  if not state.enabled then
    chunks[#chunks + 1] = { '\nMarks are currently disabled.', 'MoreMsg' }
  end
  echo(chunks)
end

return M
