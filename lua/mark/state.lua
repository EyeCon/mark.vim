-- Shared state for mark.nvim.
--
-- num_groups   number of mark highlight groups (= number of colors)
-- patterns     one pattern per group ('' when the group is unused)
-- cycle        next group index (1-based) to use when all groups are in use
-- last_search  index (1-based) of the last searched mark group, -1 = none
-- enabled      whether marks are displayed (patterns are kept when disabled)
-- config       merged configuration from setup()
-- colors       resolved color definitions (re-applied on ColorScheme)

return {
  num_groups = 0,
  patterns = {},
  cycle = 1,
  last_search = -1,
  enabled = true,
  config = {},
  colors = {},
}
