-- Built-in color palettes for mark.nvim.
--
-- Each entry defines one mark highlight group via nvim_set_hl() attributes;
-- a plain string entry is shorthand for { bg = ... }. The mark group with
-- index N uses the color at index N.

local M = {}

M.original = {
  { ctermbg = 'Cyan',    ctermfg = 'Black', bg = '#8CCBEA', fg = 'Black' },
  { ctermbg = 'Green',   ctermfg = 'Black', bg = '#A4E57E', fg = 'Black' },
  { ctermbg = 'Yellow',  ctermfg = 'Black', bg = '#FFDB72', fg = 'Black' },
  { ctermbg = 'Red',     ctermfg = 'Black', bg = '#FF7272', fg = 'Black' },
  { ctermbg = 'Magenta', ctermfg = 'Black', bg = '#FFB3FF', fg = 'Black' },
  { ctermbg = 'Blue',    ctermfg = 'Black', bg = '#9999FF', fg = 'Black' },
}

M.extended = {
  { ctermbg = 'Blue',        ctermfg = 'Black', bg = '#A1B7FF', fg = '#001E80' },
  { ctermbg = 'Magenta',     ctermfg = 'Black', bg = '#FFA1C6', fg = '#80005D' },
  { ctermbg = 'Green',       ctermfg = 'Black', bg = '#ACFFA1', fg = '#0F8000' },
  { ctermbg = 'Yellow',      ctermfg = 'Black', bg = '#FFE8A1', fg = '#806000' },
  { ctermbg = 'DarkCyan',    ctermfg = 'Black', bg = '#D2A1FF', fg = '#420080' },
  { ctermbg = 'Cyan',        ctermfg = 'Black', bg = '#A1FEFF', fg = '#007F80' },
  { ctermbg = 'DarkBlue',    ctermfg = 'Black', bg = '#A1DBFF', fg = '#004E80' },
  { ctermbg = 'DarkMagenta', ctermfg = 'Black', bg = '#A29CCF', fg = '#120080' },
  { ctermbg = 'DarkRed',     ctermfg = 'Black', bg = '#F5A1FF', fg = '#720080' },
  { ctermbg = 'Brown',       ctermfg = 'Black', bg = '#FFC4A1', fg = '#803000' },
  { ctermbg = 'DarkGreen',   ctermfg = 'Black', bg = '#D0FFA1', fg = '#3F8000' },
  { ctermbg = 'Red',         ctermfg = 'Black', bg = '#F3FFA1', fg = '#6F8000' },
  { ctermbg = 'White',       ctermfg = 'Gray',  bg = '#E3E3D2', fg = '#999999' },
  { ctermbg = 'LightGray',   ctermfg = 'White', bg = '#D3D3C3', fg = '#666666' },
  { ctermbg = 'Gray',        ctermfg = 'Black', bg = '#A3A396', fg = '#222222' },
  { ctermbg = 'Black',       ctermfg = 'White', bg = '#53534C', fg = '#DDDDDD' },
  { ctermbg = 'Black',       ctermfg = 'Gray',  bg = '#131311', fg = '#AAAAAA' },
}

