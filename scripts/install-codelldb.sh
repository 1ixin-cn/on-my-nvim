#!/bin/bash
# ============================================================
# 安装 codelldb 调试适配器
# 用途：C / C++ / Rust 的 DAP 调试
# 原理：codelldb 是 VSCode 的 LLDB 调试插件，DAP 通过它驱动 lldb
# ============================================================
set -euo pipefail

CODELLDB_DIR="${1:-$HOME/.local/share/codelldb}"
CODELLDB_VER="v0.12.0"
EXT_ID="vadimcn.vscode-lldb"

echo "==> 安装 codelldb (${CODELLDB_VER}) 到 ${CODELLDB_DIR}"

if [[ -d "${CODELLDB_DIR}/${EXT_ID}/bin/codelldb" ]]; then
  echo "✓ codelldb 已存在，跳过安装"
  exit 0
fi

mkdir -p "${CODELLDB_DIR}"

URL="https://github.com/vadimcn/vscode-lldb/releases/download/${CODELLDB_VER}/${EXT_ID}-darwin-arm64.vsix"

echo "==> 下载: ${URL}"
TMP_VSIX="$(mktemp -t codelldb).vsix"
curl -fL --progress-bar -o "${TMP_VSIX}" "${URL}"

echo "==> 解压"
cd "${CODELLDB_DIR}"
unzip -oq "${TMP_VSIX}" -d "${CODELLDB_DIR}"

rm -f "${TMP_VSIX}"

BIN="${CODELLDB_DIR}/${EXT_ID}/bin/codelldb"
if [[ -x "${BIN}" ]]; then
  chmod +x "${BIN}"
  echo "✓ 安装完成: ${BIN}"
  echo ""
  echo "请将以下路径加入 PATH，或在 nvim 配置中指定："
  echo "  export PATH=\"${CODELLDB_DIR}/${EXT_ID}/bin:\$PATH\""
else
  echo "✗ 安装异常，未找到 codelldb 可执行文件"
  ls -R "${CODELLDB_DIR}" | head -30
  exit 1
fi
