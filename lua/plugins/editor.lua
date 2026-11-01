-- ============================================================
-- 日常效率插件：格式化 / 检查 / 文件树 / 补全辅助 / Git / 终端 等
-- ============================================================

return {
  -- ----------------------------------------------------------
  -- Treesitter：高亮与缩进（现代高亮引擎）
  -- ----------------------------------------------------------
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      -- nvim-treesitter 新版使用 require('nvim-treesitter').setup()
      local ok, ts = pcall(require, 'nvim-treesitter')
      if ok and type(ts.setup) == 'function' then
        ts.setup({
          ensure_installed = {
            'go', 'python', 'rust', 'cpp', 'c', 'lua', 'vim', 'vimdoc',
            'dockerfile', 'yaml', 'json', 'jsonc', 'helm', 'bash', 'markdown',
            'toml', 'gomod', 'gomod_sum', 'gosum', 'gowork', 'query',
          },
          highlight = { enable = true },
          indent = { enable = true },
          incremental_selection = {
            enable = true,
            keymaps = {
              init_selection = '<C-space>',
              node_incremental = '<C-space>',
              node_decremental = '<bs>',
            },
          },
        })
      else
        -- 回退到旧版 API
        require('nvim-treesitter.config').setup({
          ensure_installed = {
            'go', 'python', 'rust', 'cpp', 'c', 'lua', 'vim', 'vimdoc',
            'dockerfile', 'yaml', 'json', 'helm', 'bash', 'markdown', 'toml',
          },
          highlight = { enable = true },
          indent = { enable = true },
        })
      end
    end,
  },

  -- ----------------------------------------------------------
  -- Conform：保存时自动格式化
  -- ----------------------------------------------------------
  {
    'stevearc/conform.nvim',
    config = function()
      require('conform').setup({
        format_on_save = {
          timeout_ms = 1000,
          lsp_format = 'fallback',
        },
        formatters_by_ft = {
          go = { 'goimports', 'gofumpt' },
          python = { 'ruff_format' },
          rust = { 'rustfmt' },
          cpp = { 'clang_format' },
          c = { 'clang_format' },
          lua = { 'stylua' },
          yaml = { 'prettierd' },
          json = { 'prettierd' },
          jsonc = { 'prettierd' },
          markdown = { 'prettierd' },
          sh = { 'shfmt' },
          toml = { 'taplo' },
        },
        -- 格式化失败时自动切换到 LSP 格式化
        formatters = {
          rust = { 'rustfmt', 'taplo' },
        },
      })
    end,
  },

  -- ----------------------------------------------------------
  -- nvim-lint：静态检查
  -- ----------------------------------------------------------
  {
    'mfussenegger/nvim-lint',
    config = function()
      local lint = require('lint')
      lint.linters_by_ft = {
        python = { 'ruff' },
        yaml = { 'yamllint' },
        bash = { 'shellcheck' },
        lua = { 'luacheck' },
      }
      -- 有装才启用
      if vim.fn.executable('golangci-lint') == 1 then
        lint.linters_by_ft.go = { 'golangcilint' }
      end
      if vim.fn.executable('hadolint') == 1 then
        lint.linters_by_ft.dockerfile = { 'hadolint' }
      end
      vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave' }, {
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },

  -- ----------------------------------------------------------
  -- Git 集成
  -- ----------------------------------------------------------
  {
    'lewis6991/gitsigns.nvim',
    init = function()
      vim.keymap.set('n', '<leader>gs', '<cmd>Gitsigns stage_hunk<CR>', { desc = 'Git：暂存改动块' })
      vim.keymap.set('n', '<leader>gS', '<cmd>Gitsigns stage_buffer<CR>', { desc = 'Git：暂存整个文件' })
      vim.keymap.set('n', '<leader>gr', '<cmd>Gitsigns reset_hunk<CR>', { desc = 'Git：撤销改动块' })
      vim.keymap.set('n', '<leader>gp', '<cmd>Gitsigns preview_hunk<CR>', { desc = 'Git：预览改动' })
      vim.keymap.set('n', '<leader>gb', '<cmd>Gitsigns blame_line<CR>', { desc = 'Git：行级 blame' })
    end,
    config = function()
      require('gitsigns').setup({
        current_line_blame = false,
        current_line_blame_opts = { delay = 300, virt_text = true, virt_text_pos = 'eol' },
        signcolumn = true,
        numhl = false,
        linehl = false,
        word_diff = true,
        watch_gitdir = { interval = 1000, follow_files = true },
        on_attach = function(bufnr)
          local gs = require('gitsigns')
          local opts = { buffer = bufnr }
          vim.keymap.set('n', '<leader>gs', gs.stage_hunk, opts)
          vim.keymap.set('n', '<leader>gS', gs.stage_buffer, opts)
          vim.keymap.set('n', '<leader>gr', gs.reset_hunk, opts)
          vim.keymap.set('n', '<leader>gp', gs.preview_hunk, opts)
          vim.keymap.set('n', '<leader>gb', gs.blame_line, opts)
        end,
      })
    end,
  },

  -- ----------------------------------------------------------
  -- 终端
  -- ----------------------------------------------------------
  {
    'akinsho/toggleterm.nvim',
    init = function()
      vim.keymap.set('n', '<C-\\>', '<cmd>ToggleTerm<CR>', { desc = '终端 开/关' })
      vim.keymap.set('t', '<C-\\>', '<cmd>ToggleTerm<CR>', { desc = '终端 开/关' })
    end,
    config = function()
      require('toggleterm').setup({
        direction = 'float',
        float_opts = { border = 'rounded', winblend = 0 },
        size = function(term)
          if term.direction == 'horizontal' then
            return math.floor(term.size * 0.3)
          end
          return math.floor(term.size * 0.6)
        end,
        shading = false,
        start_in_insert = true,
        insert_mappings = true,
        persist_size = true,
      })
    end,
  },

  -- ----------------------------------------------------------
  -- 缓冲区标签页
  -- ----------------------------------------------------------
  {
    'akinsho/bufferline.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    init = function()
      vim.keymap.set('n', '<S-h>', '<cmd>BufferLineCyclePrev<CR>', { desc = '上一个缓冲区' })
      vim.keymap.set('n', '<S-l>', '<cmd>BufferLineCycleNext<CR>', { desc = '下一个缓冲区' })
      vim.keymap.set('n', '<leader>bd', '<cmd>BufferLineDelete<CR>', { desc = '关闭当前缓冲区' })
    end,
    opts = {
      options = {
        diagnostics = 'nvim_lsp',
        close_command = 'bdelete! %d',
        separator_style = 'slant',
        show_close_icon = false,
        show_buffer_close_icons = false,
        buffer_close_icon = '󰅖',
        modified_icon = '●',
      },
    },
    config = function(_, opts)
      require('bufferline').setup(opts)
    end,
  },

  -- ----------------------------------------------------------
  -- 自动配对括号 / 换行
  -- ----------------------------------------------------------
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = function()
      require('nvim-autopairs').setup({
        enable_check_bracket_line = true,
        enable_afterquote = true,
        enable_filetype = {
          python = { enable = false },  -- Python 单引号优先，避免干扰文档字符串
        },
        map_bs = true,
        map_check_mirror = true,
        map_cbracket = true,
      })
    end,
  },

  -- ----------------------------------------------------------
  -- 注释
  -- ----------------------------------------------------------
  {
    'numToStr/Comment.nvim',
    cmd = { 'CommentToggle' },
    init = function()
      vim.keymap.set('n', '<leader>cl', '<cmd>CommentToggle<CR>', { desc = '注释 切换' })
      vim.keymap.set('x', '<leader>cl', '<cmd>CommentToggle<CR>', { desc = '注释 切换' })
    end,
    config = function()
      require('Comment').setup({
        padding = true,
        sticky = true,
        toggler = {
          line = 'gcc',
          block = 'gbc',
        },
      })
    end,
  },

  -- ----------------------------------------------------------
  -- TODO 标记
  -- ----------------------------------------------------------
  {
    'folke/todo-comments.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = 'TodoTelescope',
    init = function()
      vim.keymap.set('n', '<leader>to', '<cmd>TodoTelescope<CR>', { desc = '搜索 TODO 标记' })
    end,
    config = function()
      require('todo-comments').setup({
        signs = true,
        keywords = {
          FIX = { icon = ' ', color = 'error', alt = { 'FIX', 'FIXME', 'BUG', 'XXX' } },
          TODO = { icon = ' ', color = 'info', alt = { 'TODO', 'FIXME', 'XXX' } },
          WARN = { icon = ' ', color = 'warning', alt = { 'WARN', 'WARNING' } },
          NOTE = { icon = '󰠰 ', color = 'hint', alt = { 'NOTE', 'INFO' } },
          HACK = { icon = '󰄲 ', color = 'comment' },
        },
      })
    end,
  },

  -- ----------------------------------------------------------
  -- 缩进线
  -- ----------------------------------------------------------
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {
      indent = { char = '│' },
      scope = { enabled = false },
      exclude = { filetypes = { 'TelescopePrompt', 'neo-tree' } },
    },
    config = function(_, opts)
      require('ibl').setup(opts)
    end,
  },

  -- ----------------------------------------------------------
  -- 快速跳转
  -- ----------------------------------------------------------
  {
    'ggandor/leap.nvim',
    version = '*',
    config = function()
      require('leap').setup({
        leap = { chars = { 's', 'f', 't', 'r', 'c', 'n' } },
        unknown = { 60 },
        safe_labels = {
          [';'] = { action = 'preview', mode = { 'n', 'x' } },
        },
      })
    end,
  },

  -- ----------------------------------------------------------
  -- 代码大纲（基于 LSP 的符号导航，类似 IDE 的 Structure 面板）
  -- ----------------------------------------------------------
  {
    'SmiteshP/nvim-navic',
    dependencies = { 'neovim/nvim-lspconfig' },
    init = function()
      vim.keymap.set('n', '<leader>nl', '<cmd>NavicToggle<CR>', { desc = '代码大纲 开/关' })
      vim.keymap.set('n', '<leader>na', '<cmd>NavicOpen<CR>', { desc = '代码大纲：跳转符号' })
    end,
    config = function()
      require('nvim-navic').setup({
        icons = {
          File = '󰈙 ',
          Module = '󰆧 ',
          Namespace = '󰦮 ',
          Package = '󰏗 ',
          Class = '󰠱 ',
          Method = '󰆧 ',
          Property = '󰜢 ',
          Field = '󰜢 ',
          Constructor = '󰛖 ',
          Enum = '󰡧 ',
          Interface = '󰡨 ',
          Function = '󰡕 ',
          Variable = '󰀫 ',
          Constant = '󰏿 ',
          String = '󰗽 ',
          Number = '󰎠 ',
          Boolean = '󰨙 ',
          Array = '󰅪 ',
          Object = '󰀨 ',
          Key = '󰌋 ',
          Null = '󰟢 ',
          EnumMember = '󰠸 ',
          Struct = '󰙅 ',
          Event = '󰆗 ',
          Operator = '󰛥 ',
          TypeParameter = '󰡸 ',
        },
        separator = '▸',
        highlight = true,
        icons_only = false,
        depth_limit = 0,
        sort = false,
      })
    end,
  },
}
