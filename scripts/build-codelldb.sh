#!/bin/bash
# ============================================================
# 从源码构建 codelldb 调试适配器
# 用途：C / C++ / Rust 的 DAP 调试
# 原理：codelldb 是 VSCode 的 LLDB 调试插件，DAP 通过它驱动 lldb
# 依赖：Rust（cargo）、unzip、curl
# ============================================================
set -euo pipefail

CODELLDB_DIR="${1:-$HOME/.local/share/codelldb-src}"
CODELLDB_VER="v0.12.0"
REPO="https://github.com/vadimcn/vscode-lldb.git"

echo "==> 准备目录 ${CODELLDB_DIR}"
mkdir -p "${CODELLDB_DIR}"

if [[ ! -d "${CODELLDB_DIR}/.git" ]]; then
  echo "==> 克隆源码 (${CODELLDB_VER})"
  git clone --depth 1 --branch "${CODELLDB_VER}" "${REPO}" "${CODELLDB_DIR}" 2>&1 | tail -3
else
  echo "==> 源码已存在，切换到 ${CODELLDB_VER}"
  git -C "${CODELLDB_DIR}" fetch --depth 1 origin "${CODELLDB_VER}" 2>/dev/null || true
  git -C "${CODELLDB_DIR}" checkout "${CODELLDB_VER}" 2>&1 | tail -2
fi

echo "==> 使用 cargo 构建 codelldb（首次编译约需 2-5 分钟）"
cd "${CODELLDB_DIR}"
cargo build --release 2>&1 | tail -20

BIN="${CODELLDB_DIR}/target/release/codelldb"
if [[ ! -x "${BIN}" ]]; then
  echo "✗ 构建失败，未找到 ${BIN}"
  exit 1
fi

echo "✓ 构建完成: ${BIN}"
echo ""
echo "配置方式：在 nvim 的 lua/options/basic.lua 中已将下述目录加入 PATH"
echo "  ${CODELLDB_DIR}/target/release"
