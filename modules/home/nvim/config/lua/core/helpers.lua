-- Live-grep across only the files currently in the quickfix list.
local function search_quickfix_files()
  local files = {}
  for _, item in ipairs(vim.fn.getqflist()) do
    local filepath = vim.fn.bufname(item.bufnr)
    if filepath ~= '' then
      local abs_path = vim.fn.fnamemodify(filepath, ':p')
      if abs_path ~= '' then
        table.insert(files, abs_path)
      end
    end
  end

  -- Dedupe manually (vim.fn.uniq has type quirks with this list).
  local unique_files = {}
  local seen = {}
  for _, file in ipairs(files) do
    if not seen[file] then
      unique_files[#unique_files + 1] = file
      seen[file] = true
    end
  end

  if #unique_files > 0 then
    require('fzf-lua').live_grep { search_paths = unique_files }
  else
    print 'No valid files found in the quickfix list'
  end
end

vim.api.nvim_create_user_command('SearchQuickfixFiles', search_quickfix_files, {})

-- Highlight yanked text. Try it with `yap`. See :help vim.highlight.on_yank()
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Open each unsaved buffer in its own tab.
local function open_unsaved_buffers()
  local unsaved = {}
  local original_bufnr = vim.api.nvim_get_current_buf()

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local modified = vim.api.nvim_get_option_value('modified', { buf = bufnr })
    if modified and bufnr ~= original_bufnr then
      table.insert(unsaved, bufnr)
      vim.cmd('tabnew ' .. vim.api.nvim_buf_get_name(bufnr))
    end
  end

  if #unsaved > 0 then
    vim.notify('Opened ' .. #unsaved .. ' unsaved buffers')
  end
end

vim.api.nvim_create_user_command('OpenUnsavedBuffers', open_unsaved_buffers, {})
