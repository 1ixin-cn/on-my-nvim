-- ============================================================
-- 任务系统：阶段编译 / 实时编译
-- 设计：
--   1) 根据当前文件类型 & 项目根目录，推断可用的构建命令
--   2) 阶段化：检查 -> 构建 -> 测试 -> 运行，各阶段独立可执行
--   3) 实时：保存时自动执行"轻量检查"，结果汇入 Trouble 面板
--   4) 输出解析：把编译器报错转成 Trouble 诊断，支持点击跳转
-- ============================================================

local M = {}

M.tasks = {}       -- 当前项目的任务表
M.root = nil       -- 项目根目录
M.ft = nil         -- 当前文件类型

-- ------------------------------------------------------------
-- 解析项目根目录
-- ------------------------------------------------------------
local function find_root()
  -- 优先 git 根
  local git_root = vim.fn.systemlist({ 'git', '-C', vim.fn.getcwd(), 'rev-parse', '--show-toplevel' })
  if vim.v.shell_error == 0 and git_root[1] ~= '' then
    return git_root[1]
  end
  -- 各语言的标志文件
  local markers = {
    'Cargo.toml', 'go.mod', 'package.json', 'pyproject.toml', 'setup.py',
    'CMakeLists.txt', 'Makefile', 'meson.build', 'requirements.txt',
  }
  local cwd = vim.fn.getcwd()
  for _, m in ipairs(markers) do
    if vim.fn.filereadable(cwd .. '/' .. m) == 1 then
      return cwd
    end
  end
  return cwd
end

-- ------------------------------------------------------------
-- 构建命令推断（按语言）
-- ------------------------------------------------------------
local function detect_tasks(ft, root)
  local tasks = {}

  if ft == 'rust' then
    tasks.check = {
      name = 'Rust 检查 (cargo check)',
      cmd = { 'cargo', 'check', '--message-format', 'short' },
      root = root,
    }
    tasks.build = {
      name = 'Rust 构建 (cargo build)',
      cmd = { 'cargo', 'build' },
      root = root,
    }
    tasks.run = {
      name = 'Rust 运行 (cargo run)',
      cmd = { 'cargo', 'run' },
      root = root,
    }
    tasks.test = {
      name = 'Rust 测试 (cargo test)',
      cmd = { 'cargo', 'test' },
      root = root,
    }
    tasks.check.extra = { 'cargo', 'clippy', '--message-format', 'short' }

  elseif ft == 'go' then
    tasks.check = {
      name = 'Go 检查 (go vet)',
      -- 实时检查只针对当前包，避免扫描整个项目
      cmd = { 'go', 'vet', '.' },
      root = root,
    }
    tasks.build = {
      name = 'Go 构建 (go build)',
      cmd = { 'go', 'build', './...' },
      root = root,
    }
    tasks.run = {
      name = 'Go 运行 (go run 当前文件)',
      cmd = { 'go', 'run', vim.fn.expand('%:t') },
      root = root,
      dynamic = true,
    }
    tasks.test = {
      name = 'Go 测试 (go test)',
      cmd = { 'go', 'test', './...' },
      root = root,
    }

  elseif ft == 'python' then
    tasks.check = {
      name = 'Python 检查 (ruff + pyright)',
      cmd = { 'ruff', 'check', '.' },
      root = root,
    }
    tasks.build = {
      name = 'Python 编译检查 (compileall)',
      cmd = { 'python3', '-m', 'compileall', '-q', '.' },
      root = root,
    }
    tasks.run = {
      name = 'Python 运行 (当前文件)',
      cmd = { 'python3', vim.fn.expand('%:t') },
      root = root,
      dynamic = true,
    }
    tasks.test = {
      name = 'Python 测试 (pytest)',
      cmd = { 'pytest', '-q' },
      root = root,
    }

  elseif ft == 'c' or ft == 'cpp' then
    tasks.check = {
      name = 'C/C++ 语法检查 (clang++ -fsyntax-only)',
      cmd = { 'clang++', '-fsyntax-only', '-std=c++17', vim.fn.expand('%:t') },
      root = root,
      dynamic = true,
    }
    tasks.build = {
      name = 'C/C++ 构建 (make)',
      cmd = { 'make' },
      root = root,
    }
    tasks.run = {
      name = 'C/C++ 运行',
      cmd = { 'make', 'run' },
      root = root,
    }
    tasks.test = {
      name = 'C/C++ 测试 (make test)',
      cmd = { 'make', 'test' },
      root = root,
    }

  elseif ft == 'lua' then
    tasks.check = {
      name = 'Lua 检查 (luacheck)',
      cmd = { 'luacheck', '.' },
      root = root,
    }
  end

  -- Makefile 项目：优先使用 make 目标
  if vim.fn.filereadable(root .. '/Makefile') == 1 and not tasks.build then
    tasks.build = { name = 'Make 构建', cmd = { 'make' }, root = root }
  end

  return tasks
