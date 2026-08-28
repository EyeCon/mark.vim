-- Persistence for mark.nvim: global mark sets stored as named slots in a
-- JSON file, plus activation of per-filetype mark sets from the configuration.

local state = require('mark.state')
local util = require('mark.util')
local highlight = require('mark.highlight')

local M = {}

local DEFAULT_SLOT = 'default'

local function used_count()
  local count = 0
  for _, pattern in ipairs(state.patterns) do
    if pattern ~= '' then
      count = count + 1
    end
  end
  return count
end

local function read_data()
  local file = io.open(state.config.persistence.path, 'r')
  if file == nil then
    return {}
  end
  local content = file:read('*a')
  file:close()
  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= 'table' then
    return {}
  end
  return data
end

local function write_data(data)
  -- The "p" flag creates missing parent directories.
  vim.fn.writefile({ vim.json.encode(data) }, state.config.persistence.path, 'p')
end

--- Save the current mark set into a slot. Returns the number of used marks.
function M.save(slot_name)
  local data = read_data()
  data.slots = data.slots or {}
  local slot = slot_name or DEFAULT_SLOT
  local used = used_count()
  if used == 0 and slot_name ~= nil then
    -- Like the original plugin: saving an empty set removes a named slot.
    data.slots[slot] = nil
  else
    data.slots[slot] = {
      patterns = vim.deepcopy(state.patterns),
      enabled = state.enabled,
    }
  end
  write_data(data)
  return used
end

--- Auto-save into the default slot (called after every mark change).
function M.auto_save()
  if not (state.config.persistence.enabled and state.config.persistence.auto_save) then
    return
  end
  M.save(DEFAULT_SLOT)
end

--- Apply a pattern list to the current state (trimmed / padded to the number
-- of groups) and refresh all windows. Returns the number of used marks.
function M.apply(patterns, enabled)
  local trimmed = {}
  for index = 1, math.min(#patterns, state.num_groups) do
    trimmed[index] = tostring(patterns[index])
  end
  for index = #trimmed + 1, state.num_groups do
    trimmed[index] = ''
  end

  state.patterns = trimmed
  state.enabled = (enabled == nil) and true or (enabled and true or false)

  highlight.refresh()

  return used_count()
end

--- Load a slot into the current mark set. Returns (used_count, error_text).
function M.load(slot_name)
  local slot = slot_name or DEFAULT_SLOT
  local data = read_data()
  local stored = data.slots and data.slots[slot]
  if type(stored) ~= 'table' or type(stored.patterns) ~= 'table' then
    return 0, string.format('No marks stored in slot "%s"', slot)
  end
  return M.apply(stored.patterns, stored.enabled), nil
end

--- Names of all stored slots (sorted).
function M.slot_names()
  local data = read_data()
  local names = {}
  if type(data.slots) == 'table' then
    for name in pairs(data.slots) do
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

function M.complete_slots(arglead)
  return vim.tbl_filter(function(name)
    return name:sub(1, #arglead) == arglead
  end, M.slot_names())
end

--- Activate the mark set configured for a filetype (config.filetype_marks).
-- A string value names a stored slot; a table value is an inline pattern
-- list. Filetypes without a mapping leave the current set untouched.
function M.activate_filetype(filetype)
  local mapped = state.config.filetype_marks[filetype]
  if mapped == nil then
    return
  end
  if type(mapped) == 'string' then
    local _, err = M.load(mapped)
    if err then
      util.warn(err)
    end
  elseif type(mapped) == 'table' then
    M.apply(mapped, true)
  else
    util.warn('Invalid filetype_marks entry for filetype "' .. filetype .. '"')
  end
end

return M
