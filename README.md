# mark.nvim

Highlight several words in different colors simultaneously — a Lua port of the
mark.vim plugin (originally vimscript #1238 by Yuheng Xie, continued by Ingo
Karkat) for **Neovim 0.12+**.

## Features

- Multiple patterns highlighted in parallel, one color per mark group, in all
  windows of the tabpage. Implemented with `matchadd()`, so there are no
  clashes with syntax highlighting.
- Jumps behave like the built-in `*` / `#` / `n` / `N`: counts, wrap messages,
  jumplist entries, fold opening.
- The number of mark groups is defined by an explicit list of colors; mark
  group `N` uses `colors[N]`.
- Marks are persisted globally in a JSON file (`stdpath('data')/mark.json`)
  with named slots, and mark sets can be activated automatically per filetype.

## Setup

```lua
require('mark').setup({
  colors = {
    '#8CCBEA',                          -- background shorthand
    { bg = '#A4E57E', fg = 'black' },   -- full nvim_set_hl() attributes
  },
  filetype_marks = {
    lua = { 'function', 'local \\k\\+' },
    python = 'PY',                      -- a stored slot name
  },
})
```

Without `setup()`, the plugin starts with the built-in 'original' palette
(9 colors) and the original default mappings.

## Commands

| Command                  | Action                                                    |
| ------------------------ | --------------------------------------------------------- |
| `:[N]Mark set[!] {pat}`  | toggle / add-subtract pattern (group N with `[N]`)        |
| `:Mark list`             | list all groups and patterns                              |
| `:Mark edit [N]`         | edit current / group N pattern in a prompt                |
| `:Mark clear [N\|all]`   | clear current mark / group N / everything                 |
| `:Mark toggle`           | enable/disable display (patterns kept)                    |
| `:Mark save [slot]`      | store current set in a slot                               |
| `:Mark load [slot]`      | load a slot (`load!` merges into the current set)             |
| `:Mark palette {name}`   | switch between 'original' / 'extended' / 'maximum'        |

## Default mappings

| Keys        | Action                                          |
| ----------- | ----------------------------------------------- |
| `<leader>m` | mark word under cursor / visual selection       |
| `<leader>r` | mark by regexp input                            |
| `<leader>n` | clear mark under cursor                         |
| `*` / `#`   | search mark under cursor (falls back to builtin)|
| `<leader>*` / `<leader>#` | search current mark              |
| `<leader>/` / `<leader>?` | search any mark                  |
| `<k1>`..<`<k9>` | jump to mark group N                       |

All mappings (and more variants, e.g. whitespace-indifferent selection
marking) are configurable via `setup().keymaps`; see `:h mark.nvim`.

## Credits

This port is based on the design and work of the original plugin's authors:

- **Yuheng Xie** — author of the original Mark plugin (vimscript #1238)
- **Ingo Karkat** — maintainer of the continued mark.vim (vimscript #2666), 2008–2014
- Contributors to the Vimscript versions: Luc Hermitte, Andy Wokula, fanhe,
  Philipp Marek, rockybalboa4 ("maximum" palette), Xiaopan Zhang,
  Vladimir Marek, Zhou YiChao
