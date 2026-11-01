-- ============================================================
-- 全局快捷键映射（中文描述）
-- ============================================================

local M = {}

function M.setup()
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { desc = desc, silent = true })
  end

  -- ----------------------------------------------------------
  -- 文件操作
  -- ----------------------------------------------------------
  map('n', '<leader>w', '<cmd>write<CR>', '保存文件')
  map('n', '<leader>W', '<cmd>write!<CR>', '强制保存文件')
  map('n', '<leader>wa', '<cmd>wall<CR>', '保存所有文件')
  map('n', '<leader>wq', '<cmd>wq<CR>', '保存并退出')
  map('n', '<leader>wqa', '<cmd>wqa<CR>', '保存全部并退出')
  map('n', '<leader>q', '<cmd>quit<CR>', '退出当前窗口')
  map('n', '<leader>qa', '<cmd>quitall<CR>', '退出全部窗口')
  map('n', '<leader>qw', '<cmd>quitall<CR>', '退出全部窗口')

  -- ----------------------------------------------------------
  -- 窗口导航
  -- ----------------------------------------------------------
  map('n', '<C-h>', '<C-w>h', '窗口：左')
  map('n', '<C-j>', '<C-w>j', '窗口：下')
  map('n', '<C-k>', '<C-w>k', '窗口：上')
  map('n', '<C-l>', '<C-w>l', '窗口：右')
  map('n', '<leader>wh', '<C-w>h', '窗口：左')
  map('n', '<leader>wj', '<C-w>j', '窗口：下')
  map('n', '<leader>wk', '<C-w>k', '窗口：上')
  map('n', '<leader>wl', '<C-w>l', '窗口：右')
  map('n', '<leader>ws', '<C-w>s', '窗口：上下分割')
  map('n', '<leader>wv', '<C-w>v', '窗口：左右分割')
  map('n', '<leader>wn', '<C-w>n', '窗口：新开')
  map('n', '<leader>wc', '<C-w>c', '窗口：关闭')
  map('n', '<leader>wo', '<C-w>o', '窗口：仅保留当前')
  map('n', '<leader>w=', '<C-w>=', '窗口：等宽')
  map('n', '<leader>w|', '<C-w>|', '窗口：最大化宽度')
  map('n', '<leader>w-', '<C-w>_', '窗口：最大化高度')

  -- ----------------------------------------------------------
  -- 标签页
  -- ----------------------------------------------------------
  map('n', '<leader>tn', '<cmd>tabnew<CR>', '标签页：新建')
  map('n', '<leader>tc', '<cmd>tabclose<CR>', '标签页：关闭当前')
  map('n', '<leader>tp', '<cmd>tabprevious<CR>', '标签页：上一个')
  map('n', '<leader>tnn', '<cmd>tabnext<CR>', '标签页：下一个')
  map('n', '<leader>tf', '<cmd>tabfind<CR>', '标签页：查找')

  -- ----------------------------------------------------------
  -- 编译 / 任务（阶段编译）
  -- ----------------------------------------------------------
  map('n', '<leader>cc', function()
    require('core.tasks').run('check')
  end, '编译：检查阶段')
  map('n', '<leader>cb', function()
    require('core.tasks').run('build')
  end, '编译：构建阶段')
  map('n', '<leader>cr', function()
    require('core.tasks').run('run')
  end, '编译：运行')
  map('n', '<leader>ct', function()
    require('core.tasks').run('test')
  end, '编译：测试')
  map('n', '<leader>cl', function()
    require('core.tasks').list()
  end, '编译：列出任务')

  -- 实时编译开关（命令名需大写开头）
  vim.api.nvim_create_user_command('RealtimeCompile', function()
    vim.g.realtime_compile = not vim.g.realtime_compile
    local state = vim.g.realtime_compile and '开启' or '关闭'
    vim.notify('实时编译已' .. state, vim.log.levels.INFO)
  end, { desc = '切换实时编译开关' })
  map('n', '<leader>cz', '<cmd>RealtimeCompile<CR>', '实时编译：开/关')

  -- ----------------------------------------------------------
  -- LSP 快捷键（全局 + 缓冲区）
  -- ----------------------------------------------------------
  local lsp_map = {
    ['gd'] = { vim.lsp.buf.definition, 'LSP：跳转定义' },
    ['gD'] = { vim.lsp.buf.declaration, 'LSP：跳转声明' },
    ['gr'] = { vim.lsp.buf.references, 'LSP：查找引用' },
    ['gI'] = { vim.lsp.buf.implementation, 'LSP：跳转实现' },
    ['K'] = { vim.lsp.buf.hover, 'LSP：悬浮文档' },
    ['<C-k>'] = { vim.lsp.buf.signature_help, 'LSP：函数签名' },
    ['<leader>lr'] = { vim.lsp.buf.rename, 'LSP：重命名' },
    ['<leader>la'] = { vim.lsp.buf.code_action, 'LSP：代码操作' },
    ['<leader>lf'] = { function() vim.lsp.buf.format({ async = true }) end, 'LSP：格式化' },
    ['<leader>ld'] = { vim.diagnostic.open_float, 'LSP：诊断详情' },
    ['<leader>ln'] = { vim.lsp.buf.workspace_symbol, 'LSP：工作区符号' },
    ['<leader>li'] = { vim.lsp.buf.type_definition, 'LSP：跳转类型定义' },
    ['<leader>lq'] = { vim.diagnostic.setloclist, 'LSP：诊断列表' },
  }
  for lhs, item in pairs(lsp_map) do
    map('n', lhs, item[1], item[2])
  end

  -- ----------------------------------------------------------
  -- 通用编辑
  -- ----------------------------------------------------------
  map('n', '<leader>yy', '"+y', '复制整行')
  map('n', '<leader>dd', '"+d', '剪切整行')
  map('v', '<leader>y', '"+y', '复制选中')
  map('v', '<leader>d', '"+d', '剪切选中')
  map('n', '<leader>u', '<cmd>undo<CR>', '撤销')
  map('n', '<leader><C-r>', '<cmd>redo<CR>', '重做')
  map('n', 'j', 'gj', '向下移动（保持列）')
  map('n', 'k', 'gk', '向上移动（保持列）')
  map('n', '<leader>zh', '<cmd>nohlsearch<CR>', '清除搜索高亮')
  map('n', '<leader>zz', '<cmd>normal zt<CR>', '光标置顶')
  map('n', '<leader>zt', '<cmd>normal zz<CR>', '光标居中')
  map('n', '<leader>zb', '<cmd>normal zb<CR>', '光标置底')

  -- 注释
  map('n', 'gcc', '<cmd>CommentToggle<CR>', '注释：切换行注释')
  map('x', 'gcc', '<cmd>CommentToggle<CR>', '注释：切换行注释')
  map('n', 'gbc', '<cmd>CommentToggle<CR>', '注释：切换块注释')

  -- 搜索
  map('n', '<leader>s', '<cmd>write<CR>', '保存')
  map('n', 'n', 'n', '下一个匹配')
  map('n', 'N', 'N', '上一个匹配')
  map('n', '*', '<cmd>normal *<CR>', '搜索当前词（向下）')

  -- 诊断跳转
  map('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end, '诊断：上一个')
  map('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end, '诊断：下一个')
  map('n', '[e', function() vim.diagnostic.jump({ count = -1, float = true }) end, '错误：上一个')
  map('n', ']e', function() vim.diagnostic.jump({ count = 1, float = true }) end, '错误：下一个')

  -- 会话
  map('n', '<leader>ss', '<cmd>SessionSave<CR>', '会话：保存')
  map('n', '<leader>sl', '<cmd>SessionLoad<CR>', '会话：恢复')
  map('n', '<leader>sx', '<cmd>SessionDelete<CR>', '会话：删除')

  -- 折叠
  map('n', '<leader>zo', '<cmd>foldopen<CR>', '折叠：打开')
  map('n', '<leader>zc', '<cmd>foldclose<CR>', '折叠：关闭')
  map('n', '<leader>zR', '<cmd>foldopen! <CR>', '折叠：全部打开')
  map('n', '<leader>zM', '<cmd>foldclose! <CR>', '折叠：全部关闭')

  -- 缩进
  map('n', '<<', '<<', '减少缩进')
  map('n', '>>', '>>', '增加缩进')

  -- 标签页/缓冲区
  map('n', '<leader>bb', '<cmd>bdelete<CR>', '缓冲区：关闭当前')

  -- 帮助
  map('n', '<leader>hh', '<cmd>help<CR>', '打开帮助')
  map('n', 'g?', '<cmd>help<CR>', '打开帮助')

  -- 字符替换（简易）：<leader>sr
  -- 注意：原来的实现有两个问题
  --   1) 格式串只写了一个 %s，第二个参数（替换内容）被丢弃，
  --      实际执行成 :%s/关键词//gc —— 等于把匹配到的内容全部删除；
  --   2) 先问「替换为」再问「搜索」，顺序与直觉相反。
  -- 这里改成先问搜索词、再问替换词，并正确传入两个参数。
  map('n', '<leader>sr', function()
    vim.ui.input({ prompt = '搜索: ' }, function(search)
      if not search or search == '' then
        return
      end
      vim.ui.input({ prompt = '替换为: ' }, function(replace)
        if replace == nil then
          return
        end
        vim.cmd(('%%s/%s/%s/gc'):format(
          vim.fn.escape(search, '/'),
          vim.fn.escape(replace, '/')
        ))
      end)
    end)
  end, '替换：全文逐处确认替换')
end

return M
