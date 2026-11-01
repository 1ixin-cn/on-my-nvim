-- ============================================================
-- 会话持久化：关闭 nvim 后重开，恢复标签页/窗口/光标/折叠
-- ------------------------------------------------------------
-- 配合 autosave.lua 的自动保存，做到"中途关闭和退出不丢内容"
-- ============================================================

local M = {}

function M.setup()
  -- ----------------------------------------------------------
  -- persistence.nvim：会话保存与恢复
  -- ----------------------------------------------------------
  require('persistence').setup({
    -- 恢复会话前先恢复上次窗口布局
    need_file_list = false,
    -- 会话文件保存目录
    dir = vim.fn.stdpath('data') .. '/sessions',
    -- 忽略的目录
    ignore = {
      'oil:', 'fugitive:', 'spectre_panel', 'neogitstatus',
    },
  })

  -- ----------------------------------------------------------
  -- 保存/恢复会话的命令
  -- ----------------------------------------------------------
  vim.api.nvim_create_user_command('SessionSave', function()
    require('persistence').save()
    vim.notify('会话已保存', vim.log.levels.INFO)
  end, { desc = '保存当前会话' })

  vim.api.nvim_create_user_command('SessionLoad', function()
    require('persistence').load()
  end, { desc = '恢复上次会话' })

  vim.api.nvim_create_user_command('SessionDelete', function()
    require('persistence').delete()
  end, { desc = '删除已保存的会话' })

  -- ----------------------------------------------------------
  -- 退出前自动保存会话
  -- ----------------------------------------------------------
  local group = vim.api.nvim_create_augroup('SessionPersist', { clear = true })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      pcall(function()
        require('persistence').save()
      end)
    end,
  })

  -- ----------------------------------------------------------
  -- 已移除：启动时扫描 swapdir 弹「检测到 N 个未保存的交换文件」的提示
  -- ----------------------------------------------------------
  -- 原因：这个检查只看 swapdir 里的文件数量，无法区分
  --   (a) 上次真的异常退出  (b) 另一个 nvim 窗口正开着同一个文件。
  -- 后者是日常常态（多窗口编辑），于是每开一个新 nvim 都会误报一次，
  -- 而且消息较长，必然触发 hit-enter（Press ENTER 才继续），非常烦。
  --
  -- 真正异常退出时不需要它：打开对应文件时 Neovim 自己会弹 E325
  -- ATTENTION 交换文件对话框，给出 (R)ecover / (D)elete / (Q)uit 选择，
  -- 定位更准确，也不会误报。
  --
  -- 想手动看一眼残留：:!ls ~/.local/share/nvim/swapdir
  -- 想手动恢复：    nvim -r 文件名
end

return M
