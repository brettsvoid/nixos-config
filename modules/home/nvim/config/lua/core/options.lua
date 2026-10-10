-- The terminal uses a Nerd Font (read by which-key.lua)
vim.g.have_nerd_font = true

-- Lua module cache. Redundant: lazy.setup() (config/lazy.lua) already enables it.
vim.loader.enable()

-- [[ Setting options ]]
-- relative line numbers, absolute on the cursor line
vim.opt.number = true
vim.opt.relativenumber = true

-- don't show the mode, since it's already in the status line
vim.opt.showmode = false

-- tabs & indentation
vim.opt.breakindent = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- line wrapping
vim.opt.wrap = false

-- backup and undo handling
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

-- search settings
vim.opt.ignorecase = true
vim.opt.smartcase = true -- case-sensitive if the pattern has capitals

-- scroll settings
vim.opt.scrolloff = 8
vim.opt.isfname:append("@-@")

vim.opt.cursorline = true

-- ms idle before CursorHold fires (LSP document highlight)
vim.opt.updatetime = 250

-- shorter wait for a mapped sequence to complete
vim.opt.timeoutlen = 300

-- preview substitutions live, as you type
vim.opt.inccommand = "split"

-- Appearance --
vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true
vim.opt.signcolumn = "yes" -- show sign column so that text doesn't shift

-- folding
-- Safe globally: vim.treesitter.foldexpr() returns "0" (no folds) for buffers
-- without a parser. nvim-treesitter.lua starts the parser per buffer.
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevelstart = 99 -- start with all folds open
vim.opt.foldtext = "" -- keep syntax highlighting on the folded line

-- backspace
vim.opt.backspace = "indent,eol,start" -- backspace over indent, line breaks and insert start

-- split windows
vim.opt.splitright = true

-- no ins-completion messages (completeopt is unset: blink.cmp draws its own menu)
vim.opt.shortmess = vim.opt.shortmess + { c = true }

-- localoptions keeps filetype and highlighting after a session restore (per auto-session)
vim.opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

vim.opt.winborder = "rounded"
