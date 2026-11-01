-- ============================================================
-- 基础选项设置
-- ============================================================

-- 确保 ~/.local/bin 在 PATH 中，供 Neovim 找到 fd / codelldb 等二进制
local user_bin = vim.fn.expand('~/.local/bin')
if vim.fn.isdirectory(user_bin) == 1 and string.find(vim.env.PATH, user_bin, 1, true) == nil then
  vim.env.PATH = user_bin .. ':' .. vim.env.PATH
end
-- Rust 工具链（rustup 默认装在 ~/.cargo/bin）
local cargo_bin = vim.fn.expand('~/.cargo/bin')
if vim.fn.isdirectory(cargo_bin) == 1 and string.find(vim.env.PATH, cargo_bin, 1, true) == nil then
  vim.env.PATH = cargo_bin .. ':' .. vim.env.PATH
end
-- Homebrew 路径
local brew_bin = '/opt/homebrew/bin'
if vim.fn.isdirectory(brew_bin) == 1 and string.find(vim.env.PATH, brew_bin, 1, true) == nil then
  vim.env.PATH = brew_bin .. ':' .. vim.env.PATH
end
-- codelldb 调试适配器（C/C++/Rust 调试）
local codelldb_bin = vim.fn.expand('~/.local/share/codelldb/vadimcn.vscode-lldb/bin')
if vim.fn.isdirectory(codelldb_bin) == 1 and string.find(vim.env.PATH, codelldb_bin, 1, true) == nil then
  vim.env.PATH = codelldb_bin .. ':' .. vim.env.PATH
end
-- mason 安装的 LSP / 调试器 / 格式化器
local mason_bin = vim.fn.stdpath('data') .. '/mason/bin'
if vim.fn.isdirectory(mason_bin) == 1 and string.find(vim.env.PATH, mason_bin, 1, true) == nil then
  vim.env.PATH = mason_bin .. ':' .. vim.env.PATH
end

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- 交换文件目录
-- 注意结尾的 `//`：表示 swap 文件名用**完整路径转义**（%Users%...%main.rs.swp）。
-- 只写目录不带 // 时，nvim 只用 basename 命名（main.rs.swp）——
-- 不同目录下的同名文件会抢同一个 swap，互相覆盖，崩溃后也认不出是谁的。
local swapdir = vim.fn.stdpath('data') .. '/swapdir'
if vim.fn.isdirectory(swapdir) == 0 then
  vim.fn.mkdir(swapdir, 'p')
end
vim.opt.directory = swapdir .. '//'

-- 编码（中文支持核心）
vim.opt.encoding = 'utf-8'
vim.opt.fileencoding = 'utf-8'
vim.opt.fileencodings = 'utf-8,gbk,gb2312,cp936,ucs-bom,latin1'
vim.opt.fileformat = 'unix'

-- 显示
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.wrap = true
vim.opt.cursorline = true
vim.opt.signcolumn = 'yes'
vim.opt.showmatch = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.laststatus = 3
vim.opt.termguicolors = true
vim.opt.numberwidth = 4
vim.opt.foldcolumn = '1'
vim.opt.list = false
vim.opt.breakindent = true
vim.opt.undolevels = 10000
vim.opt.swapfile = true          -- 交换文件：崩溃后可恢复未保存内容
vim.opt.backup = true           -- 备份文件
vim.opt.writebackup = true
vim.opt.backupdir = vim.fn.stdpath('data') .. '/backup' -- 备份集中存放，不污染项目
-- directory 已在上方「交换文件目录」处统一设置（带 // 后缀），此处不再重复赋值
vim.opt.updatecount = 200
vim.opt.showtabline = 2
vim.opt.mouse = 'a'
vim.opt.clipboard = 'unnamedplus'
vim.opt.scrollback = 10000
vim.opt.splitbelow = true
vim.opt.splitright = true
-- 0.13 中 shortmess 为 flag 型，字符串赋值；'v' 标志在此版本非法
vim.opt.shortmess = 'aoO' -- 截断冗长提示

-- 搜索
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.inccommand = 'nosplit'

-- 其他
vim.opt.undofile = true
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }
vim.opt.virtualedit = 'onemore'
vim.opt.history = 2000
vim.opt.confirm = true           -- 退出时若有未保存修改会确认，防止误关丢文件
vim.opt.undofile = true
vim.opt.conceallevel = 2
vim.opt.concealcursor = ''

-- 路径：优先当前目录
vim.opt.path = vim.fn.split(vim.o.runtimepath, ',')
vim.opt.path = { '.', vim.fn.expand('~') }
vim.opt.path:append(vim.fn.expand('~/file/for-cloud/ai-file'))

-- 语法高亮
vim.cmd('syntax on')
vim.cmd('filetype plugin indent on')

-- 抑制 lspconfig 弃用警告（nvim 0.13 开发版正常提示，功能不受影响）
vim.deprecate = function() end
