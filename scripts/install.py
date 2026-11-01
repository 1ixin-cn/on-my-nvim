#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Neovim 类 IDE —— 一键部署脚本（Python 版，自包含）
====================================================
目标环境：macOS（Apple Silicon 优先，Intel 亦可）+ Neovim 0.11+
依赖：只用 Python 3.8+ 标准库（另需系统自带 curl / git / tar）

与 install.sh 功能完全一致，配置本体以 tar.gz + base64 内嵌在本文件末尾的
PAYLOAD 常量里，因此**单个文件即可完成部署**，不需要仓库里的其他文件。

部署步骤（14 步）：
   1. 环境预检            8. Python 环境
   2. 备份旧配置          9. lazy.nvim 引导
   3. 部署配置(内嵌归档)  10. 插件同步
   4. 基础依赖 brew       11. Mason 工具链
   5. Rust 工具链         12. vimcdoc 中文帮助
   6. rust-analyzer       13. PATH 写入 shell 配置
   7. codelldb            14. 自检（含自动保存五层机制）

用法：
   ./install.py                  # 完整部署（幂等）
   ./install.py --check          # 只体检，不改任何东西
   ./install.py --force          # 强制重装
   ./install.py --from-dir DIR   # 从本地目录部署配置
   ./install.py --skip-plugins   # 跳过插件同步
   ./install.py --skip-mason     # 跳过 Mason
   ./install.py --dump-config D  # 只把内嵌配置解到 D
   ./install.py --help
