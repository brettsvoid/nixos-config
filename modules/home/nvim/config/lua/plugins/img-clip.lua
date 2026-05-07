return {
	"HakonHarnes/img-clip.nvim",
	event = "VeryLazy",
	opts = {
		default = {
			embed_image_as_base64 = false,
			prompt_for_file_name = true,
			drag_and_drop = {
				insert_mode = true,
			},
			use_absolute_path = false,
		},
		filetypes = {
			markdown = {
				url_encode_path = true,
				template = "![$CURSOR]($FILE_PATH)",
				dir_path = "assets",
			},
			norg = {
				template = ".image $FILE_PATH",
				dir_path = "assets",
			},
		},
	},
	keys = {
		{
			"<leader>p",
			"<cmd>PasteImage<cr>",
			desc = "Paste image from clipboard",
		},
	},
}