-- The "maximum" palette needs a truecolor terminal for its lower tiers.
M.maximum = vim.list_extend(vim.list_extend(vim.list_extend(
  vim.deepcopy(M.original),
  {
    { ctermfg = 'White', ctermbg = '17',  fg = 'White', bg = '#00005f' },
    { ctermfg = 'White', ctermbg = '22',  fg = 'White', bg = '#005f00' },
    { ctermfg = 'White', ctermbg = '23',  fg = 'White', bg = '#005f5f' },
    { ctermfg = 'White', ctermbg = '27',  fg = 'White', bg = '#005fff' },
    { ctermfg = 'White', ctermbg = '29',  fg = 'White', bg = '#00875f' },
    { ctermfg = 'White', ctermbg = '34',  fg = 'White', bg = '#00af00' },
    { ctermfg = 'Black', ctermbg = '37',  fg = 'Black', bg = '#00afaf' },
    { ctermfg = 'Black', ctermbg = '43',  fg = 'Black', bg = '#00d7af' },
    { ctermfg = 'Black', ctermbg = '47',  fg = 'Black', bg = '#00ff5f' },
    { ctermfg = 'White', ctermbg = '52',  fg = 'White', bg = '#5f0000' },
    { ctermfg = 'White', ctermbg = '53',  fg = 'White', bg = '#5f005f' },
    { ctermfg = 'White', ctermbg = '58',  fg = 'White', bg = '#5f5f00' },
    { ctermfg = 'White', ctermbg = '60',  fg = 'White', bg = '#5f5f87' },
    { ctermfg = 'White', ctermbg = '64',  fg = 'White', bg = '#5f8700' },
    { ctermfg = 'White', ctermbg = '65',  fg = 'White', bg = '#5f875f' },
    { ctermfg = 'Black', ctermbg = '66',  fg = 'Black', bg = '#5f8787' },
    { ctermfg = 'Black', ctermbg = '72',  fg = 'Black', bg = '#5faf87' },
    { ctermfg = 'Black', ctermbg = '74',  fg = 'Black', bg = '#5fafd7' },
    { ctermfg = 'Black', ctermbg = '78',  fg = 'Black', bg = '#5fd787' },
    { ctermfg = 'Black', ctermbg = '79',  fg = 'Black', bg = '#5fd7af' },
    { ctermfg = 'Black', ctermbg = '85',  fg = 'Black', bg = '#5fffaf' },
  }
), {
  { ctermfg = 'White', ctermbg = '90',  fg = 'White', bg = '#870087' },
  { ctermfg = 'White', ctermbg = '95',  fg = 'White', bg = '#875f5f' },
  { ctermfg = 'White', ctermbg = '96',  fg = 'White', bg = '#875f87' },
  { ctermfg = 'Black', ctermbg = '101', fg = 'Black', bg = '#87875f' },
  { ctermfg = 'Black', ctermbg = '107', fg = 'Black', bg = '#87af5f' },
  { ctermfg = 'Black', ctermbg = '114', fg = 'Black', bg = '#87d787' },
  { ctermfg = 'Black', ctermbg = '117', fg = 'Black', bg = '#87d7ff' },
  { ctermfg = 'Black', ctermbg = '118', fg = 'Black', bg = '#87ff00' },
  { ctermfg = 'Black', ctermbg = '122', fg = 'Black', bg = '#87ffd7' },
  { ctermfg = 'White', ctermbg = '130', fg = 'White', bg = '#af5f00' },
  { ctermfg = 'White', ctermbg = '131', fg = 'White', bg = '#af5f5f' },
  { ctermfg = 'Black', ctermbg = '133', fg = 'Black', bg = '#af5faf' },
  { ctermfg = 'Black', ctermbg = '138', fg = 'Black', bg = '#af8787' },
  { ctermfg = 'Black', ctermbg = '142', fg = 'Black', bg = '#afaf00' },
  { ctermfg = 'Black', ctermbg = '152', fg = 'Black', bg = '#afd7d7' },
  { ctermfg = 'White', ctermbg = '160', fg = 'White', bg = '#d70000' },
  { ctermfg = 'Black', ctermbg = '166', fg = 'Black', bg = '#d75f00' },
  { ctermfg = 'Black', ctermbg = '169', fg = 'Black', bg = '#d75faf' },
  { ctermfg = 'Black', ctermbg = '174', fg = 'Black', bg = '#d78787' },
  { ctermfg = 'Black', ctermbg = '175', fg = 'Black', bg = '#d787af' },
  { ctermfg = 'Black', ctermbg = '186', fg = 'Black', bg = '#d7d787' },
  { ctermfg = 'Black', ctermbg = '190', fg = 'Black', bg = '#d7ff00' },
  { ctermfg = 'White', ctermbg = '198', fg = 'White', bg = '#ff0087' },
  { ctermfg = 'Black', ctermbg = '202', fg = 'Black', bg = '#ff5f00' },
  { ctermfg = 'Black', ctermbg = '204', fg = 'Black', bg = '#ff5f87' },
  { ctermfg = 'Black', ctermbg = '209', fg = 'Black', bg = '#ff875f' },
  { ctermfg = 'Black', ctermbg = '212', fg = 'Black', bg = '#ff87d7' },
  { ctermfg = 'Black', ctermbg = '215', fg = 'Black', bg = '#ffaf5f' },
  { ctermfg = 'Black', ctermbg = '220', fg = 'Black', bg = '#ffd700' },
  { ctermfg = 'Black', ctermbg = '224', fg = 'Black', bg = '#ffd7d7' },
  { ctermfg = 'Black', ctermbg = '228', fg = 'Black', bg = '#ffff87' },
}), {
  { fg = 'Black', bg = '#b3dcff' },
  { fg = 'Black', bg = '#99cbd6' },
  { fg = 'Black', bg = '#7afff0' },
  { fg = 'Black', bg = '#a6ffd2' },
  { fg = 'Black', bg = '#a2de9e' },
  { fg = 'Black', bg = '#bcff80' },
  { fg = 'Black', bg = '#e7ff8c' },
  { fg = 'Black', bg = '#f2e19d' },
  { fg = 'Black', bg = '#ffcc73' },
  { fg = 'Black', bg = '#f7af83' },
  { fg = 'Black', bg = '#fcb9b1' },
  { fg = 'Black', bg = '#ff8092' },
  { fg = 'Black', bg = '#ff73bb' },
  { fg = 'Black', bg = '#fc97ef' },
  { fg = 'Black', bg = '#c8a3d9' },
  { fg = 'Black', bg = '#ac98eb' },
  { fg = 'Black', bg = '#6a6feb' },
  { fg = 'Black', bg = '#8caeff' },
  { fg = 'Black', bg = '#70b9fa' },
})

function M.names()
  local names = {}
  for name in pairs(M) do
    if type(M[name]) == 'table' then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

function M.complete_names(arglead)
  return vim.tbl_filter(function(name)
    return name:sub(1, #arglead) == arglead
  end, M.names())
end

return M
