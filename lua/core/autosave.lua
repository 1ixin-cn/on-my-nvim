-- ============================================================
-- 自动保存 / 防丢文件
-- ------------------------------------------------------------
-- 五道保险，从最常触发到最后兜底：
--   1. 事件   离开插入 / 改动文本 / 失焦 / 换 buffer / 停手 250ms
--   2. 定时   每 5 秒扫一遍（g:autosave_interval 可调）
--   3. 退出   VimLeavePre + VimLeave
--   4. 信号   SIGHUP / SIGTERM / SIGQUIT（SIGINT 只存不退）
--   5. 交换文件   kill -9 / 断电时的最后手段（另见 SwapExists 处理）
-- ============================================================

local augroup = vim.api.nvim_create_augroup('UserAutoSave', { clear = true })

-- libuv 的 handle（定时器 / 信号）一旦被 GC 回收就会失效，
-- 必须由 Lua 侧持有引用，否则定时器不跑、信号监听静默失效。
local keepalive = {}

-- 统一的保存函数：仅在有改动、且是真实文件（非终端/无名字）时保存
local function safe_write(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local bo = vim.bo[buf]
  if not bo.modifiable or not bo.buflisted or bo.buftype ~= '' then
    return
  end
  if vim.fn.bufname(buf) == '' then
    return
  end
  vim.api.nvim_buf_call(buf, function()
    -- noautocmd 是刻意的：conform 的 format_on_save 挂在 BufWritePre 上，
    -- 若自动保存走完整事件链，停手 250ms / 每 5 秒就会格式化一次，
    -- 打字打到一半被重排（rustfmt 还可能因为代码不完整直接失败）。
    -- 想让某个文件格式化，手动 :w 即可（那条路径不带 noautocmd）。
    vim.cmd('silent! noautocmd update')
  end)
end

-- 触发时机：插入模式离开、文本变化、窗口失焦、停止输入 250ms、
--          插入模式下停手 250ms、离开缓冲区
vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged', 'FocusLost', 'CursorHold', 'CursorHoldI', 'BufLeave' }, {
  group = augroup,
  callback = function(ev)
    safe_write(ev.buf)
  end,
})

-- 保存所有已修改的真实文件，返回实际保存个数
local function save_all_modified()
  local n = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
      pcall(safe_write, buf)
      n = n + 1
    end
  end
  return n
end

