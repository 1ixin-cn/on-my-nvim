-- ============================================================
-- LSP 配置（适配 Neovim 0.13 的 vim.lsp.config 新 API）
-- ============================================================

local M = {}

-- 二进制路径解析（跳过失效的 rustup shim）
local paths = require('core.paths')

-- LSP 公共设置
local function common()
  return {
    -- 诊断自动在浮动窗口中展示
    diagnostics = {
      severity_sort = true,
      underline = true,
      virtual_text = { spacing = 2, source = 'if_many' },
      float = {
        border = 'rounded',
        source = true,
        header = '',
        prefix = '',
      },
    },
    -- 代码动作使用浮动窗口
    workspace = {
      check_workspace = false,
    },
    -- 悬停信息自动换行
    hover = {
      border = 'rounded',
      wrap = true,
    },
  }
end

function M.setup()
  -- ----------------------------------------------------------
  -- Python：ruff（快）+ pyright（准）双服务器
  -- ----------------------------------------------------------
  vim.lsp.config('ruff', {
    cmd = { 'ruff', 'server' },
    filetypes = { 'python' },
    root_markers = { 'pyproject.toml', 'setup.py', 'requirements.txt', 'Pipfile', 'pyproject.toml' },
    settings = {
      -- ruff 内置 LSP，只处理 lint / 快速修复，不做类型检查
      ['ruff'] = {
        logLevel = 'warn',
        showSyntaxErrors = false,
        fixAll = true,
        organizeImports = true,
      },
    },
  })

  vim.lsp.config('pyright', {
    cmd = { 'pyright-langserver', '--stdio' },
    filetypes = { 'python' },
    root_markers = {
      'pyproject.toml',
      'setup.py',
      'setup.cfg',
      'requirements.txt',
      'Pipfile',
      'pyrightconfig.json',
    },
    settings = {
      python = {
        analysis = {
          autoSearchPaths = true,
          diagnosticMode = 'workspace',
          typeCheckingMode = 'basic',
          useLibraryCodeForTypes = true,
          stubPath = 'typings',
        },
      },
    },
  })

  -- ----------------------------------------------------------
  -- Go：gopls
  -- ----------------------------------------------------------
  vim.lsp.config('gopls', {
    cmd = { 'gopls' },
    filetypes = { 'go', 'gomod', 'gowork' },
    root_markers = { 'go.work', 'go.mod' },
    settings = {
      gopls = {
        analyses = {
          unusedparams = true,
          unusedfunc = true,
          unusedvariable = true,
          shadow = true,
          nilness = true,
        },
        staticcheck = true,
        gofumpt = true,
        usePlaceholders = true,
        completeUnimported = true,
        deepCompletion = true,
        semanticTokens = true,
      },
    },
  })

  -- ----------------------------------------------------------
  -- Rust：rust-analyzer
  -- ----------------------------------------------------------
  vim.lsp.config('rust_analyzer', {
    -- 显式解析路径：~/.cargo/bin/rust-analyzer 是失效的 rustup shim，
    -- 直接用 PATH 可能命中它导致启动失败
    cmd = { paths.resolve('rust-analyzer') },
    filetypes = { 'rust' },
    root_markers = { 'rust-project.json', 'Cargo.toml', 'Cargo.lock' },
    settings = {
      ['rust-analyzer'] = {
        -- 关掉 RA 自带 flycheck。理由同 plugins/langs.lua：
        -- 保存时的 cargo check 由实时编译（core/tasks.lua）负责，
        -- 两边都开会重复诊断 + 重复编译。
        checkOnSave = false,
        check = {
          command = 'clippy',
          extraArgs = { '--no-deps' },
        },
        cargo = {
          allFeatures = true,
          buildScripts = { enable = true },
        },
        procMacro = { enable = true },
        rustc = { source = 'rustc', onSave = { enable = true } },
        files = {
          excludeDirs = { 'target', '.git' },
        },
      },
    },
  })

  -- ----------------------------------------------------------
  -- C / C++：clangd
  -- ----------------------------------------------------------
  vim.lsp.config('clangd', {
    cmd = { 'clangd' },
    filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
    root_markers = {
      'compile_commands.json',
      'compile_flags.txt',
      '.clangd',
      'CMakeLists.txt',
      'meson.build',
    },
    init_options = {
      clangdFileStatus = true,   -- 实时显示编译状态
      diagnosticHints = false,
      completionAllHeaderPaths = true,
      index = {
        memoryBudget = 104857600, -- 100MB 索引内存
      },
    },
  })

  -- ----------------------------------------------------------
  -- 其他语言（保持原有能力）
  -- ----------------------------------------------------------
  vim.lsp.config('lua_ls', {
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    root_markers = { '.luarc.json', '.luarc.jsonc', 'stylua.toml' },
    settings = {
      Lua = {
        diagnostics = {
          globals = { 'vim' },
          disable = { 'undefined-global' },
        },
        runtime = {
          version = 'LuaJIT',
        },
        workspace = {
          checkThirdParty = false,
          library = {
            '+lua',
          },
        },
      },
    },
  })

  vim.lsp.config('jsonls', {
    cmd = { 'vscode-json-language-server', '--stdio' },
    filetypes = { 'json', 'jsonc' },
    root_markers = { '.git', 'package.json' },
    settings = {
      json = {
        schemas = {
          ['https://json.schemastore.org/package.json'] = 'package.json',
        },
        validate = { enable = true },
      },
    },
  })

  vim.lsp.config('yamlls', {
    cmd = { 'yaml-language-server', '--stdio' },
    filetypes = { 'yaml' },
    root_markers = { '.git', 'package.json', 'go.mod', 'Cargo.toml' },
    settings = {
      yaml = {
        schemas = {
          kubernetes = '/*.yaml',
          ['https://json.schemastore.org/github-workflow.json'] = '/.github/workflows/*.yml',
        },
        validate = { enable = true },
        hover = true,
        completion = { key = true },
      },
    },
  })

  vim.lsp.config('dockerls', {
    cmd = { 'docker-langserver', '--stdio' },
    filetypes = { 'dockerfile', 'dockercompose' },
    root_markers = { 'Dockerfile', 'docker-compose.yml', 'compose.yaml' },
  })

  vim.lsp.config('bashls', {
    cmd = { 'bash-language-server', 'start' },
    filetypes = { 'bash', 'sh' },
    root_markers = { '.git', '.bashrc', 'PKGBUILD' },
  })

  vim.lsp.config('marksman', {
    cmd = { 'marksman' },
    filetypes = { 'markdown', 'mdx' },
    root_markers = { '.git', '.markdownlint*' },
  })

  vim.lsp.config('sqls', {
    cmd = { 'sqls' },
    filetypes = { 'sql', 'mysql' },
    root_markers = { '.git' },
  })

  -- 合并公共设置
  vim.lsp.config('*', common())

  -- ----------------------------------------------------------
  -- 启用所有服务器（0.11+ 新 API：config 只注册，必须 enable 才会启动）
  -- ----------------------------------------------------------
  -- 说明：rust_analyzer 不在此列表中。
  -- rustaceanvim（plugins/langs.lua）会在 Rust 缓冲区自行启动并管理
  -- rust-analyzer；若这里也 enable，同一缓冲区会挂两个客户端，
  -- 表现为诊断重复、内存翻倍、保存时触发两次 cargo check。
  local servers = {
    'ruff',
    'pyright',
    'gopls',
    'clangd',
    'lua_ls',
    'jsonls',
    'yamlls',
    'dockerls',
    'bashls',
    'marksman',
    'sqls',
  }
  for _, server in ipairs(servers) do
    local ok, err = pcall(vim.lsp.enable, server)
    if not ok then
      vim.notify(('启用 LSP %s 失败: %s'):format(server, tostring(err)), vim.log.levels.WARN)
    end
  end
end

return M
