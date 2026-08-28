-- mark.nvim: highlight several words in different colors simultaneously.
-- Port of the mark.vim plugin by Ingo Karkat / Yuheng Xie to Lua for
-- Neovim 0.12+.

local state = require('mark.state')
local util = require('mark.util')

local M = {}

local defaults = {
  -- Explicit list of colors; group N uses colors[N]. A string entry is
  -- shorthand for { bg = ... }; a table entry is passed to nvim_set_hl().
  colors = nil,
  -- Used when colors == nil: 'original' | 'extended' | 'maximum'.
  palette = 'original',
  -- nil = follow &ignorecase (an explicit \C in a pattern always wins);
  -- true / false override the setting for marks.
  ignorecase = nil,
  -- Add set patterns to the search history.
  history = true,
  -- Define <kN> / <C-kN> direct group jump mappings for groups 1..N.
  group_jump_keys = 9,
  persistence = {
    enabled = true,
    auto_save = true,
    auto_load = false,
    path = vim.fn.stdpath('data') .. '/mark.json',
  },
  -- filetype → mark set; a string value names a stored slot, a table value is
  -- an inline pattern list. Activated when a buffer of that filetype is used.
  filetype_marks = {},
  -- Mappings; set to false to disable a default. The <Plug>(Mark*) mappings
  -- are always defined and can be used for custom mappings.
  keymaps = {
    mark = '<leader>m',
    regex = '<leader>r',
    clear = '<leader>n',
    all_clear = false,
    toggle = false,
    iwhite = false,
    current_next = '<leader>*',
    current_prev = '<leader>#',
    any_next = '<leader>/',
    any_prev = '<leader>?',
    next = '*',
    prev = '#',
    or_cur_next = false,
    or_cur_prev = false,
    or_any_next = false,
    or_any_prev = false,
    group_next = false,
    group_prev = false,
  },
}

local subcommands = { 'set', 'list', 'clear', 'toggle', 'save', 'load', 'palette' }

M._default_maps = {}

local function marks() return require('mark.marks') end
local function search() return require('mark.search') end
local function persistence() return require('mark.persistence') end
local function highlight() return require('mark.highlight') end

-- Command completion ----------------------------------------------------------

