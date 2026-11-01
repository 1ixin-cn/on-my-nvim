#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把当前 nvim 配置打包成 tar.gz + base64，并注入到三份部署脚本里。

用法：
    python3 tools/make-payload.py            # 重新打包并注入三份脚本
    python3 tools/make-payload.py --check    # 只比对：内嵌载荷是否与当前配置一致
    python3 tools/make-payload.py --dump DIR # 只把载荷解出来，便于人工 diff

为什么要用脚本而不是手敲 tar：macOS 的 bsdtar 会往归档里塞 AppleDouble
（`._xxx`）文件，`__pycache__` / `*.pyc` 也很容易混进来，archive 会凭空胖一倍、
解出来还多出几十个脏文件。这里用 Python 的 tarfile 逐个 add，白名单添加，
从源头上避免。
"""

import argparse
import base64
import gzip
import io
import os
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# 归档里要包含什么（相对 ROOT 的路径）。故意不含三份部署脚本本身：
# 否则 payload 里套 payload，体积翻倍，而且部署完谁也不需要再装一次。
INCLUDE = [
    "init.lua",
    "lazy-lock.json",
    "README.md",
    "快捷键手册.md",
    "lua",
    # codelldb 的两个辅助脚本（手工重装/源码编译用），装机后留在 ~/.config/nvim/scripts/
    "scripts/install-codelldb.sh",
    "scripts/build-codelldb.sh",
]

# 归档里要排除什么
EXCLUDE_SUFFIX = (".bak", ".swp", ".swo", ".pyc", ".DS_Store", ".orig", ".rej")
EXCLUDE_DIRS = {"__pycache__", ".git", ".cache", "node_modules"}

# 三份脚本里载荷区段的起止标记
TARGETS = [
    {
        "file": "install.sh",
        "begin": "  cat <<'NVIM_PAYLOAD_EOF'",
        "end": "NVIM_PAYLOAD_EOF",
    },
    {
        "file": "install.py",
        "begin": 'PAYLOAD = """',
        "end": '"""',
    },
    {
        "file": "install.rs",
        "begin": 'const PAYLOAD: &str = r#"',
        "end": '"#;',
    },
]

WRAP = 76


def collect_files():
    """按白名单收集要打包的内容。

    返回 (files, dirs)：
      files —— [(绝对路径, 归档内相对路径)]
      dirs  —— [归档内相对路径]，只放**空目录**（例如 lua/langs 占位目录）。
               非空目录会被 tar 自动带出来，不用单列。
    """
    out = []
    all_dirs = []
    for entry in INCLUDE:
        p = ROOT / entry
        if not p.exists():
            print(f"  ! 缺少 {entry}，跳过", file=sys.stderr)
            continue
        if p.is_file():
            if _ok_file(p):
                out.append((p, entry))
            continue
        for dirpath, dirnames, filenames in os.walk(p):
            # 原地过滤目录，os.walk 就不会往里走
            dirnames[:] = sorted(
                d for d in dirnames if d not in EXCLUDE_DIRS and not d.startswith(".")
            )
            all_dirs.append(str(Path(dirpath).relative_to(ROOT)))
            for fn in sorted(filenames):
                fp = Path(dirpath) / fn
                if not _ok_file(fp):
                    continue
                out.append((fp, str(fp.relative_to(ROOT))))
    file_arcs = {arc for _, arc in out}
    empty_dirs = [
        d for d in all_dirs
        if d != "." and not any(a == d or a.startswith(d + "/") for a in file_arcs)
    ]
    return out, empty_dirs


def _ok_file(p: Path) -> bool:
    if p.name.startswith("._"):
        return False
    if p.name.startswith("."):
        return False
    for suf in EXCLUDE_SUFFIX:
        if p.name.endswith(suf):
            return False
    return p.is_file()


def build_archive(files, empty_dirs=()) -> bytes:
    """构建 gzip 压缩的 tar，返回原始字节。"""
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode="w") as tar:
        for d in empty_dirs:
            info = tarfile.TarInfo(name=d)
            info.type = tarfile.DIRTYPE
            info.mode = 0o755
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            tar.addfile(info)
        for abs_path, arc_name in files:
            info = tar.gettarinfo(name=str(abs_path), arcname=arc_name)
            info.uid = 0
            info.gid = 0
            info.uname = ""
            info.gname = ""
            # 权限只保留「可执行/不可执行」这一位，其他位统一化，
            # 避免把本机的奇怪 mode 带进归档
            info.mode = 0o755 if os.access(abs_path, os.X_OK) else 0o644
            with open(abs_path, "rb") as fh:
                tar.addfile(info, fh)
    raw.seek(0)
    gz = io.BytesIO()
    # mtime=0：同样的内容每次打包得到同样的字节，方便比对是否漂移
    with gzip.GzipFile(fileobj=gz, mode="wb", compresslevel=9, mtime=0) as f:
        f.write(raw.getvalue())
    return gz.getvalue()


