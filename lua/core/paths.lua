-- ============================================================
-- 二进制路径解析
-- ------------------------------------------------------------
-- 背景：本机存在多个来源的同名二进制，部分来源是失效的 shim：
--   ~/.cargo/bin/rust-analyzer  -> rustup 的符号链接，但手工安装的
--                                  toolchain 没有 rust-analyzer 组件，
--                                  执行会报 "missing manifest in toolchain"
--   ~/.local/bin/              -> 用户自装二进制（本次 rust-analyzer 安装于此）
--   mason/bin/                 -> mason 管理的包
-- 因此不能只靠 PATH 顺序，必须显式过滤掉已知的坏 shim。
-- ============================================================

local M = {}

-- 已知不可用的 shim：只有 rust-analyzer 这一个是坏的
-- （手工安装的 rustup toolchain 没有 rust-analyzer 组件，
--   ~/.cargo/bin/rust-analyzer 执行会报 "missing manifest in toolchain"）
-- 注意：~/.cargo/bin 下的 rustc / cargo / clippy 等 shim 是可用的，
-- 不能按目录整体排除。
-- 注意：这里是 Lua 模式匹配（不是正则）。
-- `%.` 表示字面量点号，`%-` 表示字面量连字符。
-- 之前误写成 `'/%%.cargo/...'`（两个百分号），`%%` 匹配的是一个字面量 `%`，
-- 于是这个规则永远匹配不上 —— 坏 shim 过滤形同虚设，
-- rust-analyzer 被解析成 ~/.cargo/bin 下的 rustup shim。
-- 当时之所以还能用，只是因为 rustup 会兜底回落到 ~/.local/bin，
-- 一旦 PATH 里没有 ~/.local/bin 就会直接失败。
local BAD_SHIMS = {
  ['/%.cargo/bin/rust%-analyzer$'] = true,
}

--- 判断路径是否为已知坏 shim
---@param path string
---@return boolean
local function is_bad_shim(path)
  for pat, _ in pairs(BAD_SHIMS) do
    if path:match(pat) then
      return true
    end
  end
  return false
end

--- 解析可执行文件路径
--- 依次尝试：PATH（排除坏 shim）-> mason/bin -> ~/.local/bin -> ~/.cargo/bin
---@param name string 二进制名，如 'rust-analyzer' / 'codelldb'
---@return string 找到返回绝对路径，未找到返回原始 name（交由 LSP 报错）
function M.resolve(name)
  -- 1) PATH 查找（跳过坏 shim）
  local from_path = vim.fn.exepath(name)
  if from_path ~= '' and not is_bad_shim(from_path) then
    return from_path
  end

  -- 2) 显式候选目录，按可靠性排序
  local candidates = {
    vim.fn.stdpath('data') .. '/mason/bin/' .. name,
    vim.fn.expand('~/.local/bin/' .. name),
    vim.fn.expand('~/.cargo/bin/' .. name),
  }
  for _, cand in ipairs(candidates) do
    if vim.fn.filereadable(cand) == 1 and not is_bad_shim(cand) then
      return cand
    end
  end

  -- 3) 都没找到：若 PATH 里那个是坏 shim，返回 name 让上层给出清晰提示
  return name
end

--- 判断二进制是否可用（真正能执行）
---@param name string
---@return boolean
function M.available(name)
  local path = M.resolve(name)
  if path == name then
    return false
  end
  -- 真正执行一次验证，避免 shim 存在但组件缺失的假阳性
  local ok = vim.fn.system({ path, '--version' })
  return vim.v.shell_error == 0 and ok ~= ''
end

return M
