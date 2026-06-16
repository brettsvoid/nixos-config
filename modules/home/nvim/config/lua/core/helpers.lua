function SearchQuickfixFiles()
  local qflist = vim.fn.getqflist()
  local files = {}

  for _, item in ipairs(qflist) do
    local filepath = vim.fn.bufname(item.bufnr)
    if filepath ~= '' then
      local abs_path = vim.fn.fnamemodify(filepath, ':p')
      if abs_path ~= '' then
        table.insert(files, abs_path)
      end
    end
  end

  -- files = vim.fn.uniq(files)
  -- require('telescope.builtin').live_grep { search_dirs = files }

  -- Remove duplicates manually to avoid type issues with vim.fn.uniq
  local unique_files = {}
  local hash = {}

  for _, file in ipairs(files) do
    if not hash[file] then
      unique_files[#unique_files + 1] = file
      hash[file] = true
    end
  end

  if #unique_files > 0 then
    require('telescope.builtin').live_grep { search_dirs = unique_files }
  else
    print 'No valid files found in the quickfix list'
  end
end

-- Create a Vim command to run the Lua function
vim.api.nvim_create_user_command('SearchQuickfixFiles', function()
  SearchQuickfixFiles()
end, {})

-- Highlight when yanking text
-- Try it with `yap` in normal mode
-- See `:help vim.hightlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yangking text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- One way to show unsaved buffers
function OpenUnsavedBuffers()
  local buffers = vim.api.nvim_list_bufs()
  local unsaved_buffers = {}

  local original_bufnr = vim.api.nvim_get_current_buf()

  for _, bufnr in ipairs(buffers) do
    --local is_saved = vim.api.nvim_buf_get_option(bufnr, 'modified')
    local is_saved = vim.api.nvim_get_option_value('modified', { buf = bufnr })

    if is_saved and bufnr ~= original_bufnr then
      local bufname = vim.api.nvim_buf_get_name(bufnr)

      table.insert(unsaved_buffers, bufnr)

      vim.cmd('tabnew ' .. bufname)
    end
  end

  if #unsaved_buffers > 0 then
    vim.notify('Opened ' .. #unsaved_buffers .. ' unsaved buffers')
  end
end

vim.api.nvim_create_user_command('OpenUnsavedBuffers', OpenUnsavedBuffers, {})
