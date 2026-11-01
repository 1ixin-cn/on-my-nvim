-- ============================================================
-- DAP 调试插件组
-- nvim-dap 为核心，codelldb / delve / debugpy 为各语言调试器
-- ============================================================

return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'rcarriga/nvim-dap-ui',
      'nvim-neotest/nvim-nio',
      'mfussenegger/nvim-dap-python',
      'leoluz/nvim-dap-go',
      'theHamsta/nvim-dap-virtual-text',
    },
    cmd = { 'DapContinue', 'DapToggleBreakpoint', 'DapEval' },
    -- 说明：这里不再用 init 注册 <F5> 等键位。
    -- init 里的键位是字符串形式（<cmd>DapContinue<CR>），会在插件加载
    -- 之后覆盖 core/dap.lua 用函数注册的键位；一旦上游命令改名，
    -- 快捷键就会静默失效。全部键位统一在 core/dap.lua 中注册。
    config = function()
      require('core.dap').setup()
    end,
  },

  -- ----------------------------------------------------------
  -- 调试时在源码上方显示变量值（类 IDE 体验）
  -- ----------------------------------------------------------
  {
    'theHamsta/nvim-dap-virtual-text',
    dependencies = { 'mfussenegger/nvim-dap' },
    config = function()
      require('nvim-dap-virtual-text').setup({
        -- 调试时显示当前行附近的变量值
        enabled = true,
        -- 只在调试暂停时显示
        debug_only = true,
      })
    end,
  },

  -- ----------------------------------------------------------
  -- DAP 适配器：Python（debugpy）
  -- ----------------------------------------------------------
  {
    'mfussenegger/nvim-dap-python',
    dependencies = { 'mfussenegger/nvim-dap' },
    config = function()
      -- 使用 mason 提供的独立 debugpy-adapter 脚本（最可靠）
      local adapter = vim.fn.stdpath('data') .. '/mason/bin/debugpy-adapter'
      if vim.fn.filereadable(adapter) ~= 1 then
        adapter = vim.fn.exepath('debugpy-adapter')
      end

      -- 解析能导入 debugpy 的解释器（用于运行被调试程序）
      local python = 'python3'
      for _, name in ipairs({ 'python3', 'python' }) do
        local path = vim.fn.exepath(name)
        if path ~= '' then
          local r = vim.fn.system({ path, '-c', 'import debugpy' })
          if vim.v.shell_error == 0 then
            python = path
            break
          end
        end
      end

      require('dap-python').setup(python)

      -- dap-python 注册的适配器是函数，会在 enrich_config 里补全 pythonPath。
      -- 这里不应覆盖它（否则会丢失 enrich_config 的处理逻辑），
      -- 只需保证配置使用绝对解释器路径与 debugpy 类型。
      local dap = require('dap')
      local zh_names = {
        ['file'] = '调试 Python (当前文件)',
        ['file:args'] = '调试 Python (带参数)',
        ['attach'] = '附加到 Python 进程',
        ['file:doctest'] = '调试 Python 文档测试',
      }
      for _, c in ipairs(dap.configurations.python or {}) do
        c.type = 'debugpy'
        c.pythonPath = python
        c.name = zh_names[c.name] or c.name
      end
    end,
  },

  -- ----------------------------------------------------------
  -- DAP 适配器：Go（Delve）
  -- ----------------------------------------------------------
  {
    'leoluz/nvim-dap-go',
    dependencies = { 'mfussenegger/nvim-dap' },
    config = function()
      require('dap-go').setup()
      -- 配置名汉化
      local dap = require('dap')
      local zh_names = {
        ['Debug'] = '调试 (当前文件)',
        ['Debug (Arguments)'] = '调试 (带参数)',
        ['Debug (Arguments & Build Flags)'] = '调试 (参数与构建标志)',
        ['Debug Package'] = '调试整个包',
        ['Attach'] = '附加到进程',
        ['Debug test'] = '调试测试',
        ['Debug test (go.mod)'] = '调试测试 (go.mod)',
        ['Debug (Delve)'] = '调试 (Delve)',
      }
      for _, list in pairs(dap.configurations) do
        for _, c in ipairs(list) do
          if c.name then
            c.name = zh_names[c.name] or c.name
          end
        end
      end
    end,
  },

  -- ----------------------------------------------------------
  -- 说明：codelldb 适配器已合并到 core/dap.lua 中注册
  -- （那里同时解析 codelldb 二进制路径）。
  -- 此处不再单独声明一个 nvim-dap 条目 —— 给同一插件起不同 name
  -- 会让 lazy 在 lazy/ 下生成第二个目录（如 dap-codelldb-adapter），
  -- 与 nvim-dap 并存，导致 require('dap') 加载到哪份不确定。
  -- ----------------------------------------------------------
}