end

-- ------------------------------------------------------------
-- 解析编译输出为诊断
-- 格式：
--   file.go:12:5: undefined: foo
--   src/main.rs:12:5: error[E0308]: mismatched types
--   file.py:12:5: error: something
-- ------------------------------------------------------------
local function parse_output(output)
  local diagnostics = {}
  for _, line in ipairs(output) do
    -- 匹配 file:line:col: message
    local file, lnum, col, msg =
      line:match('^(.-):(%d+):(%d+):%s*[-:]?%s*(.+)$')
    if not file then
      file, lnum, msg = line:match('^(.-):(%d+):%s*[-:]?%s*(.+)$')
      col = 1
    end
    if file and lnum then
      -- 清理前缀：go vet 输出形如 "vet: ./main.go:6:10: ..." 或 "# package"
      file = file:gsub('^vet:%s*', '')
      file = file:gsub('^#%s*', '')
      file = file:gsub('^%./', '')
      -- 跳过非文件路径（如 package 名）
      if file:find('/') or file:match('%.%w+$') then
        local severity = vim.diagnostic.severity.INFO
        local text = msg
        local m = msg:lower()
        if m:find('error') or m:find('undefined') or m:find('cannot') or m:find('mismatch')
          or m:find('not assignable') or m:find('undeclared') or m:find('too many') then
          severity = vim.diagnostic.severity.ERROR
        elseif m:find('warning') or m:find('deprecated') or m:find('unused') or m:find('should') then
          severity = vim.diagnostic.severity.WARN
        end
        -- 去掉行内的 error:/warning: 前缀
        text = text:gsub('^error[%[%w]*%]:?%s*', ''):gsub('^warning:%s*', '')

        -- 汉化编译诊断（引号内代码片段保持原样）
        local ok_i18n, i18n = pcall(require, 'core.i18n')
        if ok_i18n then
          text = i18n.translate_diagnostic(text)
        end

        table.insert(diagnostics, {
          filename = vim.fn.fnamemodify(file, ':p'),
          -- 行号/列号必须转成 0-based：编译器输出是 1-based（main.rs:2:9），
          -- 而 vim.diagnostic 的 lnum/col 都是 0-based。不转换会有两个后果：
          --   ① 诊断标记画在错误行的下一行，看起来「错位」；
          --   ② 与 LSP 诊断（0-based）行号永远差 1，导致后面的去重逻辑
          --      一次都不会命中，Trouble 里同一个错误重复显示。
          lnum = math.max(tonumber(lnum) - 1, 0),
          col = math.max(tonumber(col or 1) - 1, 0),
          message = text,
          severity = severity,
          source = '编译',
        })
      end
    end
  end
  return diagnostics
end