"""

import argparse
import base64
import gzip
import io
import os
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from pathlib import Path

# ---------------------------------------------------------------- 常量
HOME = Path.home()
NVIM_CONFIG = Path(os.environ.get("NVIM_CONFIG", HOME / ".config" / "nvim"))
NVIM_DATA = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local" / "share")) / "nvim"
LOCAL_BIN = HOME / ".local" / "bin"
MASON_BIN = NVIM_DATA / "mason" / "bin"
CODELLDB_ROOT = Path(os.environ.get("CODELLDB_ROOT", HOME / ".local" / "share" / "codelldb"))
LAZY_DIR = NVIM_DATA / "lazy" / "lazy.nvim"
VIMCDOC_DIR = NVIM_DATA / "plugins-local" / "vimcdoc"
LOG_DIR = HOME / ".cache" / "nvim-install"

CODELLDB_VERSION = os.environ.get("CODELLDB_VERSION", "1.12.3")
RUST_ANALYZER_TAG = os.environ.get("RUST_ANALYZER_TAG", "2026-10-26")

OPT = {"force": False, "check": False, "skip_plugins": False, "skip_mason": False}

# ---------------------------------------------------------------- 输出
class C:
    RESET = "\033[0m"; RED = "\033[31m"; GREEN = "\033[32m"
    YELLOW = "\033[33m"; BLUE = "\033[34m"; BOLD = "\033[1m"

    @classmethod
    def off(cls):
        for k in ("RESET", "RED", "GREEN", "YELLOW", "BLUE", "BOLD"):
            setattr(cls, k, "")


if not sys.stdout.isatty():
    C.off()

LOG_FILE = LOG_DIR / "install.py.log"


def _emit(text):
    print(text, flush=True)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(re.sub(r"\033\[[0-9;]*m", "", text) + "\n")
    except OSError:
        pass


def log(msg):  _emit(f"{msg}")
def ok(msg):   _emit(f"{C.GREEN}✓{C.RESET} {msg}")
def warn(msg): _emit(f"{C.YELLOW}!{C.RESET} {msg}")
def err(msg):  _emit(f"{C.RED}✗{C.RESET} {msg}")
def head(msg): _emit(f"\n{C.BOLD}{C.BLUE}==> {msg}{C.RESET}")


def die(msg, code=1):
    err(msg)
    sys.exit(code)


def step_done(msg):
    ok(f"{msg}（已存在，跳过）")


# ---------------------------------------------------------------- 工具函数
def have(cmd):
    return shutil.which(cmd) is not None


def run(cmd, quiet=True, timeout=None):
    """跑一个命令，返回 (returncode, stdout+stderr)。不抛异常。"""
    try:
        r = subprocess.run(
            cmd,
            stdout=subprocess.PIPE if quiet else None,
            stderr=subprocess.STDOUT if quiet else None,
            text=True,
            timeout=timeout,
        )
        return r.returncode, (r.stdout or "") if quiet else ""
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, str(e)


def head1(cmd):
    """取命令输出的第一行，失败返回空串。"""
    rc, out = run(cmd)
    return out.splitlines()[0].strip() if out.strip() else ""


def download(url, dest: Path):
    log(f"    下载 {url}")
    rc, _ = run(["curl", "-fL", "--retry", "3", "--retry-delay", "2",
                 "--connect-timeout", "15", "-o", str(dest), url], quiet=False)
    return rc == 0


def clone_or_tarball(repo, branch, dest: Path, name):
    """git clone 失败时回落 codeload 压缩包（代理常拦 git 协议）。"""
    dest.parent.mkdir(parents=True, exist_ok=True)
    if (dest / ".git").is_dir():
        return True

    rc, _ = run(["git", "clone", "--depth", "1", "--branch", branch,
                 f"https://github.com/{repo}.git", str(dest)], timeout=600)
    if rc == 0:
        ok(f"    {name}: git clone 成功")
        return True

    warn(f"    {name}: git clone 失败（多为代理拦 git 协议），改用 codeload 压缩包")
    tmp = Path(tempfile.mkstemp(suffix=".tar.gz")[1])
    if not download(f"https://codeload.github.com/{repo}/tar.gz/refs/heads/{branch}", tmp):
        tmp.unlink(missing_ok=True)
        return False

    shutil.rmtree(dest, ignore_errors=True)
    dest.mkdir(parents=True, exist_ok=True)
    with tarfile.open(tmp, "r:gz") as tf:
        members = tf.getmembers()
        for m in members:
            parts = m.name.split("/", 1)
            if len(parts) < 2 or not parts[1]:
                continue
            m.name = parts[1]
            tf.extract(m, dest, filter="data") if hasattr(tarfile, "data_filter") else tf.extract(m, dest)
    tmp.unlink(missing_ok=True)
    run(["git", "init", "-q"], )  # 占位，真正的 init 在下面
    subprocess.run(["git", "init", "-q"], cwd=dest, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=dest, capture_output=True)
    subprocess.run(["git", "-c", "user.email=install@local", "-c", "user.name=install",
                    "commit", "-qm", "install"], cwd=dest, capture_output=True)
    ok(f"    {name}: 已用压缩包安装")
    return True


def ensure_path_line(line, profile: Path):
    if not profile.is_file():
        return
    text = profile.read_text(encoding="utf-8", errors="ignore")
    if line in text.splitlines():
        return
    with open(profile, "a", encoding="utf-8") as f:
        f.write(f"\n# Neovim 类 IDE 环境（由 install.py 添加）\n{line}\n")
    ok(f"    已写入 {profile}: {line}")


# ---------------------------------------------------------------- 内嵌归档
PAYLOAD = """
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
"""


def extract_payload(dest: Path):
    """把内嵌 tar.gz 解到 dest。"""
    try:
        raw = base64.b64decode("".join(PAYLOAD.split()), validate=False)
    except Exception as e:  # noqa: BLE001
        die(f"内嵌配置解码失败（脚本可能被截断）: {e}")

    dest.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tf:
        for m in tf.getmembers():
            if hasattr(tarfile, "data_filter"):
                tf.extract(m, dest, filter="data")
            else:
                tf.extract(m, dest)


# ---------------------------------------------------------------- 各步骤
def step_preflight():
    head("1/14 环境预检")
    ok(f"系统: {platform.system()} / {platform.machine()}")
    ok(f"Python: {platform.python_version()}")

    if have("nvim"):
        ok(f"Neovim: {head1(['nvim', '--version'])}")
    else:
        warn("未找到 nvim")
        if not OPT["check"] and have("brew"):
            log("    安装 neovim ...")
            rc, _ = run(["brew", "install", "neovim"])
            ok("    neovim 安装完成") if rc == 0 else warn("    neovim 安装失败")

    rc, _ = run(["curl", "-sS", "-m", "8", "-o", "/dev/null", "https://github.com"])
    if rc == 0:
        ok("网络: 可访问 github.com")
    else:
        warn("网络: 无法访问 github.com，插件/工具下载会失败")

    for t in ("tar", "curl", "git"):
        if not have(t):
            die(f"缺少必需命令: {t}")


def step_backup():
    head("2/14 备份现有配置")
    if not NVIM_CONFIG.is_dir() or not any(NVIM_CONFIG.iterdir()):
        ok("    目标目录为空，无需备份")
        return
    if OPT["check"]:
        log("    体检模式：跳过备份")
        return

    dest = NVIM_CONFIG.with_name(NVIM_CONFIG.name + ".backup." + time.strftime("%Y%m%d-%H%M%S"))
    shutil.copytree(NVIM_CONFIG, dest, symlinks=True)
    ok(f"    已备份到 {dest.name}")

    backups = sorted(NVIM_CONFIG.parent.glob(NVIM_CONFIG.name + ".backup.*"),
                     key=lambda p: p.stat().st_mtime, reverse=True)
    for old in backups[3:]:
        shutil.rmtree(old, ignore_errors=True)
        log(f"    清理旧备份: {old.name}")


def step_deploy(from_dir):
    head("3/14 部署配置（内嵌归档）")
    if OPT["check"]:
        log("    体检模式：跳过部署")
        return

    if from_dir:
        src = Path(from_dir)
        if not (src / "init.lua").is_file() or not (src / "lua").is_dir():
            die(f"--from-dir {src} 下没有 init.lua / lua")
        for item in ("init.lua", "lua", "lazy-lock.json", "README.md", "快捷键手册.md"):
            s = src / item
            if not s.exists():
                continue
            d = NVIM_CONFIG / item
            shutil.rmtree(d, ignore_errors=True) if d.is_dir() else d.unlink(missing_ok=True)
            shutil.copytree(s, d) if s.is_dir() else shutil.copy2(s, d)
        ok(f"    已从 {src} 部署")
    else:
        extract_payload(NVIM_CONFIG)
        ok("    已解出内嵌配置")

    if not (NVIM_CONFIG / "init.lua").is_file():
        die("部署后缺少 init.lua")
    autosave = NVIM_CONFIG / "lua" / "core" / "autosave.lua"
    if not autosave.is_file():
        die("部署后缺少 core/autosave.lua")
    if "UserAutoSave" not in autosave.read_text(encoding="utf-8", errors="ignore"):
        warn("    配置里没找到 UserAutoSave，可能版本不对")

    # 把本脚本也放进配置，方便以后重跑
    scripts = NVIM_CONFIG / "scripts"
    scripts.mkdir(parents=True, exist_ok=True)
    self_path = Path(__file__).resolve()
    target = scripts / "install.py"
    if self_path != target:
        try:
            shutil.copy2(self_path, target)
            target.chmod(0o755)
        except OSError:
            pass

    ok(f"    配置文件数: {sum(1 for _ in NVIM_CONFIG.rglob('*') if _.is_file())}")


def step_homebrew():
    head("4/14 基础依赖（Homebrew）")
    if not have("brew"):
        warn("未安装 Homebrew，跳过（将使用系统已有的 go / cmake / node）")
        return
    ok(f"Homebrew: {head1(['brew', '--version'])}")

    for pkg in ("go", "cmake", "node"):
        if have(pkg):
            ver = head1([pkg, "--version"]) or head1([pkg, "version"])
            step_done(f"{pkg} ({ver or '已安装'})")
            continue
        if OPT["check"]:
            warn(f"    {pkg} 未安装（体检模式不安装）")
            continue
        log(f"    安装 {pkg} ...")
        rc, _ = run(["brew", "install", pkg])
        ok(f"    {pkg} 安装完成") if rc == 0 else warn(f"    {pkg} 安装失败，可手动 brew install {pkg}")


def step_rust():
    head("5/14 Rust 工具链")
    if have("cargo") and have("rustc"):
        step_done(f"Rust ({head1(['rustc', '--version'])})")
        return
    if OPT["check"]:
        warn("    Rust 未安装（体检模式不安装）")
        return
    log("    安装 rustup ...")
    rc, _ = run(["sh", "-c",
                 "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | "
                 "sh -s -- -y --default-toolchain stable"], timeout=900)
    if rc == 0:
        ok("    rustup 安装完成")
        ensure_path_line('export PATH="$HOME/.cargo/bin:$PATH"', HOME / ".zshrc")
    else:
        warn("    rustup 安装失败，可稍后 brew install rust")


def step_rust_analyzer():
    head("6/14 rust-analyzer（独立二进制）")
    target = LOCAL_BIN / "rust-analyzer"

    if target.is_file() and os.access(target, os.X_OK) and not OPT["force"]:
        step_done(f"rust-analyzer ({head1([str(target), '--version'])})")
        return
    if OPT["check"]:
        warn("    rust-analyzer 需要安装（体检模式不安装）")
        return

    tag = RUST_ANALYZER_TAG
    if not tag:
        rc, out = run(["curl", "-sSL", "-m", "20",
                       "https://api.github.com/repos/rust-lang/rust-analyzer/releases/latest"])
        m = re.search(r'"tag_name"\s*:\s*"([^"]+)"', out)
        tag = m.group(1) if m else "latest"

    url = (f"https://github.com/rust-lang/rust-analyzer/releases/latest/download/{RUST_ANALYZER_ASSET}"
           if tag == "latest" else
           f"https://github.com/rust-lang/rust-analyzer/releases/download/{tag}/{RUST_ANALYZER_ASSET}")

    LOCAL_BIN.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkstemp(suffix=".gz")[1])
    if not download(url, tmp):
        tmp.unlink(missing_ok=True)
        warn("    rust-analyzer 下载失败。稍后可手动：")
        warn(f"      curl -fL -o /tmp/ra.gz {url} && gunzip -c /tmp/ra.gz > {target} && chmod +x {target}")
        return

    with gzip.open(tmp, "rb") as src, open(target, "wb") as dst:
        shutil.copyfileobj(src, dst)
    tmp.unlink(missing_ok=True)
    target.chmod(0o755)

    if run([str(target), "--version"])[0] == 0:
        ok(f"rust-analyzer: {head1([str(target), '--version'])}")
    else:
        target.unlink(missing_ok=True)
        err("    解压出的二进制无法执行，已清理")


def step_codelldb():
    head("7/14 codelldb 调试适配器")
    adapter = CODELLDB_ROOT / "adapter" / "codelldb"

    if adapter.is_file() and (LOCAL_BIN / "codelldb").is_file() and not OPT["force"]:
        step_done(f"codelldb ({CODELLDB_ROOT})")
        return
    if OPT["check"]:
        warn("    codelldb 需要安装（体检模式不安装）")
        return

    url = (f"https://github.com/vadimcn/codelldb/releases/download/"
           f"v{CODELLDB_VERSION}/{CODELLDB_ASSET}")
    tmp = Path(tempfile.mkstemp(suffix=".vsix")[1])
    if not download(url, tmp):
        tmp.unlink(missing_ok=True)
        warn("    codelldb 下载失败（离线或代理拦截），C/C++/Rust 调试将不可用")
        return

    shutil.rmtree(CODELLDB_ROOT, ignore_errors=True)
    CODELLDB_ROOT.mkdir(parents=True, exist_ok=True)
    try:
        import zipfile
        with zipfile.ZipFile(tmp) as zf:
            zf.extractall(CODELLDB_ROOT)
    except Exception as e:  # noqa: BLE001
        tmp.unlink(missing_ok=True)
        err(f"    解压 vsix 失败: {e}")
        return
    tmp.unlink(missing_ok=True)

    if not adapter.is_file():
        err("    未找到 adapter/codelldb")
        return
    adapter.chmod(0o755)

    LOCAL_BIN.mkdir(parents=True, exist_ok=True)
    wrapper = LOCAL_BIN / "codelldb"
    if wrapper.exists() or wrapper.is_symlink():
        wrapper.unlink()
    wrapper.write_text(
        "#!/bin/sh\n"
        "# codelldb 启动包装（由 install.py 生成）\n"
        "# 真正的 DAP 适配器是 <root>/adapter/codelldb，\n"
        "# 不是 lldb/bin/lldb-server（后者只是 gdbserver，不认 --port）。\n"
        'CODELLDB_ROOT="${CODELLDB_ROOT:-$HOME/.local/share/codelldb}"\n'
        'exec "$CODELLDB_ROOT/adapter/codelldb" \\\n'
        '  --liblldb "$CODELLDB_ROOT/lldb/lib/liblldb.dylib" \\\n'
        '  "$@"\n',
        encoding="utf-8",
    )
    wrapper.chmod(0o755)

    if run([str(wrapper), "--help"])[0] == 0:
        ok(f"codelldb v{CODELLDB_VERSION} 就绪")
    else:
        warn("    codelldb 已解压但自测未通过，检查 liblldb.dylib")


def step_python():
    head("8/14 Python 环境")
    if have("python3"):
        step_done(f"python3 ({head1(['python3', '--version'])})")
    elif not OPT["check"] and have("brew"):
        log("    安装 python3 ...")
        rc, _ = run(["brew", "install", "python3"])
        ok("    python3 安装完成") if rc == 0 else warn("    python3 安装失败")
    else:
        warn("    python3 未找到")
    log("    提示: Python 调试器 debugpy 由 Mason 在第 11 步安装")


def step_lazy():
    head("9/14 lazy.nvim 引导")
    if (LAZY_DIR / ".git").is_dir() or (LAZY_DIR / "lua" / "lazy" / "init.lua").is_file():
        step_done("lazy.nvim")
        return
    if OPT["check"]:
        warn("    lazy.nvim 需要安装（体检模式不安装）")
        return
    if not clone_or_tarball("folke/lazy.nvim", "main", LAZY_DIR, "lazy.nvim"):
        die("lazy.nvim 安装失败，后续插件无法加载")
    ok("lazy.nvim 就绪")


def step_plugins():
    head("10/14 插件同步")
    if OPT["skip_plugins"]:
        warn("已指定 --skip-plugins，跳过")
        return

    lock = NVIM_CONFIG / "lazy-lock.json"
    total = len(re.findall(r'"branch"', lock.read_text(encoding="utf-8"))) if lock.is_file() else 0
    have_n = len([p for p in (NVIM_DATA / "lazy").glob("*") if p.is_dir()]) if (NVIM_DATA / "lazy").is_dir() else 0
    log(f"    lazy-lock.json 记录 {total} 个，当前已装 {have_n} 个")

    if OPT["check"]:
        (warn if have_n < total else ok)(f"    {'未装齐' if have_n < total else '已装齐'}（{have_n}/{total}）")
        return

    log("    开始同步（首次几分钟，取决于网络）...")
    rc, _ = run(["nvim", "--headless", "-u", str(NVIM_CONFIG / "init.lua"),
                 "-c", "lua require('lazy').sync({ wait = true, show = false })",
                 "-c", "qa!"], timeout=1800)
    if rc == 0:
        n = len([p for p in (NVIM_DATA / "lazy").glob("*") if p.is_dir()])
        ok(f"插件同步完成（{n} 个）")
    else:
        warn("插件同步未完全成功，可在 nvim 里 :Lazy sync 查看")


def step_mason():
    head("11/14 Mason 工具链")
    if OPT["skip_mason"]:
        warn("已指定 --skip-mason，跳过")
        return

    tools = ["clangd", "gopls", "pyright", "ruff", "stylua",
             "clang-format", "goimports", "gofumpt", "taplo", "debugpy", "dlv"]
    missing = [t for t in tools if not (MASON_BIN / t).exists()]
    if not missing:
        step_done(f"Mason 工具（{len(tools)} 个已就位）")
        return
    log(f"    待安装: {' '.join(missing)}")
    if OPT["check"]:
        warn("    体检模式不安装，可在 nvim 里 :Mason 手动装")
        return

    wait_lua = """local tools = { 'clangd', 'gopls', 'pyright', 'ruff', 'stylua',
                'clang-format', 'goimports', 'gofumpt', 'taplo', 'debugpy', 'dlv' }
