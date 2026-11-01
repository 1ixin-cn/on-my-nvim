-- ============================================================
-- 会话持久化插件：persistence.nvim
-- 与 lua/core/autosave.lua 配合，关闭 nvim 后可完整恢复现场
-- ============================================================

return {
  {
    'folke/persistence.nvim',
    event = 'VeryLazy',
    config = function()
      require('persistence').setup({
        need_file_list = false,
        dir = vim.fn.stdpath('data') .. '/sessions',
        ignore = {
          'oil:', 'fugitive:', 'spectre_panel', 'neogitstatus', 'dapui_scopes',
        },
      })
    end,
  },

  -- ----------------------------------------------------------
  -- 已移除 Pocco81/auto-save.nvim
  -- ----------------------------------------------------------
  -- 原因：它内部 `nvim_create_augroup("AutoSave", { clear = true })`，与本项目
  -- lua/core/autosave.lua 的组名撞车。它在 VeryLazy 阶段加载，晚于我们的初始化，
  -- 于是把我们注册的 CursorHoldI / FocusLost / BufLeave / VimLeavePre 等
  -- **整组清空**，只留下它自己的 InsertLeave / TextChanged。
  -- 结果就是"插入模式停手不自动保存、退出不落盘"，而且不报任何错。
  --
  -- 它的 condition 还要求 filetype 非空，对 .txt / 无 filetype 的临时文件不生效。
  -- 我们自己的 core/autosave.lua 覆盖面更全，不需要这个插件。
}
