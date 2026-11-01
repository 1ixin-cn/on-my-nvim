-- ============================================================
-- 各语言增强插件
-- ============================================================

return {
  -- ----------------------------------------------------------
  -- Go 开发增强
  -- ----------------------------------------------------------
  {
    'ray-x/go.nvim',
    dependencies = {
      'ray-x/guihua.lua',
      'neovim/nvim-lspconfig',
      'nvim-treesitter/nvim-treesitter',
    },
    ft = { 'go' },
    config = function()
      require('go').setup({
        goimport = 'goimports',
        gofmt = 'gofumpt',
        max_line_len = 120,
        tag_transform = true,
        tag_opt = 'go1.17',
        test_runner = 'go',
        verbose_tests = true,
        should_split = true,
        gopls = {
          gofumpt = true,
          analyses = {
            unusedparams = true,
            unusedfunc = true,
            shadow = true,
            nilness = true,
          },
          staticcheck = true,
          use_placeholders = true,
          complete_unimported = true,
          deep_completion = true,
          goto_references = true,
        },
      })
    end,
  },

  -- ----------------------------------------------------------
  -- Python 开发增强
  -- ----------------------------------------------------------
  {
    'linux-cultist/venv-selector.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    ft = 'python',
    cmd = { 'VenvSelect', 'VenvSelectAll', 'VenvClear', 'VenvClearAll' },
    init = function()
      vim.keymap.set('n', '<leader>cv', '<cmd>VenvSelect<CR>', { desc = '选择 Python 虚拟环境' })
      vim.keymap.set('n', '<leader>cvA', '<cmd>VenvSelectAll<CR>', { desc = '为所有窗口选择虚拟环境' })
    end,
    config = function()
      require('venv-selector').setup({
        python_command = 'python3',
        finder = 'telescope',
        mappings = {
          use = '<CR>',
          browse = '<C-b>',
        },
      })
    end,
  },

  -- ----------------------------------------------------------
  -- C/C++ 构建工具
  -- ----------------------------------------------------------
  {
    'Civitasv/cmake-tools.nvim',
    ft = { 'cpp', 'c' },
    cmd = { 'CMakeGenerate', 'CMakeBuild', 'CMakeRun', 'CMakeSelectBuildPreset' },
    init = function()
      vim.keymap.set('n', '<leader>cg', '<cmd>CMakeGenerate<CR>', { desc = 'CMake：生成构建文件' })
      vim.keymap.set('n', '<leader>cb', '<cmd>CMakeBuild<CR>', { desc = 'CMake：构建' })
      vim.keymap.set('n', '<leader>cr', '<cmd>CMakeRun<CR>', { desc = 'CMake：运行' })
    end,
    config = function()
      require('cmake-tools').setup({
        cmake_command = 'cmake',
        ctest_command = 'ctest',
        cmake_build_directory = 'build',
        cmake_soft_link_compile_commands = true,
        cmake_use_preset = false,
        cmake_use_clangd = true,
        cmake_dap_configuration = {
          name = 'codelldb',
          type = 'codelldb',
          request = 'launch',
          program = '${file}',
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
          runInTerminal = false,
        },
      })
    end,
  },

  -- ----------------------------------------------------------
  -- Rust 增强
  -- 说明：rust-analyzer 的 LSP 已在 core/lsp.lua 用新 API 配置并 enable，
  -- 此处仅启用 rustaceanvim 的工具集（代码动作、测试等），避免双重启动 LSP。
  -- ----------------------------------------------------------
  {
    'mrcjkb/rustaceanvim',
    cond = function()
      -- 仅在 Rust 工具链可用时启用
      local mason_ra = vim.fn.stdpath('data') .. '/mason/bin/rust-analyzer'
      return vim.fn.exepath('cargo') ~= ''
        or vim.fn.exepath('rustc') ~= ''
        or vim.fn.filereadable(mason_ra) == 1
    end,
    ft = { 'rust' },
    init = function()
      vim.keymap.set('n', '<leader>rR', '<cmd>RustLspRestart<CR>', { desc = 'Rust：重启 rust-analyzer' })
    end,
    config = function()
      -- 注意：rustaceanvim 没有 setup() 函数，配置通过 vim.g.rustaceanvim 传递。
      -- 写成 require('rustaceanvim').setup(...) 会在打开 Rust 文件时报
      -- "attempt to call field 'setup' (a nil value)"。
      local paths = require('core.paths')
      vim.g.rustaceanvim = {
        -- rustaceanvim 会自行启动并管理 rust-analyzer 客户端，
        -- 因此 core/lsp.lua 中不再对 rust_analyzer 调 vim.lsp.enable，
        -- 否则同一缓冲区会挂两个 LSP 客户端（重复诊断 + 双倍内存）。
        server = {
          cmd = { paths.resolve('rust-analyzer') },
          default_settings = {
            ['rust-analyzer'] = {
              -- 关掉 rust-analyzer 自带的 flycheck（保存时跑 cargo check）。
              -- 原因有两条：
              --   1) 诊断重复：同一处类型错误会被报两次，一次 source=rust-analyzer
              --      （原生推断），一次 source=rustc（flycheck 调 cargo check 的结果），
              --      在 Trouble 面板里看着像两个不同的问题。
              --   2) 编译重复：本配置已在保存时跑「实时编译」（core/tasks.lua 的
              --      cargo check），再接上 RA 的 flycheck 等于每次保存跑两遍 cargo，
              --      还会抢 target 目录锁，保存变慢。
              -- 原生诊断（source=rust-analyzer）保留，打字时即可实时报错；
              -- 编译器级别的检查交给保存时的实时编译，并由 tasks.lua 做跨来源去重。
              checkOnSave = false,
              check = { command = 'clippy' },
              cargo = { allFeatures = true, buildScripts = { enable = true } },
              procMacro = { enable = true },
            },
          },
        },
        tools = {
          test_executor = 'background',
          float_win_config = { border = 'rounded' },
        },
        dap = {
          -- 交由 core/dap.lua 的 codelldb 配置处理，避免重复注册
          autoload_configurations = false,
        },
      }
    end,
  },

  -- ----------------------------------------------------------
  -- Rust 测试与 cargo 辅助命令（由 rustaceanvim 提供）
  -- ----------------------------------------------------------
}