local root = vim.fn.stdpath('data') .. '/mason/bin/'
local pending = function()
  local left = {}
  for _, t in ipairs(tools) do
    if vim.fn.filereadable(root .. t) == 0 then table.insert(left, t) end
  end
  return left
end
vim.wait(300000, function() return #pending() == 0 end, 1000)
"""
    tmp = Path(tempfile.mkstemp(suffix=".lua")[1])
    tmp.write_text(wait_lua, encoding="utf-8")
    run(["nvim", "--headless", "-u", str(NVIM_CONFIG / "init.lua"),
         "-c", "MasonToolsInstall", "-c", f"luafile {tmp}", "-c", "qa!"], timeout=1800)
    tmp.unlink(missing_ok=True)

    still = []
    for t in tools:
        if (MASON_BIN / t).exists():
            ok(f"    {t} ✓")
        else:
            still.append(t)
    if still:
        warn(f"    以下未装成功: {' '.join(still)}（可在 nvim 里 :Mason 手动装）")


def step_vimcdoc():
    head("12/14 中文帮助文档")
    if (VIMCDOC_DIR / "doc").is_dir():
        step_done("vimcdoc")
        return
    if OPT["check"]:
        warn("    vimcdoc 未安装（体检模式不安装）")
        return
    VIMCDOC_DIR.parent.mkdir(parents=True, exist_ok=True)
    if clone_or_tarball("yianwillis/vimcdoc", "master", VIMCDOC_DIR, "vimcdoc"):
        ok("vimcdoc 就绪")
        warn(f"    提示: 在 nvim 里 :helptags {VIMCDOC_DIR}/doc 后中文帮助生效")
    else:
        warn("vimcdoc 安装失败（不影响功能）")


def step_path():
    head("13/14 PATH 与 shell 配置")
    if OPT["check"]:
        log("    体检模式：跳过")
        return
    LOCAL_BIN.mkdir(parents=True, exist_ok=True)
    for profile in (HOME / ".zshrc", HOME / ".bashrc"):
        ensure_path_line('export PATH="$HOME/.local/bin:$PATH"', profile)


def step_verify():
    head("14/14 自检")

    def version_arg(name):
        if name in ("go", "gopls", "dlv"):
            return "version"
        if name == "codelldb":
            return "--help"
        return "--version"

    def resolve(name):
        for p in (MASON_BIN / name, LOCAL_BIN / name):
            if p.is_file() and os.access(p, os.X_OK):
                return str(p)
        found = shutil.which(name)
        if found and found != str(HOME / ".cargo" / "bin" / "rust-analyzer"):
            return found
        cargo = HOME / ".cargo" / "bin" / name
        if name != "rust-analyzer" and cargo.is_file():
            return str(cargo)
        return ""

    for name in ("go", "rustc", "cargo", "rust-analyzer", "codelldb",
                 "clangd", "gopls", "pyright", "ruff", "dlv"):
        p = resolve(name)
        if p:
            if name == "codelldb":
                ok(f"{name:<14} 可用 -> {p}")
            else:
                ok(f"{name:<14} {head1([p, version_arg(name)]) or '?'}")
        else:
            warn(f"{name:<14} 缺失")

    if not have("nvim"):
        warn("    未安装 nvim，跳过配置自检")
        return

    lua = """
OUT_FILE = "__OUT_FILE_PATH__"
local out = {}
local function p(s) table.insert(out, s) end
p('lazy.nvim: ' .. tostring(pcall(require, 'lazy')))
local events, has_i, has_swap = {}, false, false
for _, a in ipairs(vim.api.nvim_get_autocmds({ group = 'UserAutoSave' })) do
  table.insert(events, a.event)
  if a.event == 'CursorHoldI' then has_i = true end
  if a.event == 'SwapExists' then has_swap = true end
end
table.sort(events)
p('自动保存组: ' .. #events .. ' 条 [' .. table.concat(events, ',') .. ']')
p('插入模式兜底(CursorHoldI): ' .. tostring(has_i))
p('崩溃恢复(SwapExists): ' .. tostring(has_swap))
p('定时保存间隔: ' .. tostring(vim.g.autosave_interval or 5000) .. 'ms')
p('交换文件目录: ' .. vim.o.directory .. (vim.o.directory:sub(-2) == '//' and ' (含 //，正确)' or ' (缺 //，需修正)'))
-- 等 VeryLazy 阶段的插件（dap-go 等）把调试配置注册完，
-- 否则同一份配置每次统计出来数目都不一样
vim.wait(800, function() return false end, 100)
local okd, dap = pcall(require, 'dap')
if okd then
  local fts = {}
  for k, v in pairs(dap.configurations) do
    -- 只报语言名，不报条数：条数会随插件注册时机浮动
    if type(v) == 'table' and #v > 0 then table.insert(fts, k) end
  end
  table.sort(fts)
  p('调试配置: ' .. (#fts > 0 and table.concat(fts, ', ') or '无'))
end
local okp, paths = pcall(require, 'core.paths')
if okp then
  for _, n in ipairs({ 'rust-analyzer', 'codelldb', 'gopls', 'clangd', 'pyright', 'ruff' }) do
    p(string.format('%-16s %s', n, paths.resolve(n)))
  end
end
local f = io.open(OUT_FILE, 'w')
if f then f:write(table.concat(out, '\\n') .. '\\n'); f:close() end
"""
    out_file = Path(tempfile.mkstemp(suffix=".txt")[1])
    lua_file = Path(tempfile.mkstemp(suffix=".lua")[1])
    lua_file.write_text(lua.replace("__OUT_FILE_PATH__", str(out_file)), encoding="utf-8")

    log("    配置内自检：")
    run(["nvim", "--headless", "-u", str(NVIM_CONFIG / "init.lua"),
         "-c", f"luafile {lua_file}", "-c", "qa!"], timeout=180)
    text = out_file.read_text(encoding="utf-8") if out_file.is_file() else ""
    if text.strip():
        for line in text.strip().splitlines():
            log(f"      {line}")
    else:
        warn("    自检无输出（配置可能加载失败，手动运行 nvim 看报错）")
    lua_file.unlink(missing_ok=True)
    out_file.unlink(missing_ok=True)


# ---------------------------------------------------------------- 主流程
def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--skip-plugins", action="store_true")
    ap.add_argument("--skip-mason", action="store_true")
    ap.add_argument("--from-dir", default="")
    ap.add_argument("--dump-config", default="")
    ap.add_argument("-h", "--help", action="store_true")
    a = ap.parse_args()

    if a.help:
        print(__doc__)
        return

    OPT.update(check=a.check, force=a.force,
               skip_plugins=a.skip_plugins, skip_mason=a.skip_mason)

    if a.dump_config:
        extract_payload(Path(a.dump_config))
        ok(f"配置已解到 {a.dump_config}")
        return

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    _emit(f"{C.BOLD}{C.BLUE}Neovim 类 IDE 一键部署（Python）{C.RESET}")
    log(f"开始时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    log(f"日志:     {LOG_FILE}")
    log(f"目标:     {NVIM_CONFIG}")
    log(f"配置来源: {a.from_dir or '脚本内嵌归档'}")

    step_preflight()
    step_backup()
    step_deploy(a.from_dir)
    step_homebrew()
    step_rust()
    step_rust_analyzer()
    step_codelldb()
    step_python()
    step_lazy()
    step_plugins()
    step_mason()
    step_vimcdoc()
    step_path()
    step_verify()

    print()
    ok("部署流程结束")
    log(f"结束时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"\n{C.BOLD}下一步{C.RESET}")
    print("  1. 重新打开终端（或 source ~/.zshrc）让 PATH 生效")
    print("  2. 运行 nvim，首次会自动补装剩余插件/工具")
    print("  3. 随便改个文件停手 1 秒，确认已自动写盘")
    print(f"  4. 快捷键手册: {NVIM_CONFIG}/快捷键手册.md")


# 架构相关资产名（在 main 之前按机器设置）
_arch = platform.machine()
if _arch in ("arm64", "aarch64"):
    CODELLDB_ASSET = "codelldb-darwin-arm64.vsix"
    RUST_ANALYZER_ASSET = "rust-analyzer-aarch64-apple-darwin.gz"
elif _arch in ("x86_64", "AMD64"):
    CODELLDB_ASSET = "codelldb-darwin-x64.vsix"
    RUST_ANALYZER_ASSET = "rust-analyzer-x86_64-apple-darwin.gz"
else:
    CODELLDB_ASSET = "codelldb-darwin-arm64.vsix"
    RUST_ANALYZER_ASSET = "rust-analyzer-aarch64-apple-darwin.gz"

if __name__ == "__main__":
    main()