-- ------------------------------------------------------------
-- 执行任务
-- ------------------------------------------------------------
function M.run(task_key, opts)
  opts = opts or {}
  local task = M.tasks[task_key]
  if not task then
    vim.notify('未找到任务: ' .. tostring(task_key), vim.log.levels.WARN)
    return
  end

  local cmd = vim.deepcopy(task.cmd)
  -- 动态命令：重新展开当前文件名
  if task.dynamic then
    for i, v in ipairs(cmd) do
      if v == vim.fn.expand('%:t') then
        cmd[i] = vim.fn.expand('%:t')
      end
    end
  end

  local root = task.root or M.root or vim.fn.getcwd()

  local result = vim.system(cmd, {
    cwd = root,
    text = true,
    env = vim.env,
  }, function(res)
    vim.schedule(function()
      -- text = true 时 stdout/stderr 为字符串，需按行拆分
      local output = {}
      local function add_lines(str)
        if type(str) == 'string' and str ~= '' then
          for line in str:gmatch('[^\r\n]+') do
            table.insert(output, line)
          end
        end
      end
      add_lines(res.stdout)
      add_lines(res.stderr)

      local ok = res.code == 0
      local diags = parse_output(output)

      -- 写入 vim.diagnostic（Trouble 会自动同步显示）
      -- 使用独立命名空间，避免与 LSP 诊断互相覆盖
      local ns = vim.api.nvim_create_namespace('build')
      vim.diagnostic.reset(ns)
      if #diags > 0 then
        -- 按文件分组，逐个 buffer 设置（0.13 的 diagnostic.set 签名为
        -- set(namespace, bufnr, diagnostics, opts)）
        local by_file = {}
        for _, d in ipairs(diags) do
          by_file[d.filename] = by_file[d.filename] or {}
          table.insert(by_file[d.filename], {
            lnum = d.lnum,
            col = d.col,
            message = d.message,
            severity = d.severity,
            source = d.source,
          })
        end
        for filename, list in pairs(by_file) do
          local buf = vim.fn.bufadd(filename)
          if vim.fn.bufloaded(buf) == 0 then
            vim.fn.bufload(buf)
          end
          -- 去重：若 LSP 已在同一行报告过错误，就不再重复展示编译器的
          -- 同一处问题（否则 Trouble 里同一个 E0308 会显示三次）
          local filtered = {}
          for _, item in ipairs(list) do
            local dup = false
            for _, e in ipairs(vim.diagnostic.get(buf, { lnum = item.lnum })) do
              if e.source ~= '编译' and e.severity == item.severity then
                dup = true
                break
              end
            end
            if not dup then
              table.insert(filtered, item)
            end
          end
          if #filtered > 0 then
            pcall(vim.diagnostic.set, ns, buf, filtered)
          end
        end
      end

      -- 失败时弹出并聚焦 Trouble，让错误立刻可见；成功时不打扰。
      -- 注意：quiet 模式（保存触发的实时编译）必须完全静默 ——
      -- 本配置的自动保存挂在 TextChanged 上，每敲几个字就会保存一次，
      -- 如果这时弹面板抢焦点，光标会被反复拽走，根本没法写代码。
      -- 实时编译的结果已经以行内标记/虚拟文本的形式呈现，不需要弹窗。
      local quiet = opts.quiet == true
      if not quiet and not ok then
        local ok_trouble, trouble = pcall(require, 'trouble')
        if ok_trouble and type(trouble.open) == 'function' then
          pcall(trouble.open, 'diagnostics', { focus = true })
        end
      end

      if not quiet then
        if ok then
          vim.notify(('%s ✅ 成功'):format(task.name), vim.log.levels.INFO)
        else
          vim.notify(
            ('%s ❌ 失败（退出码 %d），%d 条诊断 —— 详情见下方「诊断」面板'):format(
              task.name, res.code, #diags
            ),
            vim.log.levels.ERROR
          )
        end
      end

      if opts.on_done then
        opts.on_done(ok, diags, output)
      end
    end)
  end)

  return result
end

-- ------------------------------------------------------------
-- 实时编译：保存时触发轻量检查
-- ------------------------------------------------------------
-- 防抖：同一文件 1.5 秒内的多次保存只检查一次，避免连续保存时反复编译
local last_check = {}

function M.setup_realtime()
  local group = vim.api.nvim_create_augroup('RealtimeCompile', { clear = true })

  vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
    group = group,
    callback = function(ev)
      -- 只在文件类型受支持且开启了实时编译时触发
      if not vim.g.realtime_compile then
        return
      end
      local ft = vim.bo[ev.buf].filetype
      local supported = { python = true, go = true, rust = true, c = true, cpp = true, lua = true }
      if not supported[ft] then
        return
      end
      -- 编译进行中不重复触发
      if vim.g.compiling_now then
        return
      end
      -- 防抖：同文件 1.5 秒内只检查一次
      local fname = vim.fn.expand('%:p')
      local now = vim.loop.now()
      if last_check[fname] and (now - last_check[fname]) < 1500 then
        return
      end
      last_check[fname] = now
      M.refresh_tasks()
      if M.tasks.check then
        M.run('check', { quiet = true })
      end
    end,
  })
end

-- ------------------------------------------------------------
-- 刷新任务（切换文件/目录时）
-- ------------------------------------------------------------
function M.refresh_tasks()
  local ft = vim.bo.filetype
  local root = find_root()
  if ft ~= M.ft or root ~= M.root then
    M.ft = ft
    M.root = root
    M.tasks = detect_tasks(ft, root)
  end
  return M.tasks
end

-- ------------------------------------------------------------
-- 列出可用任务（用于选择菜单）
-- ------------------------------------------------------------
function M.list()
  M.refresh_tasks()
  local names = {}
  for k, v in pairs(M.tasks) do
    table.insert(names, { k, v.name })
  end
  table.sort(names, function(a, b)
    return a[1] < b[1]
  end)
  return names
end

function M.setup()
  M.refresh_tasks()
  M.setup_realtime()
end

return M
