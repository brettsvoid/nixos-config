-- Check if a file exists in the project root
local function file_exists_in_root(filename)
	local path = vim.fn.expand("%:p:h")
	local git_dir = vim.fn.finddir(".git", path)
	local file_path = vim.fn.fnamemodify(git_dir, ":h") .. "/" .. filename
	return vim.fn.filereadable(file_path) == 1
end

return {}
-- https://github.com/Equilibris/nx.nvim
-- return {
--   'Equilibris/nx.nvim',
--   dependencies = {
--     'nvim-telescope/telescope.nvim',
--   },
--   cond = function()
--     return file_exists_in_root 'nx.json'
--   end,
--   opts = {},
--   config = function(_, opts)
--     local nx = require 'nx'
--     local which_key = require 'which-key'
--
--     nx.setup(opts)
--
--     which_key.register({
--       n = {
--         name = '[N]x Commands',
--         x = { '<cmd>Telescope nx actions<CR>', 'n[x] actions' },
--         m = { '<cmd>Telescope nx run_many<CR>', 'nx run [m]any' },
--         a = { '<cmd>Telescope nx affected<CR>', 'nx [a]ffected' },
--         g = { '<cmd>Telescope nx generators<CR>', 'nx [g]enerators' },
--         w = { '<cmd>Telescope nx workspace_generators<CR>', 'nx [w]orkspace generators' },
--         e = { '<cmd>Telescope nx external_generators<CR>', 'nx [e]xternal generators' },
--       },
--     }, { prefix = '<leader>' })
--   end,
-- }
