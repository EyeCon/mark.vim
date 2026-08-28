-- Small shared helpers for mark.nvim.

local M = {}

--- Whether patterns should be matched case-insensitively.
-- Honors `ignorecase` config (nil = follow &ignorecase) and an explicit
-- case-sensitive atom `\C` in the pattern (when not preceded by a backslash).
function M.is_ignorecase(pattern)
  local cfg = require('mark.state').config
  local ignorecase = (cfg.ignorecase == nil) and vim.o.ignorecase or cfg.ignorecase
  if not ignorecase then
    return false
  end
  local pos = 1
  while true do
    local s = pattern:find('\\C', pos, true)
    if not s then
      return true
    end
    if s == 1 or pattern:sub(s - 1, s - 1) ~= '\\' then
      return false
    end
    pos = s + 2
  end
end

--- Escape literal text for use in a magic regular expression.
function M.escape_text(text)
  return (vim.fn.escape(text, '\\^$.*[~'):gsub('\n', '\\n'))
end

--- Whitespace-indifferent variant: runs of whitespace become `\_s\+`.
function M.escape_text_whitespace_indifferent(text)
  return (vim.fn.escape(text, '\\^$.*[~'):gsub('%s+', '\\_s\\+'))
end

--- Split a pattern into its alternatives (only on unescaped `\|`).
function M.split_alternatives(pattern)
  local alternatives = {}
  local start = 1
  local pos = 1
  while true do
    local s, e = pattern:find('\\|', pos, true)
    if not s then
      break
    end
    local backslashes = 0
    local i = s - 1
    while i >= 1 and pattern:sub(i, i) == '\\' do
      backslashes = backslashes + 1
      i = i - 1
    end
    if backslashes % 2 == 0 then
      alternatives[#alternatives + 1] = pattern:sub(start, s - 1)
      start = e + 1
    end
    pos = e + 1
  end
  alternatives[#alternatives + 1] = pattern:sub(start)
  return alternatives
end

--- Compare a {line, col} position with a possibly empty position list.
function M.eq_pos(a, b)
  return type(a) == 'table'
    and type(b) == 'table'
    and a[1] ~= nil
    and b[1] ~= nil
    and a[1] == b[1]
    and a[2] == b[2]
end

--- Strip the Vim exception source info from an error message.
function M.vim_error_text(err)
  return (err:gsub('^Vim%b():', ''):gsub('^Vim:', ''))
end

function M.error(msg)
  vim.notify('mark.nvim: ' .. msg, vim.log.levels.ERROR)
end

function M.warn(msg)
  vim.notify('mark.nvim: ' .. msg, vim.log.levels.WARN)
end

function M.info(msg)
  vim.api.nvim_echo({ { msg } }, true, {})
end

return M
