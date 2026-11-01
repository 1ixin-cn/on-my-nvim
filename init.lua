-- ============================================================
-- Neovim 主配置入口
-- 类 IDE 配置：多语言实时调试 / 实时编译 / 会话持久化 / 全面汉化
-- ------------------------------------------------------------
-- 目录结构：
--   lua/options/basic.lua   基础选项
--   lua/core/autosave.lua    自动保存（防丢文件）
--   lua/core/i18n.lua        汉化核心
--   lua/core/lsp.lua         LSP 服务器定义
--   lua/core/dap.lua         调试配置
--   lua/core/tasks.lua       任务系统（阶段编译/实时编译）
--   lua/core/session.lua     会话持久化
--   lua/keymaps/init.lua     快捷键
--   lua/plugins/*.lua        插件配置
-- ============================================================

-- 1) 基础选项（必须最先）
require('options.basic')

-- 2) 汉化（在任何插件输出提示之前生效）
require('core.i18n').setup()

-- 3) lazy.nvim 引导
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--depth', '1',
    'https://github.com/folke/lazy.nvim.git',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 4) 加载插件
require('lazy').setup({
  spec = {
    { import = 'plugins.mason' },
    { import = 'plugins.lsp' },
    { import = 'plugins.cmp' },
    { import = 'plugins.ui' },
    { import = 'plugins.editor' },
    { import = 'plugins.dap' },
    { import = 'plugins.session' },
    { import = 'plugins.langs' },
  },
  -- 插件安装/更新时自动重新加载配置
  install = { colorscheme = { 'tokyonight', 'habamax' } },
  checker = { enabled = true, notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip',
        'tarPlugin',
        'tohtml',
        'tutor',
        'zipPlugin',
        'netrwPlugin',   -- 用 Telescope 替代
      },
    },
  },
  -- 缺失插件不报错（网络受限时仍可启动）
  missing = false,
  change_detection = {
    notify = false,
  },
  rocks = {
    enabled = false,
  },
}, {
  -- 首次启动时自动同步插件
  performance = { rtp = { reset = false } },
})

-- 5) 快捷键
require('keymaps').setup()

-- 6) 自动保存（防丢文件）
require('core.autosave')

-- 7) 会话持久化
require('core.session').setup()

-- 8) 任务系统（阶段编译 / 实时编译）
require('core.tasks').setup()

-- 8.5) 调试配置
-- 说明：nvim-dap 是懒加载插件，plugins/dap.lua 里的 config 只有在插件
-- 真正被加载时才执行。若启动后不主动初始化，codelldb / Go / Python 的
-- 调试配置在首次按 F5 前都不存在（表现为「没有可用的配置」）。
-- 这里在 lazy.setup 之后主动 require 一次，触发插件加载并完成注册；
-- core.dap.setup 内部有幂等保护，重复调用无副作用。
pcall(function()
  require('core.dap').setup()
end)

-- 9) 全局变量与状态
vim.g.realtime_compile = true   -- 实时编译默认开启

-- 10) 状态栏与语言状态
local augroup = vim.api.nvim_create_augroup('StatusLine', { clear = true })
vim.api.nvim_create_autocmd('BufEnter', {
  group = augroup,
  callback = function()
    -- 切换文件时刷新任务表
    pcall(function()
      require('core.tasks').refresh_tasks()
    end)
  end,
})

-- 11) 启动完成后的收尾
vim.api.nvim_create_autocmd('VimEnter', {
  group = augroup,
  callback = function()
    -- 兜底初始化 DAP：nvim-dap 是懒加载插件，其 config 只有在插件真正
    -- 加载时才会执行；若用户从未触发过 DAP 命令，codelldb / Go 等
    -- 调试配置就不会注册。这里主动初始化一次（core.dap.setup 内部幂等）。
    pcall(function()
      require('core.dap').setup()
    end)

    -- 首次启动提示
    if vim.fn.empty(vim.fn.globpath(vim.fn.stdpath('data') .. '/lazy', 'lazy.nvim', false, true)) > 0 then
      vim.schedule(function()
        vim.notify('Neovim 类 IDE 环境已就绪 | 按 <leader> 查看全部快捷键', vim.log.levels.INFO)
      end)
    end
  end,
})

-- 12) 中文帮助入口
vim.api.nvim_create_user_command('Help', function()
  vim.cmd('help')
end, { desc = '打开中文帮助文档' })
