-- set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- enable the experimental loader to speed up startup times
--vim.loader.enable()

-- [[ Setting options ]]
-- line numbers
-- shows absolute line number on cursor line (when relative number is on)
vim.opt.number = true
-- show relative line numbers
vim.opt.relativenumber = true

-- don't show the mode, since it's already in the status line
vim.opt.showmode = true

-- tabs & indentation
vim.opt.breakindent = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- line wrapping
vim.opt.wrap = false -- disable line wrapping

-- backup and undo handling
vim.opt.swapfile = false
vim.opt.backup = false -- set to false to let undo tree handle undos
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

-- search settings
vim.opt.ignorecase = true -- ignore case when searching
vim.opt.smartcase = true -- if you include mixed case in your search, assumes you want case-sensitive

-- scroll settings
vim.opt.scrolloff = 8
vim.opt.isfname:append("@-@")

-- cursor line
vim.opt.cursorline = true -- highlight the current cursor line

-- updatetime
-- the length of time that vim waits before updating the swapfile
vim.opt.updatetime = 250

-- decrease mapped sequence wait time
-- displays which-key popup sooner
vim.opt.timeoutlen = 300

-- preview substitutions live, as you type
vim.opt.inccommand = "split"

-- Appearance --
vim.opt.hlsearch = false
vim.opt.incsearch = true

-- turn on termguicolors for 24-bit color
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes" -- show sign column so that text doesn't shift

-- backspace
vim.opt.backspace = "indent,eol,start" -- allow backspace on indent, end of line or insert mode start position

-- split windows
vim.opt.splitright = true -- split vertical window to the right
--opt.splitbelow = true -- split horizontal window to the bottom

-- colorcolumn
--vim.opt.colorcolumn = '80'

-- Set completeopt to have a better completion experience --
-- :help completeopt
-- menuone: popup even when there's only one match
-- noinsert: Do not insert text until a selection is made
-- noselect: Do not select, force to select one from the menu
-- shortness: avoid showing extra messages when using completion
-- updatetime: set updatetime for CursorHold
vim.opt.completeopt = { "menuone", "noselect", "noinsert" }
vim.opt.shortmess = vim.opt.shortmess + { c = true }

-- When pressing `p`, clipboard will be pasted
--vim.opt.clipboard = 'unnamedplus'

-- Make sure sessionoptions contains localoptions so that filetype and highlighting work correctly after a session is restores
-- Suggested by rmagatti/auto-session
vim.opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

vim.opt.winborder = "rounded"
