# Project memories

## Overview
- **mark.nvim** (was mark.vim v2.8.4): Lua port (2026-08) of Ingo Karkat's Vimscript plugin (orig. Yuheng Xie, vimscript #1238) — highlights multiple words/regexps in different colors simultaneously via `matchadd()`. Requires **Neovim 0.12+**; pure Lua, no Vimscript left.
- VCS: **Jujutsu (colocated with git)**. Use change IDs; commit only when asked.

## Layout (post-port)
- `lua/mark/state.lua`: shared state (num_groups, patterns, cycle 1-based, last_search, enabled, config, colors).
- `lua/mark/util.lua`: `is_ignorecase` (nil=follow &ignorecase, explicit `\C` wins), `escape_text`, `escape_text_whitespace_indifferent`, `split_alternatives` (splits unescaped `\|`, even-backslash rule), `eq_pos`, `vim_error_text`.
- `lua/mark/palettes.lua`: presets `original` (6), `extended` (17), `maximum` (77; needs truecolor). Entries are nvim_set_hl attrs; numeric-string cterm colors are coerced to int in highlight.define_colors (nvim_set_hl rejects "17" strings).
- `lua/mark/highlight.lua`: `define_colors` (string shorthand = {bg=...}; group N ↔ colors[N]), `reinit` (resize patterns, fix cycle/last_search), per-window match bookkeeping in `vim.w[winid].mw_match`, priority `-10 - N + 1 + (index-1)` (always < 0 so hlsearch wins), refresh via `nvim_tabpage_list_wins` + `nvim_win_call` (no windo/winrestcmd needed).
- `lua/mark/marks.lua`: core ops. `do_mark(group, regexp, cb)` — group 0 = auto choice (free group or cycle), empty regexp + group 0 = disable all, + group N = clear group; toggle-off when pattern exists; alternatives merged/subtracted with `\|`; `set_mark` (Ex-safe: errors instead of querying, `force` bang skips toggle-off), `do_mark_and_set_current` (validates regexp via pcall match), `current_mark` (high→low group scan), `visual_text` via `vim.fn.getregion` (no register clobbering; appends '\n' for linewise), `mark_regex` via `vim.ui.input` (async). Interactive group query via `vim.ui.select` → do_mark takes optional async callback.
- `lua/mark/search.lua`: `search()` port of original s:Search (count, backward, current-mark stickiness, wrap detection, jumplist `m'`, `zv` folds, echo/warn messages via nvim_echo; MoreMsg/WarningMsg). `search_current_mark/any_mark/next/group_mark`; group query path is async.
- `lua/mark/persistence.lua`: JSON at stdpath('data')/mark.json, `{slots = {default = {patterns, enabled}, NAME = ...}}`; `save/auto_save/auto? load/apply/slot_names/complete_slots/activate_filetype`. auto_save always writes 'default' slot; FileType activation sets patterns directly (no auto-save trigger) via `apply()`.
- `lua/mark/init.lua`: `setup()` (idempotent; `vim.g.mark_configured` flag), defaults in `defaults` table, strict-subcommand `:Mark` (set [N]|list|clear [N|all]|toggle|save|load|palette) with `M.complete` exported, full `<Plug>(Mark*)` set + configurable defaults (keymaps table; hasmapto-guarded, re-setup deletes previous defaults), autocmds: WinEnter (lazy apply), TabNewEntered (refresh), ColorScheme (re-define colors from state.colors), FileType+BufEnter (filetype_marks activation, only when args.buf is current).
- `plugin/mark.lua`: loaded guard + `setup()` if not configured.
- `_ignored/smoke.lua`: headless test (`nvim --headless -l _ignored/smoke.lua`), 38 checks; `_ignored/final.lua` checks matches/palette switch.

## Design decisions (user-confirmed)
- matchadd() engine (not decoration provider); cycle on overflow; full original mapping surface; global persistence + filetype→marks activation (NO per-file marks; earlier "clear mapping per file" idea dropped); strict `:Mark` subcommands.
- Number of mark groups == #colors (or palette length); group N uses colors[N].
- `:Mark set!` = keep already-marked pattern (no toggle-off), make it current.

## Gotchas
- nvim_set_hl needs integer cterm colors (coerce digit strings).
- Neovim `&ignorecase` defaults off; tests must set it explicitly.
- vim.g reads 1 as true — don't compare `== 1`.
- Clearing a group while marks are disabled re-enables display (faithful to original).
- During ACTIVE visual mode, `getpos("'<")`/`getpos("'>")` are (0,0,0,0) and `visualmode()` is '' — they're only set on leaving visual. Use `getpos('v')` (visual start) + `getpos('.')` with type from `mode()` ('v'/'V'/"\22"); marks.lua `visual_text()` does this with a '< '/'> fallback for post-visual calls.
- Lua-callback mappings do NOT leave visual mode (original Ex mappings did via `:`) — x-mode Plugs call `exit_visual_mode()` which leaves visual SYNCHRONOUSLY (`vim.cmd([[execute "normal! \<Esc>"]])`, mode-guarded). A merely deferred `<Esc>` (feedkeys 'in') races a freshly opened `vim.ui.input` and cancels it instantly — user-visible as "prompt vanishes" for `<Leader>r` in visual mode. The sync Esc also RESETS v:count, so capture `vim.v.count` before `exit_visual_mode()` in mapping callbacks.
- The REAL `vim.ui.input` cannot be driven from headless `-l` scripts: opening it inside `feedkeys(keys,'Mtx')` processing terminates the script (exit 0, output truncated). Test prompt handoff with a recording wrapper that asserts `vim.fn.mode()` at prompt-call time instead.
- Lua callback mappings run ONCE with `vim.v.count` holding a typed count (verified).
- In `feedkeys()`, a CTRL-V byte quotes the next char — to type a real `<C-v>` (blockwise visual tests) use a doubled `^V`.
- Headless `-l` scripts: `feedkeys(keys, 'Mtx')` executes mappings synchronously; `nvim_input`/`'Mt'` + `vim.wait` do NOT process input. Tests in `_ignored/`.
- Always smoke-test the COMMAND layer, not just the Lua API: `util.info()` was called by the `:Mark save/load` handlers but never defined — `persistence.save()` was tested directly so it slipped through. Command save/load tests are in smoke.lua §10b/§10c.
- `:Mark save NAME` with no marks removes the named slot (original `:MarkSave` semantics); auto_save always writes the 'default' slot even when empty.
