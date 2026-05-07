-- https://github.com/MeanderingProgrammer/render-markdown.nvim
return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    --'echasnovski/mini.nvim'  -- if you use the mini.nvim suite
    --'echasnovski/mini.icons'  -- if you use standalone mini plugins
    'nvim-tree/nvim-web-devicons', -- if you prefer nvim-web-devicons
    '3rd/image.nvim', -- image rendering support
  },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    file_types = { 'markdown' },
    latex = { enabled = false },
    render_modes = { 'n', 'c' },
    integrations = {
      image = {
        enabled = true,
      },
    },
  },
}