-- ============================================================
-- 定时兜底保存：每 N 秒把所有已修改的 buffer 落一次盘
-- ------------------------------------------------------------
-- 事件驱动（CursorHoldI / InsertLeave / CursorHold …）已经覆盖绝大多数情况，
-- 但它依赖事件真的能触发。以下场景事件会漏：
--   · 宏回放 / 大批量 :normal 操作全程不给空闲时间
--   · 插入模式下一直有键在队列里（自动补全、长粘贴）
--   · 某个插件用 clear=true 建了同名 augroup，把规则清掉（真实踩过）
-- 定时器不依赖任何事件，是最后一道保险。
--
-- 间隔默认 5 秒，可改：:let g:autosave_interval = 3000
-- 只写"已修改且有文件名"的 buffer，没改动时是空转（不产生磁盘 IO）。
-- ============================================================
do
  local timer = (vim.uv or vim.loop).new_timer()
  local interval = tonumber(vim.g.autosave_interval) or 5000
  if timer and interval and interval > 0 then
    timer:start(interval, interval, function()
      -- timer 回调是 fast context，不能直接调 vim.api
      vim.schedule(function()
        save_all_modified()
      end)
    end)
    keepalive[#keepalive + 1] = timer
  end
end

-- 退出前：保存所有已修改的 buffer（防止 :qa 时丢失）
vim.api.nvim_create_autocmd('VimLeavePre', {
  group = augroup,
  callback = function()
    save_all_modified()
  end,
})

-- 意外退出（SIGTERM/SIGHUP）时保存
vim.api.nvim_create_autocmd('VimLeave', {
  group = augroup,
  callback = function()
    pcall(function()
      vim.cmd('silent! wall')
    end)
  end,
})

-- ============================================================
-- 信号兜底：终端被直接关掉 / 被 kill / Ctrl+C
-- ------------------------------------------------------------
-- VimLeavePre / VimLeave 只在**正常退出**时触发。下面这些情况不会经过它们：
--   · 关掉终端窗口 / 关掉 tmux 会话   → 进程收到 SIGHUP
--   · kill <pid>、系统关机、Activity Monitor 结束进程 → SIGTERM
--   · kill -QUIT                      → SIGQUIT
-- 所以这里用 libuv 接管这几个信号，先落盘再退。
--
-- 唯一救不了的是 SIGKILL（kill -9、强制关机、panic）：信号无法被捕获，
-- 只能靠 swapfile 在下次打开文件时恢复（:browse recover / nvim -r 文件名）。
-- ============================================================
local uv = vim.uv or vim.loop

local in_handler = false

local function on_signal(quit)
  if in_handler then
    return
  end
  in_handler = true

  -- 注意：uv 回调运行在 "fast event" 上下文，里面 **不能** 调用 vim.cmd /
  -- vim.api（会被静默拒绝，写盘直接失效），必须 vim.schedule 到主循环。
  vim.schedule(function()
    save_all_modified()
    pcall(function()
      require('persistence').save()
    end)
    if quit then
      -- qa! 会再触发一遍 VimLeavePre/VimLeave；已保存过就不会重复写盘。
      pcall(function()
        vim.cmd('silent! qa!')
      end)
    else
      -- 只存不退（SIGINT）：解除锁定，否则后面真收到 SIGTERM 会被 in_handler 吞掉。
      in_handler = false
    end
  end)

  if not quit then
    return
  end

  -- 兜底：3 秒还没退干净（写盘卡住、磁盘满、弹了对话框）就硬退，
  -- 否则信号被接管后 nvim 会一直挂在那里变成僵尸窗口。
  local timer = uv.new_timer()
  if timer then
    timer:start(3000, 0, function()
      timer:stop()
      timer:close()
      os.exit(0)
    end)
  end
end

local function watch(signame, quit)
  pcall(function()
    local h = uv.new_signal()
    if not h then
      return
    end
    h:start(signame, function()
      on_signal(quit)
    end)
    keepalive[#keepalive + 1] = h
  end)
end

-- SIGHUP：关掉终端窗口 / 关掉 tmux 会话（最常见的一种"直接关终端"）
-- SIGTERM：kill <pid>、系统关机、Activity Monitor 结束进程
-- SIGQUIT：Ctrl+\ / kill -QUIT
-- 这三种都意味着"进程要没了"，保存后退出。
for _, sig in ipairs({ 'sighup', 'sigterm', 'sigquit' }) do
  watch(sig, true)
end

-- SIGINT（Ctrl+C）：只保存、不退出。
-- 不顺势退出的原因：执行 `:!cmd` 外部命令时 Ctrl+C 也会发 SIGINT，
-- 若就此退出会把你正在用的整个编辑器杀掉。而 TUI 下按 Ctrl+C 只是把
-- 0x03 字节交给 nvim 当中断键，根本不会产生 SIGINT —— 所以这里实际
-- 只在 `kill -INT` 时生效，语义就是"存一下，别退"。
watch('sigint', false)

-- 供外部调用的全局函数：:AutoSaveAll
vim.api.nvim_create_user_command('AutoSaveAll', function()
  local n = save_all_modified()
  vim.notify(('已保存 %d 个已修改文件'):format(n), vim.log.levels.INFO)
end, { desc = '保存所有已修改的文件' })

-- ============================================================
-- 交换文件对话框：区分「另一个 nvim 正开着」和「上次崩了」
-- ------------------------------------------------------------
-- Neovim 自带的默认处理（runtime/lua/vim/_core/defaults.lua 的 nvim.swapfile 组）
-- 只读 swap 里记录的 PID，**不检查该进程是否还活着**：
--   · PID 有效且用户相同 → 直接选 (E)dit，只给一条 W325 提示
-- 后果：kill -9 / 断电之后重开文件，它同样静默打开磁盘上的旧内容，
-- 把交换文件里的未保存内容悄悄跳过 —— 想恢复得自己想起来跑 nvim -r。
--
-- 这里在默认回调之后再设一次 vim.v.swapchoice（后注册的覆盖先注册的）：
--   · 进程还活着 + 同一用户 → 'e'，静默打开（多窗口编辑的日常场景，不打扰）
--   · 进程已死            → ''，弹出原生对话框，让你选 (R)ecover
-- ============================================================
vim.api.nvim_create_autocmd('SwapExists', {
  group = augroup,
  callback = function()
    local ok, info = pcall(vim.fn.swapinfo, vim.v.swapname)
    if not ok or type(info) ~= 'table' or info.error then
      vim.v.swapchoice = ''
      return
    end

    local pid = tonumber(info.pid) or 0
    local user = (vim.uv or vim.loop).os_get_passwd().username
    local alive = false
    if pid > 0 then
      -- 信号 0 不发送任何东西，只探测进程是否存在
      alive = pcall(function()
        (vim.uv or vim.loop).kill(pid, 0)
      end)
    end

    if alive and info.user == user then
      vim.v.swapchoice = 'e' -- 兄弟 nvim 正在编辑同一文件，直接打开
    else
      vim.v.swapchoice = '' -- 进程已死 → 显示恢复对话框
    end
  end,
})