local function complete_patterns(arglead, group)
  local patterns
  if group > 0 and (state.patterns[group] or '') ~= '' then
    patterns = { state.patterns[group] }
  else
    patterns = {}
    for _, pattern in ipairs(state.patterns) do
      if pattern ~= '' and not vim.list_contains(patterns, pattern) then
        patterns[#patterns + 1] = pattern
      end
    end
  end

  -- Complete both the entire patterns and their individual alternatives.
  local expanded = {}
  for _, pattern in ipairs(patterns) do
    if not vim.list_contains(expanded, pattern) then
      expanded[#expanded + 1] = pattern
    end
    for _, alternative in ipairs(util.split_alternatives(pattern)) do
      if not vim.list_contains(expanded, alternative) then
        expanded[#expanded + 1] = alternative
      end
    end
  end

  -- Filter according to the argument lead; allow to omit the frequent
  -- initial \< atom.
  local ok, rx = pcall(vim.regex, [[^\%(\\<\)\?\V]] .. vim.fn.escape(arglead, '\\'))
  if not ok then
    return {}
  end
  return vim.tbl_filter(function(pattern)
    return rx:match_str(pattern) ~= nil
  end, expanded)
end

local function complete(arglead, cmdline, cursorpos)
  local before = cmdline:sub(1, cursorpos)
  local tokens = vim.split(vim.trim(before), '%s+', { trimempty = true })
  local ends_with_space = before:match('%s$') ~= nil
  -- Index of the token currently being completed.
  local position = #tokens + (ends_with_space and 1 or 0)
  local sub = tokens[2]
  if sub ~= nil then
    sub = sub:match('^(.-)!$') or sub
  end

  if position <= 2 then
    return vim.tbl_filter(function(name)
      return name:sub(1, #arglead) == arglead
    end, subcommands)
  end

  if sub == 'save' or sub == 'load' then
    if position == 3 then
      return persistence().complete_slots(arglead)
    end
  elseif sub == 'palette' then
    if position == 3 then
      return require('mark.palettes').complete_names(arglead)
    end
  elseif sub == 'clear' then
    if position == 3 then
      local options = { 'all' }
      for index = 1, state.num_groups do
        options[#options + 1] = tostring(index)
      end
      return vim.tbl_filter(function(name)
        return name:sub(1, #arglead) == arglead
      end, options)
    end
  elseif sub == 'set' then
    if position >= 3 then
      local group = 0
      local offset = 3
      if position > 3 and tokens[3]:match('^%d+$') then
        group = tonumber(tokens[3])
        offset = 4
      end
      if position >= offset then
        return complete_patterns(arglead, group)
      end
    end
  end
  return {}
end

-- :Mark command ---------------------------------------------------------------

local function command_mark(opts)
  local sub, rest = opts.args:match('^(%S+)%s*(.*)$')
  if sub == nil then
    util.error('Usage: Mark set|list|clear|toggle|save|load|palette [...]')
    return
  end
  -- The bang belongs to the subcommand (:Mark load!, :Mark set!).
  local bang = false
  local stripped = sub:match('^(.-)!$')
  if stripped then
    sub = stripped
    bang = true
  end

  if sub == 'set' then
    local group = 0
    local pattern = rest
    local group_text = rest:match('^(%d+)%s+%S')
    if group_text then
      group = tonumber(group_text)
      pattern = rest:match('^%d+%s+(.*)$')
    end
    if pattern == nil or pattern == '' then
      util.error('Usage: Mark set [group] {pattern}')
      return
    end
    local success, _, err = marks().set_mark(group, pattern, bang)
    if not success and err then
      util.error(err)
    end
  elseif sub == 'list' then
    marks().list()
  elseif sub == 'clear' then
    if rest == 'all' then
      marks().clear_all()
    elseif rest:match('^%d+$') then
      marks().do_mark(tonumber(rest), '')
    elseif rest == '' then
      marks().clear_current(0)
    else
      util.error('Usage: Mark clear [group|all]')
    end
  elseif sub == 'toggle' then
    marks().toggle()
  elseif sub == 'save' then
    local slot = rest ~= '' and rest or nil
    local used = persistence().save(slot)
    if used == 0 then
      util.warn('No marks defined')
    else
      util.info(string.format('Saved %d mark%s to slot "%s"', used, used == 1 and '' or 's', slot or 'default'))
    end
  elseif sub == 'load' then
    local slot = rest ~= '' and rest or nil
    local used, err
    if bang then
      -- Merge the slot into the current set instead of replacing it.
      used, err = persistence().merge(slot)
      if err == nil then
        util.info(string.format('Merged %d mark%s from slot "%s"%s', used, used == 1 and '' or 's',
          slot or 'default', state.enabled and '' or '; marks currently disabled'))
      end
    else
      used, err = persistence().load(slot)
      if err == nil then
        util.info(string.format('Loaded %d mark%s%s', used, used == 1 and '' or 's',
          state.enabled and '' or '; marks currently disabled'))
      end
    end
    if err then
      util.error(err)
    end
  elseif sub == 'palette' then
    M.set_palette(rest)
  else
    util.error('Unknown subcommand: ' .. sub)
  end
end

--- Switch to a built-in palette at runtime (groups are re-counted).
function M.set_palette(name)
  local palettes = require('mark.palettes')
  local palette = palettes[name]
  if type(palette) ~= 'table' then
    util.error('Unknown palette: ' .. tostring(name)
      .. ' (available: ' .. table.concat(palettes.names(), ', ') .. ')')
    return
  end
  highlight().define_colors(palette)
  highlight().reinit(#palette)
  highlight().refresh()
end

-- Registration ----------------------------------------------------------------

local function define_plug(mode, name, fn, desc)
  vim.keymap.set(mode, '<Plug>(' .. name .. ')', fn, { silent = true, desc = 'Mark: ' .. desc })
end

local function define_default(mode, lhs, name, desc)
  if not lhs then
    return
  end
  local plug = '<Plug>(' .. name .. ')'
  if vim.fn.hasmapto(plug, mode) == 0 then
    vim.keymap.set(mode, lhs, plug, { silent = true, remap = true, desc = 'Mark: ' .. desc })
    M._default_maps[#M._default_maps + 1] = { mode = mode, lhs = lhs }
  end
end

local function exit_visual_mode()
  -- The original plugin's {Visual} mappings implicitly ended Visual mode (the
  -- leading ':' of their Ex commands). This has to happen synchronously: an
  -- <Esc> merely pushed into the typeahead would be consumed by a prompt
  -- opened right after (e.g. vim.ui.input), closing it again immediately.
  if vim.fn.mode():match('^[vV\22]$') then
    vim.cmd([[execute "normal! \<Esc>"]])
  end
end

local function register_keymaps(cfg)
  -- Remove defaults from a previous setup() call (user mappings survive).
  for _, map in ipairs(M._default_maps) do
    pcall(vim.keymap.del, map.mode, map.lhs)
  end
  M._default_maps = {}

  local keys = cfg.keymaps

  define_plug('n', 'MarkSet', function() marks().mark_current_word(vim.v.count) end, 'Mark word under cursor')
  define_plug('x', 'MarkSet', function()
    marks().mark_selection(vim.v.count)
    exit_visual_mode()
  end, 'Mark selection')
  define_plug('n', 'MarkRegex', function() marks().mark_regex(vim.v.count, '') end, 'Mark by regexp')
  define_plug('x', 'MarkRegex', function()
    -- Capture the count and the preset before leaving Visual mode: the
    -- synchronous <Esc> resets v:count.
    local count, preset = vim.v.count, marks().visual_text_regexp()
    exit_visual_mode()
    marks().mark_regex(count, preset)
  end, 'Mark selection by regexp')
  define_plug('x', 'MarkIWhiteSet', function()
    marks().mark_selection_whitespace_indifferent(vim.v.count)
    exit_visual_mode()
  end, 'Mark selection (whitespace-indifferent)')
  define_plug('n', 'MarkClear', function() marks().clear_current(vim.v.count) end, 'Clear current mark')
  define_plug('n', 'MarkAllClear', function() marks().clear_all() end, 'Clear all marks')
  define_plug('n', 'MarkToggle', function() marks().toggle() end, 'Toggle mark display')

  define_plug('n', 'MarkSearchCurrentNext', function() search().search_current_mark(false) end, 'Search current mark')
  define_plug('n', 'MarkSearchCurrentPrev', function() search().search_current_mark(true) end, 'Search current mark backwards')
  define_plug('n', 'MarkSearchAnyNext', function() search().search_any_mark(false) end, 'Search any mark')
  define_plug('n', 'MarkSearchAnyPrev', function() search().search_any_mark(true) end, 'Search any mark backwards')
  define_plug('n', 'MarkSearchNext', function()
    if not search().search_next(false) then
      vim.cmd('normal! *zv')
    end
  end, 'Search mark or word under cursor')
  define_plug('n', 'MarkSearchPrev', function()
    if not search().search_next(true) then
      vim.cmd('normal! #zv')
    end
  end, 'Search mark or word under cursor backwards')
  define_plug('n', 'MarkSearchOrCurNext', function() search().search_next(false, search().search_current_mark) end, 'Search current mark')
  define_plug('n', 'MarkSearchOrCurPrev', function() search().search_next(true, search().search_current_mark) end, 'Search current mark backwards')
  define_plug('n', 'MarkSearchOrAnyNext', function() search().search_next(false, search().search_any_mark) end, 'Search any mark')
  define_plug('n', 'MarkSearchOrAnyPrev', function() search().search_next(true, search().search_any_mark) end, 'Search any mark backwards')
  define_plug('n', 'MarkSearchGroupNext', function() search().search_group_mark(vim.v.count, vim.v.count1, false, true) end, 'Search mark group')
  define_plug('n', 'MarkSearchGroupPrev', function() search().search_group_mark(vim.v.count, vim.v.count1, true, true) end, 'Search mark group backwards')

  for index = 1, cfg.group_jump_keys do
    define_plug('n', ('MarkSearchGroup%dNext'):format(index), function()
      search().search_group_mark(index, vim.v.count1, false, true)
    end, ('Search mark group %d'):format(index))
    define_plug('n', ('MarkSearchGroup%dPrev'):format(index), function()
      search().search_group_mark(index, vim.v.count1, true, true)
    end, ('Search mark group %d backwards'):format(index))
  end

  define_default('n', keys.mark, 'MarkSet', 'Mark word under cursor')
  define_default('x', keys.mark, 'MarkSet', 'Mark selection')
  define_default('n', keys.regex, 'MarkRegex', 'Mark by regexp')
  define_default('x', keys.regex, 'MarkRegex', 'Mark selection by regexp')
  define_default('x', keys.iwhite, 'MarkIWhiteSet', 'Mark selection (whitespace-indifferent)')
  define_default('n', keys.clear, 'MarkClear', 'Clear current mark')
  define_default('n', keys.all_clear, 'MarkAllClear', 'Clear all marks')
  define_default('n', keys.toggle, 'MarkToggle', 'Toggle mark display')
  define_default('n', keys.current_next, 'MarkSearchCurrentNext', 'Search current mark')
  define_default('n', keys.current_prev, 'MarkSearchCurrentPrev', 'Search current mark backwards')
  define_default('n', keys.any_next, 'MarkSearchAnyNext', 'Search any mark')
  define_default('n', keys.any_prev, 'MarkSearchAnyPrev', 'Search any mark backwards')
  define_default('n', keys.next, 'MarkSearchNext', 'Search mark or word under cursor')
  define_default('n', keys.prev, 'MarkSearchPrev', 'Search mark or word under cursor backwards')
  define_default('n', keys.or_cur_next, 'MarkSearchOrCurNext', 'Search current mark')
  define_default('n', keys.or_cur_prev, 'MarkSearchOrCurPrev', 'Search current mark backwards')
  define_default('n', keys.or_any_next, 'MarkSearchOrAnyNext', 'Search any mark')
  define_default('n', keys.or_any_prev, 'MarkSearchOrAnyPrev', 'Search any mark backwards')
  define_default('n', keys.group_next, 'MarkSearchGroupNext', 'Search mark group')
  define_default('n', keys.group_prev, 'MarkSearchGroupPrev', 'Search mark group backwards')

  -- Direct group jumps on the numeric keypad.
  for index = 1, cfg.group_jump_keys do
    define_default('n', ('<k%d>'):format(index), ('MarkSearchGroup%dNext'):format(index),
      ('Search mark group %d'):format(index))
    define_default('n', ('<C-k%d>'):format(index), ('MarkSearchGroup%dPrev'):format(index),
      ('Search mark group %d backwards'):format(index))
  end
end

local function register_commands()
  vim.api.nvim_create_user_command('Mark', command_mark, {
    nargs = '*',
    desc = 'Highlight several words in different colors',
    complete = complete,
  })
end

local function register_autocmds()
  local group = vim.api.nvim_create_augroup('Mark', { clear = true })

  vim.api.nvim_create_autocmd('WinEnter', {
    group = group,
    desc = 'Mark: apply marks to a newly entered window',
    callback = function()
      if vim.w.mw_match == nil or #vim.w.mw_match ~= state.num_groups then
        highlight().apply_window(0)
      end
    end,
  })

  vim.api.nvim_create_autocmd('TabNewEntered', {
    group = group,
    desc = 'Mark: apply marks to a new tabpage',
    callback = function()
      highlight().refresh()
    end,
  })

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    desc = 'Mark: re-define the mark highlight groups',
    callback = function()
      highlight().define_colors(state.colors)
    end,
  })

  vim.api.nvim_create_autocmd({ 'FileType', 'BufEnter' }, {
    group = group,
    desc = 'Mark: activate the mark set configured for this filetype',
    callback = function(args)
      if args.buf == vim.api.nvim_get_current_buf() then
        persistence().activate_filetype(vim.bo[args.buf].filetype)
      end
    end,
  })
end

-- Public API ------------------------------------------------------------------

--- Access the number of mark groups.
function M.groups()
  return state.num_groups
end

--- Access the current / passed group's pattern (empty string when unused).
function M.pattern(index)
  if index ~= nil then
    return state.patterns[index] or ''
  end
  return state.last_search ~= -1 and state.patterns[state.last_search] or ''
end

--- Command completion for :Mark (exposed for tests and custom commands).
M.complete = complete

--- Configure the plugin. Can be called again to (re)configure.
function M.setup(opts)
  local cfg = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
  state.config = cfg

  -- Resolve the colors: explicit table, else a built-in palette.
  local colors = cfg.colors
  if colors == nil then
    local palettes = require('mark.palettes')
    colors = palettes[cfg.palette]
    if type(colors) ~= 'table' then
      if cfg.palette ~= nil and cfg.palette ~= '' then
        util.warn('Unknown palette "' .. tostring(cfg.palette) .. '", using "original"')
      end
      colors = palettes.original
    end
  elseif type(colors) ~= 'table' or #colors == 0 then
    util.error('colors must be a non-empty list; using the "original" palette')
    colors = require('mark.palettes').original
  end

  highlight().define_colors(colors)
  highlight().reinit(#colors)

  vim.g.mark_configured = true

  register_autocmds()
  register_commands()
  register_keymaps(cfg)

  if cfg.persistence.auto_load then
    local used, err = persistence().load('default')
    if err == nil then
      highlight().refresh()
    end
  else
    highlight().refresh()
  end
end

return M
