-- Add indentation guides even on blank lines
-- https://github.com/lukas-reineke/indent-blankline.nvim
return {
  'lukas-reineke/indent-blankline.nvim',
  dependencies = { 'HiPhish/rainbow-delimiters.nvim' },
  main = 'ibl', -- See `:help ibl`
  ---@module "ibl"
  ---@type ibl.config
  opts = {},
  config = function()
    local ibl = require 'ibl'

    local colors = require('catppuccin.palettes').get_palette 'macchiato'
    local blend = require('utils.color_utils').blend

    local highlight_mapping = {
      { IndentRed = blend(colors.red, colors.base, 0.4) },
      { IndentYellow = blend(colors.yellow, colors.base, 0.4) },
      { IndentBlue = blend(colors.blue, colors.base, 0.4) },
      { IndentOrange = blend(colors.peach, colors.base, 0.4) },
      { IndentViolet = blend(colors.mauve, colors.base, 0.4) },
      { IndentCyan = blend(colors.sky, colors.base, 0.4) },
      { IndentGreen = blend(colors.green, colors.base, 0.4) },
    }

    local highlight = {}
    for _, mapping in ipairs(highlight_mapping) do
      for key in pairs(mapping) do
        table.insert(highlight, key)
      end
    end

    local hooks = require 'ibl.hooks'

    -- create the highlight groups in the highlight setup hook, so they are reset
    -- every time the colorscheme changes
    hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
      for _, mapping in ipairs(highlight_mapping) do
        for name, color in pairs(mapping) do
          vim.api.nvim_set_hl(0, name, { fg = color })
        end
      end
    end)

    vim.g.rainbow_delimiters = { highlight = highlight }
    ibl.setup { indent = { highlight = highlight } }

    hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
  end,
}
