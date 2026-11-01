-- ============================================================
-- DAP 调试配置
-- 支持：Rust / C / C++（codelldb）、Go（dlv）、Python（debugpy）
-- ------------------------------------------------------------
-- 调试器安装：
--   Rust/C/C++  -> 需要 codelldb
--   Go          -> 需要 dlv (Delve)
--   Python      -> 需要 debugpy
-- 全部通过 mason 管理，见 plugins/mason.lua
-- ============================================================

local M = {}

function M.setup()
  -- 幂等：可能被插件 config 和 VimEnter 兜底各调用一次
  if M._done then
    return
  end
  M._done = true

  local dap = require('dap')
  local dapui = require('dapui')

  dapui.setup({
    layouts = {
      {
        elements = {
          { id = 'scopes', size = 0.33 },
          { id = 'breakpoints', size = 0.17 },
          { id = 'stacks', size = 0.25 },
          { id = 'watches', size = 0.25 },
        },
        -- 新版 dapui 的 size 必须是数字（列数，或 0~1 的比例），
        -- 传 { width = ..., height = ... } 会报 "size: expected number, got table"
        size = 0.40,
        position = 'right',
      },
      {
        elements = {
          { id = 'repl', size = 0.5 },
          { id = 'console', size = 0.5 },
        },
        size = 0.25,
        position = 'bottom',
      },
    },
    floating = {
      max_height = 0.9,
      max_width = 0.5,
      border = 'rounded',
    },
  })

  -- 自动打开/关闭调试 UI
  dap.listeners.after.event_initialized['dapui_config'] = function()
    dapui.open()
  end
  dap.listeners.before.event_terminated['dapui_config'] = function()
    dapui.close()
  end
  dap.listeners.before.event_exited['dapui_config'] = function()
    dapui.close()
  end

  -- 断点图标
  local signs = { Breakpoint = '●', Condition = '⦁' }
  for name, icon in pairs(signs) do
    vim.fn.sign_define('DapBreakpoint', { text = icon, texthl = 'DiagnosticSignError' })
    vim.fn.sign_define('DapStopped', { text = '▶', texthl = 'DiagnosticSignWarn', linehl = 'Visual' })
  end

  -- ----------------------------------------------------------
  -- Rust / C / C++：codelldb
  -- ----------------------------------------------------------
  -- codelldb 由 mason 安装到 mason/bin，需定位其真实路径
  -- 使用统一解析器，跳过失效的 rustup/cargo shim
  local paths = require('core.paths')
  local codelldb_path = paths.resolve('codelldb')
  if codelldb_path == 'codelldb' then
    codelldb_path = ''
  end

  if codelldb_path ~= '' then
    -- 注册 codelldb 适配器（server 模式，nvim-dap 启动时动态分配端口）
    dap.adapters.codelldb = {
      type = 'server',
      port = '${port}',
      executable = {
        command = codelldb_path,
        args = { '--port', '${port}' },
      },
    }

    -- C/C++ 的可执行文件推断：${file} 指向源文件，直接拿来调试会失败，
    -- 这里按常见布局依次尝试：同目录同名无扩展名 -> a.out -> main -> build/
    local function guess_executable()
      local dir = vim.fn.expand('%:p:h')
      local stem = vim.fn.expand('%:t:r')
      local candidates = {
        dir .. '/' .. stem,
        dir .. '/a.out',
        dir .. '/main',
        dir .. '/build/' .. stem,
        dir .. '/build/main',
      }
      for _, c in ipairs(candidates) do
        if vim.fn.executable(c) == 1 then
          return c
        end
      end
      -- 都没找到：让用户手填（带默认值提示）
      return vim.fn.input('可执行文件路径: ', dir .. '/', 'file')
    end

    -- ------------------------------------------------------
    -- 配置必须按 filetype 注册
    -- ------------------------------------------------------
    -- nvim-dap 在按 F5 时查找的是 dap.configurations[当前缓冲区filetype]，
    -- 例如 dap.configurations.rust。写成 dap.configurations.codelldb
    -- （codelldb 是适配器名，不是 filetype）会导致找不到配置、
    -- 按 F5 毫无反应 —— 这是「手动 dap.run(cfg) 能跑、按 F5 不行」的根因。
    local attach_cfg = {
      type = 'codelldb',
      request = 'attach',
      name = '附加到进程 (codelldb)',
      program = '${file}',
      pid = '${command:pickProcess}',
      MIMode = 'lldb',
    }

    -- C
    dap.configurations.c = {
      {
        type = 'codelldb',
        request = 'launch',
        name = '调试 C (当前文件)',
        program = guess_executable,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
        -- 用调试器自己的控制台，而不是请求外部终端。
        -- codelldb 默认会发 runInTerminal 请求把程序丢到外部终端，
        -- 那样调试器只能「附加」，断点会失效（实测：断点 verified 但不命中）。
        terminal = 'console',
        MIMode = 'lldb',
        -- 注意：不要写 args = {} / env = {}。
        -- Lua 的空表会被 JSON 编码成 []（数组），而 codelldb 期望 map，
        -- 会报 "invalid type: sequence, expected a map"。省略即表示空。
      },
      vim.deepcopy(attach_cfg),
    }

    -- C++
    dap.configurations.cpp = {
      {
        type = 'codelldb',
        request = 'launch',
        name = '调试 C++ (当前文件)',
        program = guess_executable,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
        terminal = 'console',
        MIMode = 'lldb',
      },
      vim.deepcopy(attach_cfg),
    }

    -- Rust（program 会在 dap.run 包装里按 Cargo 包名校正 + 自动 cargo build）
    dap.configurations.rust = {
      {
        type = 'codelldb',
        request = 'launch',
        name = '调试 Rust (codelldb)',
        program = '${workspaceFolder}/target/debug/${fileBasenameNoExtension}',
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
        terminal = 'console',
        MIMode = 'lldb',
      },
      vim.deepcopy(attach_cfg),
    }
  else
    -- 未安装 codelldb 时给出明确提示（不阻断其他调试功能）
    vim.schedule(function()
      vim.notify(
        '未检测到 codelldb，C/C++/Rust 调试不可用。安装命令: :MasonInstall codelldb',
        vim.log.levels.WARN
      )
    end)
  end

  -- ----------------------------------------------------------
  -- Go：Delve
  -- ----------------------------------------------------------
  local dlv_ok = vim.fn.executable('dlv') == 1
  if dlv_ok then
    dap.configurations.go = {
      {
        type = 'go',
        request = 'launch',
        name = '调试 Go (当前文件)',
        program = '${file}',
        cwd = '${workspaceFolder}',
      },
      {
        type = 'go',
        request = 'debug',
        name = '调试 Go 测试',
        program = '${file}',
        cwd = '${workspaceFolder}',
      },
      {
        type = 'go',
        request = 'attach',
        name = '附加到 Go 进程',
        program = '${file}',
        mode = 'local',
        processId = '${command:pickProcess}',
        cwd = '${workspaceFolder}',
      },
    }
  end

  -- ----------------------------------------------------------
  -- Python：debugpy
  -- 说明：适配器与解释器的实际注册在 plugins/dap.lua 中完成
  --（dap-python 插件会覆盖此处，此处只保证配置项存在）
  -- ----------------------------------------------------------
  local function resolve_python()
    local venv = os.getenv('VIRTUAL_ENV')
    if venv then
      local py = venv .. '/bin/python'
      if vim.fn.filereadable(py) == 1 then
        return py
      end
    end
    for _, name in ipairs({ 'python3', 'python' }) do
      local path = vim.fn.exepath(name)
      if path ~= '' then
        local r = vim.fn.system({ path, '-c', 'import debugpy' })
        if vim.v.shell_error == 0 then
          return path
        end
      end
    end
    return 'python3'
  end

  dap.configurations.python = {
    {
      type = 'debugpy',
      request = 'launch',
      name = '调试 Python (当前文件)',
      program = '${file}',
      pythonPath = resolve_python(),
      cwd = '${workspaceFolder}',
    },
    {
      type = 'debugpy',
      request = 'launch',
      name = '调试 Python (模块模式)',
      module = 'main',
      pythonPath = resolve_python(),
      cwd = '${workspaceFolder}',
    },
    {
      type = 'debugpy',
      request = 'attach',
      name = '附加到 Python 进程',
      program = '${file}',
      pythonPath = resolve_python(),
      pid = '${command:pickProcess}',
    },
  }
  -- 注意：此处不覆盖 dap.adapters.debugpy —— dap-python 注册的函数式适配器
  -- 内部含 enrich_config（负责补全 pythonPath），覆盖会丢失该逻辑。
  -- 实测：适配器必须保持 dap-python 的原始实现。

  -- ----------------------------------------------------------
  -- Rust 调试前置：自动编译 + 修正二进制名
  -- ------------------------------------------------------------
  -- Rust 的 codelldb 配置依赖 target/debug/ 下已存在可执行文件，
  -- 且二进制名默认等于 Cargo 包名（未必等于源文件名），
  -- 这里在启动调试前自动完成编译并校正 program。
  local function cargo_package_name(root)
    local toml = vim.fn.filereadable(root .. '/Cargo.toml') == 1
      and root .. '/Cargo.toml'
      or nil
    if not toml then
      return nil
    end
    local content = table.concat(vim.fn.readfile(toml), '\n')
    -- 取 [package] 段内的 name = "xxx"
    local pkg = content:match('%[package%](.-)%[')
    local name = (pkg or content):match('name%s*=%s*"([^"]+)"')
    return name
  end

  local orig_run = dap.run
  dap.run = function(config)
    if type(config) ~= 'table' then
      return orig_run(config)
    end

    -- 复制一份，避免修改 configurations 里的原始表（下次选同一配置会受影响）
    config = vim.deepcopy(config)

    -- 1) 函数型 program 提前求值
    -- 实测：program 为函数时，在协程中 dap.run 会出现「会话已建立但
    -- initialized 不触发」的现象（表现为按 F5 后毫无反应）。
    -- 提前求值成字符串可稳定工作。
    if type(config.program) == 'function' then
      config.program = config.program()
    end

    -- 2) Rust：调试前自动编译 + 校正二进制名
    if config.type == 'codelldb' and config.name and config.name:find('Rust') then
      local root = vim.fs.root(0, { 'Cargo.toml' })
      if root then
        -- 校正程序路径为 Cargo 包名
        local pkg_name = cargo_package_name(root)
        if pkg_name and pkg_name ~= '' then
          config.program = root .. '/target/debug/' .. pkg_name
        end
        -- 编译
        vim.notify('正在编译 Rust 项目...')
        local res = vim.system({ 'cargo', 'build' }, {
          cwd = root,
          text = true,
        }):wait()
        if res.code ~= 0 then
          vim.notify('Rust 编译失败，已取消调试', vim.log.levels.ERROR)
          return
        end
        vim.notify('Rust 编译完成，开始调试')
      end
    end

    return orig_run(config)
  end

  -- ----------------------------------------------------------
  -- 通用快捷键
  -- ----------------------------------------------------------
  -- 说明：新版 nvim-dap 移除了 set_conditional_breakpoint /
  -- set_breakpoint_condition，dapui 移除了 clear / toggle_repl。
  -- 这里加一层类型检查，遇到不存在的 API 就跳过，避免
  -- "rhs: expected string|function, got nil" 中断整个 setup。
  local map = function(mode, lhs, rhs, desc)
    if type(rhs) ~= 'function' and type(rhs) ~= 'string' then
      return
    end
    vim.keymap.set(mode, lhs, rhs, { desc = desc })
  end

  -- 条件断点：新版用 set_breakpoint 的第一个参数传条件
  local set_cond_breakpoint = function()
    local cond = vim.fn.input('断点条件（留空则无条件）: ')
    dap.set_breakpoint(cond ~= '' and cond or nil)
  end

  map('n', '<F5>', dap.continue, '调试：继续/启动')
  map('n', '<F10>', dap.step_over, '调试：单步跳过')
  map('n', '<F11>', dap.step_into, '调试：单步进入')
  map('n', '<F12>', dap.step_out, '调试：单步跳出')
  map('n', '<leader>db', dap.toggle_breakpoint, '调试：切换断点')
  map('n', '<leader>dB', set_cond_breakpoint, '调试：条件断点')
  map('n', '<leader>du', dapui.toggle, '调试：切换调试面板')
  map('n', '<leader>dr', dap.run_last, '调试：用上次配置重新运行')
  map('n', '<leader>dc', dap.disconnect, '调试：断开连接')
  map('n', '<leader>de', dap.terminate, '调试：终止')
  map('n', '<leader>dl', function()
    dap.continue()
  end, '调试：启动并自动聚焦源码')
  map('n', '<leader>di', dapui.eval, '调试：求值 (表达式)')
  map('n', '<leader>dw', function()
    dapui.float_element('repl')
  end, '调试：浮动打开调试命令窗口')
  map('n', '<leader>dpa', set_cond_breakpoint, '调试：为光标行设置条件断点')
  map('n', '<leader>dpl', dap.list_breakpoints, '调试：列出所有断点')
  map('n', '<leader>dq', dapui.close, '调试：关闭调试面板')

  -- 插入模式下也能触发
  vim.keymap.set('i', '<F5>', function()
    vim.cmd('stopinsert')
    dap.continue()
  end, { desc = '调试：继续/启动' })
end

return M