def to_b64(data: bytes) -> str:
    s = base64.b64encode(data).decode("ascii")
    return "\n".join(s[i:i + WRAP] for i in range(0, len(s), WRAP))


def extract_region(text: str, target: dict):
    """在脚本文本里定位载荷区段，返回 (起, 止) 的行索引（0-based，含边界行）。"""
    lines = text.splitlines()
    begin = end = -1
    for i, ln in enumerate(lines):
        if begin < 0:
            if ln.rstrip() == target["begin"]:
                begin = i
            continue
        if ln.rstrip() == target["end"]:
            end = i
            break
    if begin < 0 or end < 0:
        raise SystemExit(f"  ✗ {target['file']}：找不到载荷区段标记 {target['begin']!r}")
    return lines, begin, end


def read_payload(script: Path, target: dict) -> str:
    lines, b, e = extract_region(script.read_text(encoding="utf-8"), target)
    return "\n".join(lines[b + 1:e])


def inject(script: Path, target: dict, b64: str) -> tuple:
    text = script.read_text(encoding="utf-8")
    lines, b, e = extract_region(text, target)
    new_lines = lines[: b + 1] + b64.splitlines() + lines[e:]
    new_text = "\n".join(new_lines)
    if text.endswith("\n"):
        new_text += "\n"
    old_size = len(text.encode("utf-8"))
    script.write_text(new_text, encoding="utf-8")
    return old_size, len(new_text.encode("utf-8"))


def cmd_build():
    print("打包配置…")
    files, empty_dirs = collect_files()
    if not files:
        raise SystemExit("  ✗ 没收集到任何文件，检查 INCLUDE")
    gz = build_archive(files, empty_dirs)
    b64 = to_b64(gz)
    print(f"  文件数 {len(files)}   空目录 {len(empty_dirs)}"
          f"   tar.gz {len(gz) / 1024:.1f} KB   base64 {len(b64) / 1024:.1f} KB")
    print("注入三份脚本…")
    for t in TARGETS:
        p = ROOT / "scripts" / t["file"]
        if not p.exists():
            print(f"  ! {t['file']} 不存在，跳过")
            continue
        old, new = inject(p, t, b64)
        print(f"  ✓ {t['file']:12s} {old / 1024:7.1f} KB → {new / 1024:7.1f} KB")
    print("\n完成。建议接着验证：")
    print("  mkdir -p /tmp/pv && ./scripts/install.sh --dump-config /tmp/pv")
    print("  diff -r --exclude=scripts --exclude=tools --exclude='*.bak' ~/.config/nvim /tmp/pv")


def cmd_check():
    print("比对内嵌载荷与当前配置…")
    files, empty_dirs = collect_files()
    gz = build_archive(files, empty_dirs)
    expect = to_b64(gz)
    ok = True
    for t in TARGETS:
        p = ROOT / "scripts" / t["file"]
        if not p.exists():
            print(f"  - {t['file']} 不存在")
            continue
        have = read_payload(p, t).strip()
        same = have == expect.strip()
        ok = ok and same
        print(f"  {'✓' if same else '✗'} {t['file']:12s} "
              f"{'一致' if same else '已过期，需要重新注入'}")
    return 0 if ok else 1


def cmd_dump(out_dir: str):
    files, empty_dirs = collect_files()
    gz = build_archive(files, empty_dirs)
    dest = Path(out_dir)
    dest.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(gz), mode="r:gz") as tar:
        tar.extractall(dest)
    print(f"已解到 {dest}（{len(files)} 个文件）")


def main():
    ap = argparse.ArgumentParser(description="重建并注入 nvim 配置载荷")
    ap.add_argument("--check", action="store_true", help="只检查是否过期，不写入")
    ap.add_argument("--dump", metavar="DIR", help="只把载荷解到 DIR")
    args = ap.parse_args()

    if args.check:
        sys.exit(cmd_check())
    if args.dump:
        cmd_dump(args.dump)
        return
    cmd_build()


if __name__ == "__main__":
    main()
