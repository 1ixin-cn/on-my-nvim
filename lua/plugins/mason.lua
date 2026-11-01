-- ============================================================
-- Mason：LSP / DAP / 格式化工具 的自动安装管理
-- ============================================================

return {
  -- Mason 本体
  {
    'williamboman/mason.nvim',
    cmd = { 'Mason', 'MasonInstall', 'MasonUninstall', 'MasonUpdate', 'MasonLog' },
    init = function()
      vim.g.mapleader = ' '
      vim.keymap.set('n', '<leader>ms', '<cmd>Mason<CR>', { desc = 'Mason 面板' })
      vim.keymap.set('n', '<leader>mi', '<cmd>MasonInstall<CR>', { desc = 'Mason 安装工具' })
      vim.keymap.set('n', '<leader>mu', '<cmd>MasonUpdate<CR>', { desc = 'Mason 更新工具' })
    end,
    config = function()
      require('mason').setup({
        ui = {
          border = 'rounded',
          icons = {
            package_installed = '✓',
            package_pending = '➜',
            package_uninstalled = '✗',
          },
        },
        max_concurrent_installers = 6,
        install_root_dir = vim.fn.stdpath('data') .. '/mason',
      })
    end,
  },

  -- Mason 与 lspconfig 的桥梁
  {
    'williamboman/mason-lspconfig.nvim',
    dependencies = { 'williamboman/mason.nvim', 'neovim/nvim-lspconfig' },
    cmd = { 'LspInstall', 'LspUninstall' },
    init = function()
      vim.keymap.set('n', '<leader>li', '<cmd>LspInstall<CR>', { desc = '安装 LSP 服务器' })
      vim.keymap.set('n', '<leader>lu', '<cmd>LspUninstall<CR>', { desc = '卸载 LSP 服务器' })
    end,
    config = function()
      require('mason-lspconfig').setup({
        ensure_installed = {
          -- 语言服务器
          'gopls',             -- Go
          'pyright',           -- Python 类型检查
          'rust-analyzer',     -- Rust
          'clangd',            -- C / C++          'lua-language-server',
          'bash-language-server',
          'docker-language-server',
          'json-lsp',
          'yaml-language-server',
          'helm-ls',
          'marksman',          -- Markdown
          'sqls',              -- SQL
        },
        automatic_installation = true,
      })
    end,
  },

  -- Mason 工具安装器：自动装格式化器、调试器
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'williamboman/mason.nvim' },
    cmd = { 'MasonToolsInstall', 'MasonToolsUninstall', 'MasonToolsUpdate' },
    config = function()
      require('mason-tool-installer').setup({
        ensure_installed = {
          -- 格式化器
          'stylua',          -- Lua
          'clang-format',    -- C / C++
          'goimports',       -- Go
          'gofumpt',         -- Go
          'ruff',            -- Python
          'prettierd',       -- YAML / JSON / Markdown
          'yamllint',        -- YAML
          -- 调试器
          'debugpy',         -- Python 调试
          'delve',           -- Go 调试 (dlv)
          'codelldb',        -- C / C++ / Rust 调试 (LLDB)
          -- 其他
          'shellcheck',      -- Shell 检查
          'taplo',           -- TOML 格式化
        },
        auto_update = true,
        run_on_start = true,
        debounce_hours = 24,
      })
    end,
  },
}
