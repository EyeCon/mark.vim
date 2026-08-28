-- mark.nvim entry point.

if vim.g.loaded_mark_nvim then
  return
end
vim.g.loaded_mark_nvim = true

if not vim.g.mark_configured then
  require('mark').setup()
end
