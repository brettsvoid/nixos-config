-- https://github.com/nvim-telescope/telescope.nvim
return {
	"nvim-telescope/telescope.nvim",
	event = "VimEnter",
	tag = "0.1.8",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ -- If encountering errors, see telescope-fzf-native README for installation instructions
			"nvim-telescope/telescope-fzf-native.nvim",

			-- `build` is used to run some command when the plugin is installed/updated.
			-- This is only run then, not every time Neovim starts up.
			build = "make",

			-- `cond` is a condition used to determine whether this plugin should be
			-- installed and loaded.
			cond = function()
				return vim.fn.executable("make") == 1
			end,
		},
		{ "nvim-telescope/telescope-ui-select.nvim" },
		--{ 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
		{ "echasnovski/mini.icons" },
		"nvim-treesitter/nvim-treesitter",
	},
	-- [[ Configure Telescope ]]
	-- See `:help telescope` and `:help telescope.setup()`
	opts = function()
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")
		local builtin = require("telescope.builtin")
		return {
			defaults = {
				mappings = {
					n = {
						["d"] = actions.delete_buffer,
						["<esc>"] = actions.close,
					},
					i = {
						["<C-p>"] = actions.cycle_history_prev,
						["<C-n>"] = actions.cycle_history_next,
						["<C-d>"] = function(prompt_bufnr)
							local current_picker = action_state.get_current_picker(prompt_bufnr)

							-- Retrieve the current search query from the prompt buffer.
							local lines = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, 1, false)
							local prompt_text = lines[1] or ""

							local prompt_prefix = current_picker.prompt_prefix
							-- Strip the prompt prefix to get the actual search query.
							if #prompt_text > #prompt_prefix then
								prompt_text = prompt_text:sub(#prompt_prefix + 1)
							else
								prompt_text = ""
							end

							-- Close the current Telescope picker.
							actions.close(prompt_bufnr)

							-- Asynchronously prompt the user for a directory.
							vim.ui.input({
								prompt = "Search in directory: ",
								default = vim.fn.getcwd(),
								completion = "dir", -- Enables directory completion.
							}, function(input)
								-- Expand the input to handle relative paths.
								local expanded_dir = vim.fn.expand(input)

								if input and #input > 0 then
									-- Validate that the input is a directory.
									if vim.fn.isdirectory(expanded_dir) == 1 then
										-- Relaunch live_grep with the specified directory and previous search query.
										builtin.live_grep({
											search_dirs = { expanded_dir },
											default_text = prompt_text, -- Prepopulate with the previous search query.
										})
									else
										-- Notify the user about the invalid directory.
										vim.notify("Invalid directory: " .. expanded_dir, vim.log.levels.ERROR)
									end
								else
									-- Notify the user that no directory was selected.
									vim.notify("No directory selected. Staying in current picker.", vim.log.levels.INFO)
								end

								builtin.live_grep({
									default_text = prompt_text, -- Prepopulate with the previous search query.
								})
							end)
						end,
					},
				},
			},

			extensions = {
				fzf = {},
				["ui-select"] = {
					require("telescope.themes").get_dropdown(),
				},
			},
		}
	end,
	config = function(_, opts)
		-- Telescope is a fuzzy finder that comes with a lot of different things that
		-- it can fuzzy find! It's more than just a "file finder", it can search
		-- many different aspects of Neovim, your workspace, LSP, and more!
		--
		-- The easiest way to use Telescope, is to start by doing something like:
		--  :Telescope help_tags
		--
		-- After running this command, a window will open up and you're able to
		-- type in the prompt window. You'll see a list of `help_tags` options and
		-- a corresponding preview of the help.
		--
		-- Two important keymaps to use while in Telescope are:
		--  - Insert mode: <c-/>
		--  - Normal mode: ?
		--
		-- This opens a window that shows you all of the keymaps for the current
		-- Telescope picker. This is really useful to discover what Telescope can
		-- do as well as how to actually do it!
		local telescope = require("telescope")

		telescope.setup(opts)

		-- Enable Telescope extensions if they are installed
		pcall(telescope.load_extension, "fzf")
		pcall(telescope.load_extension, "ui-select")

		-- See `:help telescope.builtin`
		local builtin = require("telescope.builtin")
		-- vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
		-- vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
		-- vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
		-- vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
		-- vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
		-- vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
		-- vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
		-- vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
		-- vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
		vim.keymap.set(
			"n",
			"<leader><leader>",
			"<cmd>Telescope buffers sort_mru=true sort_lastused=true initial_mode=normal theme=ivy<cr>",
			{ desc = "[ ] Find existing buffers" }
		)

		-- Slightly advanced example of overriding default behavior and theme
		vim.keymap.set("n", "<leader>/", function()
			-- You can pass additional configuration to Telescope to change the theme, layout, etc.
			builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
				winblend = 10,
				previewer = false,
			}))
		end, { desc = "[/] Fuzzily search in current buffer" })

		-- It's also possible to pass additional configuration options.
		-- See `:help telescope.builtin.live_grep()` for information about particular keys
		vim.keymap.set("n", "<leader>s/", function()
			builtin.live_grep({
				grep_open_files = true,
				prompt_title = "Live Grep in Open Files",
			})
		end, { desc = "[S]earch [/] in Open Files" })

		-- Shortcut for searching your Neovim configuration files
		vim.keymap.set("n", "<leader>sn", function()
			builtin.find_files({ cwd = vim.fn.stdpath("config") })
		end, { desc = "[S]earch [N]eovim files" })
	end,
}
