-- Add github copilot autocompletion
return {
  -- https://github.com/zbirenbaum/copilot.lua
  {
    'zbirenbaum/copilot.lua',
    enabled = false,
    cmd = 'Copilot',
    event = 'InsertEnter',
    opts = {
      suggestion = { enabled = false },
      panel = { enabled = false },
    },
  },
  -- https://github.com/zbirenbaum/copilot-cmp
  -- This adds copilot suggestions to the autocompletion menu
  -- {
  --   'zbirenbaum/copilot-cmp',
  --   config = true,
  -- },
}
