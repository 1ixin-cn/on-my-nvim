-- ============================================================
-- LSP 客户端配置：能力声明、快捷键、格式化、代码操作
-- ============================================================

return {
  {
    'neovim/nvim-lspconfig',
    config = function()
      -- 实际服务器配置见 lua/core/lsp.lua（使用 0.13 新 API）
      require('core.lsp').setup()

      -- --------------------------------------------------------
      -- 公共能力：告诉服务器我们支持哪些功能
      -- --------------------------------------------------------
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities.textDocument.completion.completionItem.snippetSupport = true
      capabilities.textDocument.completion.completionItem.resolveSupport = {
        properties = { 'documentation', 'detail', 'additionalTextEdits' },
      }
      capabilities.workspace.workspaceFolders = true
      capabilities.workspace.fileOperations.didRename = true
      capabilities.workspace.fileOperations.willRename = true
      capabilities.experimental = {
        snippetTextEdit = true,
        codeActionGroup = true,
        inlineValue = { minLine = 3, maxLine = 300 },
        colorProvider = true,
        foldedText = true,
      }
      vim.lsp.config('*', { capabilities = capabilities })
    end,
  },

  -- ----------------------------------------------------------
  -- Trouble：错误/警告面板（编译诊断、类型错误集中显示）
  -- ----------------------------------------------------------
  {
    'folke/trouble.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    cmd = 'Trouble',
    init = function()
      vim.keymap.set('n', '<leader>xx', '<cmd>TroubleToggle<CR>', { desc = '问题面板 开/关' })
      vim.keymap.set('n', '<leader>xd', '<cmd>TroubleToggle diagnostics<CR>', { desc = '问题面板：诊断' })
      vim.keymap.set('n', '<leader>xq', '<cmd>TroubleToggle quickfix<CR>', { desc = '问题面板：快速修复' })
      vim.keymap.set('n', '<leader>xr', '<cmd>TroubleToggle lsp_references<CR>', { desc = '问题面板：引用' })
      vim.keymap.set('n', '<leader>xt', '<cmd>TroubleToggle todo<CR>', { desc = '问题面板：TODO' })
      vim.keymap.set('n', '<leader>xts', '<cmd>TroubleToggle text<CR>', { desc = '问题面板：文本搜索' })
      vim.keymap.set('n', '<leader>xc', '<cmd>TroubleToggle code_action<CR>', { desc = '问题面板：代码操作' })
    end,
    config = function()
      require('trouble').setup({
        use_diagnostic_signs = true,
        action_keys = {
          close = 'q',
          cancel = '<Esc>',
          confirm = '<CR>',
          open = 'o',
          open_split = '<C-s>',
          toggle_or_open = '<CR>',
          toggle_or_open_split = '<C-s>',
        },
        severity = {
          sort = true,
          reverse = true,
        },
        folders = {
          text = { only_current = true },
        },
        format = {
          indent = 2,
          max_width = 120,
          focus = true,
          row = 1,
          sign = true,
          signcolumn = true,
          base = { max_width = 60 },
          icons = { source = '󰌋' },
        },
        use_diagnostic_signs = true,
      })
    end,
  },

  -- ----------------------------------------------------------
  -- LSP 代码操作与重命名的增强 UI
  -- ----------------------------------------------------------
}
