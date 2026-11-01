-- ============================================================
-- UI 插件组：主题 / 状态栏 / 文件树 / 模糊搜索 / 快捷键提示
-- 全部配置中文界面
-- ============================================================

return {
  -- ----------------------------------------------------------
  -- 中文帮助文档
  -- 安装在 lazy 目录之外（本地 tarball 安装，规避代理导致的 git 克隆失败）
  -- ----------------------------------------------------------
  {
    'yianwillis/vimcdoc',
    dir = vim.fn.stdpath('data') .. '/plugins-local/vimcdoc',
    lazy = false,
  },

  -- ----------------------------------------------------------
  -- 主题
  -- ----------------------------------------------------------
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme('tokyonight')
      -- 背景透明可通过 :set background=transparent 开启
    end,
  },

  -- ----------------------------------------------------------
  -- 状态栏（中文）
  -- ----------------------------------------------------------
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup({
        options = {
          theme = 'tokyonight',
          globalstatus = true,
          section_separators = { left = '', right = '' },
          component_separators = { left = '', right = '' },
          disabled_filetypes = { statusline = { 'TelescopePrompt', ' Trouble' } },
        },
        sections = {
          lualine_a = {
            { 'mode', fmt = function(str)
              local zh = {
                ['NORMAL'] = '普通', ['INSERT'] = '插入', ['VISUAL'] = '可视',
                ['SELECT'] = '选择', ['REPLACE'] = '替换', ['COMMAND'] = '命令行',
                ['TERMINAL'] = '终端', ['INSERT PAIR'] = '插入',
              }
              return zh[str] or str
            end },
          },
          lualine_b = {
            { 'branch', icon = '' },
            'diagnostics',
          },
          lualine_c = {
            { 'filename', path = 1, symbols = { modified = ' ●', readonly = ' 󰌾' } },
          },
          lualine_x = {
            { 'encoding', symbols = { ['utf-8'] = 'UTF-8', ['gbk'] = 'GBK' } },
            { 'fileinfo', symbols = { filesize = '󰈚 %s' } },
          },
          lualine_y = {
            { 'progress', symbols = { progress = '󰓦 %s%%' } },
            { 'lsp_progress', symbols = { client = '%s' } },
          },
          lualine_z = {
            { 'position', symbols = { position = ' %l:%c' } },
            { 'diff', symbols = { added = ' 󰐁', modified = ' 󰏫', removed = ' 󰐅' } },
          },
        },
        on_config = function()
          -- 中文语言模式标签已通过 mode 组件的 fmt 参数实现
        end,
      })
    end,
  },

  -- ----------------------------------------------------------
  -- 文件树（中文）
  -- ----------------------------------------------------------
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    init = function()
      vim.keymap.set('n', '<leader>e', '<cmd>NvimTreeToggle<CR>', { desc = '文件树 开/关' })
      vim.keymap.set('n', '<leader>o', '<cmd>NvimTreeFocus<CR>', { desc = '文件树 聚焦' })
    end,
    config = function()
      -- 兼容 nvim 0.13-dev：SessionWritePre 事件已被移除，
      -- nvim-tree 的 0.13 分支仍在注册它会导致配置失败。
      -- 做法：在加载前临时屏蔽该事件名，加载后恢复。
      local orig_create = vim.api.nvim_create_autocmd
      vim.api.nvim_create_autocmd = function(event, opts)
        if event == 'SessionWritePre' then
          return
        end
        return orig_create(event, opts)
      end
      local ok, err = pcall(function()
        require('nvim-tree').setup({
          hijack_directories = { enable = false },
          update_focused_file = { enable = true },
          diagnostics = { enable = true, show_on_dirs = true },
          view = {
            adaptive_size = true,
            side = 'left',
            width = 32,
            preserve_window_proportions = false,
          },
          git = {
            enable = true,
            ignore = true,
            timeout = 1000,
          },
          filesystem_watchers = { enable = true },
          renderer = {
            highlight_git = true,
            highlight_opened_files = 'name',
            indent_markers = { enable = true },
          },
          actions = {
            open_file = {
              resize_window = true,
              quit_on_open = false,
            },
          },
        })
      end)
      vim.api.nvim_create_autocmd = orig_create
      if not ok then
        vim.notify('nvim-tree 配置失败: ' .. tostring(err), vim.log.levels.ERROR)
      end
    end,
  },

  -- ----------------------------------------------------------
  -- 模糊搜索（中文提示）
  -- ----------------------------------------------------------
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = 'Telescope',
    init = function()
      vim.keymap.set('n', '<leader>ff', '<cmd>Telescope find_files<CR>', { desc = '查找文件' })
      vim.keymap.set('n', '<leader>fg', '<cmd>Telescope live_grep<CR>', { desc = '全局搜索内容' })
      vim.keymap.set('n', '<leader>fb', '<cmd>Telescope buffers<CR>', { desc = '切换缓冲区' })
      vim.keymap.set('n', '<leader>fh', '<cmd>Telescope help_tags<CR>', { desc = '搜索帮助文档' })
      vim.keymap.set('n', '<leader>fr', '<cmd>Telescope oldfiles<CR>', { desc = '最近打开的文件' })
      vim.keymap.set('n', '<leader>fp', '<cmd>Telescope find_command<CR>', { desc = '查找可执行命令' })
      vim.keymap.set('n', '<leader>fs', '<cmd>Telescope git_status<CR>', { desc = 'Git 状态' })
      vim.keymap.set('n', '<leader>fc', '<cmd>Telescope git_commits<CR>', { desc = 'Git 提交历史' })
      vim.keymap.set('n', '<leader>fk', '<cmd>Telescope keymaps<CR>', { desc = '搜索快捷键' })
      vim.keymap.set('n', '<leader>fm', '<cmd>Telescope marks<CR>', { desc = '跳转标记' })
      vim.keymap.set('n', '<leader>fd', '<cmd>Telescope diagnostics<CR>', { desc = '搜索诊断信息' })
    end,
    config = function()
      require('telescope').setup({
        prompt_title = '搜索',
        selection_caret = '> ',
        entry_prefix = '  ',
        sorting_strategy = 'ascending',
        layout_strategy = 'horizontal',
        layout_config = {
          horizontal = { prompt_position = 'top', mirror = false },
          vertical = { mirror = false },
        },
        path_display = { 'truncate' },
        file_ignore_patterns = {
          '%.git/', 'node_modules/', 'target/', '__pycache__/', '%.venv/', 'venv/', 'dist/', 'build/',
        },
        defaults = {
          prompt_prefix = '🔍 ',
          selection_caret = '❯ ',
          entry_prefix = '📁 ',
          initial_mode = 'insert',
          layout_strategy = 'horizontal',
          sorting_strategy = 'descending',
        },
        pickers = {
          find_files = {
            prompt_title = '查找文件',
            hidden = true,
          },
          live_grep = {
            prompt_title = '全局搜索内容',
          },
          buffers = {
            prompt_title = '切换缓冲区',
          },
          help_tags = {
            prompt_title = '搜索帮助文档',
          },
          oldfiles = {
            prompt_title = '最近打开的文件',
          },
          git_status = {
            prompt_title = 'Git 状态',
          },
          git_commits = {
            prompt_title = 'Git 提交历史',
          },
          keymaps = {
            prompt_title = '搜索快捷键',
          },
          diagnostics = {
            prompt_title = '诊断信息',
          },
          find_command = {
            prompt_title = '查找命令',
          },
          marks = {
            prompt_title = '跳转标记',
          },
        },
        mappings = {
          i = {
            ['<C-n>'] = false,
            ['<C-p>'] = false,
          },
        },
      })
    end,
  },

  -- ----------------------------------------------------------
  -- which-key：快捷键提示（中文）
  -- ----------------------------------------------------------
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    config = function()
      require('which-key').setup({
        preset = 'helix',
        delay = 300,
        icons = {
          breadcrumb = '»',
          separator = '➜',
          group = '+',
        },
        win = {
          border = 'rounded',
        },
        layout = {
          height = { min = 4, max = 25 },
          width = { min = 20, max = 50 },
          spacing = 3,
          align = 'left',
        },
        spec = {
          { '<leader>f', group = '文件' },
          { '<leader>g', group = 'Git' },
          { '<leader>l', group = 'LSP 语言服务' },
          { '<leader>d', group = '调试' },
          { '<leader>b', group = '缓冲区' },
          { '<leader>t', group = '终端' },
          { '<leader>x', group = '问题面板' },
          { '<leader>w', group = '窗口' },
          { '<leader>q', group = '退出/保存' },
          { '<leader>c', group = '编译/任务' },
        },
      })
    end,
  },
}
