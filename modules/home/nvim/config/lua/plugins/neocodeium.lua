-- https://github.com/monkoose/neocodeium
return {
  'monkoose/neocodeium',
  event = 'VeryLazy',
  config = function()
    local neocodeium = require 'neocodeium'
    neocodeium.setup {
      manual = true, -- recommended to not conflict with nvim-cmp
    }

    -- create an autocommand which closes cmp when ai completions are displayed
    vim.api.nvim_create_autocmd('User', {
      pattern = 'NeoCodeiumCompletionDisplayed',
      callback = function()
        -- Disable default completion
        --require('cmp').abort()
      end,
    })

    -- make sure to have a mapping to accept a completion
    vim.keymap.set('i', '<M-f>', function()
      neocodeium.accept()
    end)
    vim.keymap.set('i', '<M-w>', function()
      neocodeium.accept_word()
    end)
    vim.keymap.set('i', '<M-a>', function()
      neocodeium.accept_line()
    end)
    -- set up some sort of keymap to cycle and complete to trigger completion
    vim.keymap.set('i', '<M-e>', function()
      neocodeium.cycle_or_complete()
    end)
    vim.keymap.set('i', '<M-r>', function()
      neocodeium.cycle_or_complete(-1)
    end)
    vim.keymap.set('i', '<M-c>', function()
      neocodeium.clear()
    end)
  end,
}
