-- Back-compat shim. The nvim-tree Decorator moved into the tree-adapter layer
-- (lua/commit-lens/tree/nvim-tree.lua) when commit-lens grew support for other
-- file managers. Older host configs still do
--   require("commit-lens.tree-decorator")
-- in their `renderer.decorators` list and expect the Decorator CLASS back, so
-- return it. New configs should require "commit-lens.tree.nvim-tree".decorator.
return require("commit-lens.tree.nvim-tree").decorator
