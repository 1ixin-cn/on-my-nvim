# Neovim 类 IDE 环境

基于 Neovim 搭建的多语言 IDE：实时调试、实时/阶段编译、代码高亮补全、会话不丢失、全面汉化。

仓库地址：<https://github.com/lixin-yangquan/on-my-nvim>

```bash
# 方式一：克隆仓库（推荐，之后 git pull 就能同步更新）
git clone https://github.com/lixin-yangquan/on-my-nvim.git ~/.config/nvim
~/.config/nvim/scripts/install.sh

# 方式二：不克隆，直接下载单个部署脚本（自带全部配置）
curl -fsSLO https://raw.githubusercontent.com/lixin-yangquan/on-my-nvim/main/scripts/install.sh
bash install.sh
```

- 📖 **快捷键完全手册**：[`快捷键手册.md`](快捷键手册.md)（详细版，按场景组织）
- 🚀 **一键部署脚本**（三份，功能完全等价，任选其一）
  - `scripts/install.sh` — Shell 版，**零依赖**，macOS 开箱即用 → 推荐
  - `scripts/install.py` — Python 版，只用标准库
  - `scripts/install.rs` — Rust 版，单文件源码，`rustc` 直接编译成单文件二进制

```bash
# 全新机器部署（三版任选）
./scripts/install.sh
python3 scripts/install.py
rustc -O scripts/install.rs -o /tmp/nvim-install && /tmp/nvim-install --check

# 只体检不安装
./scripts/install.sh --check
```

> 三份脚本**都自带完整配置**：`init.lua` / `lua/` / `lazy-lock.json` / `README.md` /
> `快捷键手册.md` 被打成 tar.gz + base64 内嵌在脚本末尾。拷贝**单个文件**到新机器即可
> 复现整套环境，不需要带仓库。

---

## 一、目录结构

```
~/.config/nvim/
├── init.lua                    主入口
├── 快捷键手册.md               快捷键完全手册（详细）
├── README.md                   本文档
├── lua/
│   ├── options/basic.lua       基础选项
│   ├── core/
│   │   ├── autosave.lua        自动保存（防丢文件）
│   │   ├── i18n.lua            汉化核心
│   │   ├── lsp.lua             LSP 服务器定义
│   │   ├── dap.lua             调试配置
│   │   ├── tasks.lua           任务系统（阶段/实时编译）
│   │   ├── paths.lua           二进制路径解析（跳过坏 shim）
│   │   └── session.lua         会话持久化
│   ├── keymaps/init.lua        全局快捷键
│   └── plugins/
│       ├── mason.lua           工具链自动安装
│       ├── lsp.lua             LSP 客户端
│       ├── cmp.lua             补全引擎
│       ├── ui.lua              主题/状态栏/文件树/Telescope
│       ├── editor.lua          编辑增强
│       ├── dap.lua             调试插件
│       ├── session.lua         会话持久化插件
│       └── langs.lua           各语言增强
├── scripts/
│   ├── install.sh              ★ 一键部署 Shell 版（14 步，幂等，自包含）
│   ├── install.py              ★ 一键部署 Python 版（仅标准库，自包含）
│   ├── install.rs              ★ 一键部署 Rust 版（无依赖，自包含）
│   ├── install-codelldb.sh     codelldb 二进制安装
│   └── build-codelldb.sh       codelldb 源码编译
└── tools/
    └── make-payload.py         重建配置载荷并注入三份部署脚本
```

---

## 二、快捷键总览（Leader = 空格）

### 文件与窗口

| 快捷键 | 功能 |
|---|---|
| `<leader>w` | 保存 |
| `<leader>W` | 强制保存 |
| `<leader>wa` | 保存全部 |
| `<leader>wq` / `<leader>wqa` | 保存并退出 |
| `<leader>q` / `<leader>qa` | 退出 |
| `<leader>wh/wj/wk/wl` | 窗口 左/下/上/右 |
| `<leader>ws` / `<leader>wv` | 上下 / 左右分割 |
| `<leader>wn` / `<leader>wc` | 新窗口 / 关闭窗口 |
| `<leader>tn` / `<leader>tc` | 新标签页 / 关闭标签页 |

### 编译（阶段化）

| 快捷键 | 阶段 | Rust | Go | Python | C/C++ |
|---|---|---|---|---|---|
| `<leader>cc` | 检查 | `cargo check` | `go vet` | `ruff` | `clang++ -fsyntax-only` |
| `<leader>cb` | 构建 | `cargo build` | `go build` | `compileall` | `make` |
| `<leader>cr` | 运行 | `cargo run` | `go run` | `python3` | `make run` |
| `<leader>ct` | 测试 | `cargo test` | `go test` | `pytest` | `make test` |
| `<leader>cz` | 实时编译开关 | 开/关实时检查 | | | |
| `<leader>cl` | 列出当前可用任务 | | | | |

> 编译错误自动汇入 Trouble 面板（`<leader>xx`），可点击跳转。
>
> 两种执行方式的行为差异（重要）：
> - **手动阶段编译**（`<leader>cc` 等）：失败时自动打开并聚焦 Trouble，同时弹通知；
>   成功时只弹一条通知，不打开面板。
> - **实时编译**（保存触发，`quiet` 模式）：**完全静默** —— 不弹面板、不弹通知，
>   结果只以行内标记/虚拟文本呈现。原因是自动保存挂在 `TextChanged` 上，
>   每敲几个字就保存一次，若此时抢焦点会让光标被反复拽走。

### 调试

| 快捷键 | 功能 |
|---|---|
| `<F5>` | 继续 / 启动调试 |
| `<F10>` | 单步跳过 |
| `<F11>` | 单步进入 |
| `<F12>` | 单步跳出 |
| `<leader>db` | 切换断点 |
| `<leader>dB` | 条件断点 |
| `<leader>du` | 调试面板开关 |
| `<leader>di` | 求值（表达式） |
| `<leader>dw` | 调试命令窗口 |
| `<leader>dr` | 用上次配置重跑 |

支持的调试器：

- **Python** — debugpy
- **Go** — Delve (`dlv`)
- **Rust / C / C++** — codelldb（LLDB）

### LSP

| 快捷键 | 功能 |
|---|---|
| `gd` | 跳转定义 |
| `gD` | 跳转声明 |
| `gr` | 查找引用 |
| `K` | 悬浮文档 |
| `<C-k>` | 函数签名 |
| `<leader>lr` | 重命名 |
| `<leader>la` | 代码操作 |
| `<leader>lf` | 格式化 |
| `<leader>ld` | 诊断详情 |
| `]d` / `[d` | 跳到下/上一个诊断 |

### 搜索与文件

| 快捷键 | 功能 |
|---|---|
| `<leader>ff` | 查找文件 |
| `<leader>fg` | 全局搜索内容 |
| `<leader>fb` | 切换缓冲区 |
| `<leader>fh` | 搜索帮助文档 |
| `<leader>fr` | 最近打开的文件 |
| `<leader>fd` | 搜索诊断信息 |
| `<leader>e` | 文件树开关 |
| `<leader>nl` | 代码大纲开关 |

### 问题面板（Trouble）

| 快捷键 | 功能 |
|---|---|
| `<leader>xx` | 面板总开关 |
| `<leader>xd` | 诊断 |
| `<leader>xq` | 快速修复 |
| `<leader>xt` | TODO 标记 |

### Git

| 快捷键 | 功能 |
|---|---|
| `<leader>gs` | 暂存改动块 |
| `<leader>gS` | 暂存整个文件 |
| `<leader>gr` | 撤销改动块 |
| `<leader>gp` | 预览改动 |
| `<leader>gb` | 行级 blame |

### 其他

| 快捷键 | 功能 |
|---|---|
| `<C-\>` | 终端开关 |
| `<leader>cl` | 注释切换 |
| `<leader>to` | 搜索 TODO |
| `<leader>ms` | Mason 面板 |
| `<leader>hh` | 中文帮助 |
| `<leader>ss` / `<leader>sl` | 保存会话 / 恢复会话 |

---

## 三、防丢文件机制

五层保护，从"最常触发"到"最后兜底"：

| # | 机制 | 触发时机 | 覆盖的场景 |
|---|---|---|---|
| 1 | **事件自动保存** | 离开插入模式、正常模式改动、窗口失焦、离开 buffer、停手 250ms（含插入模式） | 日常打字 |
| 2 | **定时兜底** | 每 5 秒扫一遍所有已修改 buffer | 事件被插件清掉、宏回放、大批量操作时不让出空闲时间 |
| 3 | **退出保存** | `VimLeavePre` 逐 buffer 保存 + `VimLeave` 补 `wall` | `:q` / `:qa` / `:wq` |
| 4 | **信号保存** | SIGHUP（关终端窗口/关 tmux）、SIGTERM（kill、关机）、SIGQUIT | 直接关终端、`kill <pid>`、终端崩溃 |
| 5 | **交换文件** | 进程被 `kill -9`、断电、panic | 前四层救不了时的最后手段 |

**几个实现上的取舍**（都在 `lua/core/autosave.lua` 注释里）：

- **自动保存不触发格式化**。写盘用 `noautocmd update`，绕过 conform 的 `format_on_save`。
  否则停手 250ms 就格式化一次，打字打到一半被重排，rustfmt 还会因为代码不完整直接失败。
  想格式化就手动 `:w`（那条路径照常走 conform）。
- **SIGINT 只保存、不退出**。执行 `:!cmd` 时 Ctrl+C 也会发 SIGINT，顺势退出会把编辑器一起干掉；
  而 TUI 里按 Ctrl+C 只是把字节交给 nvim 当中断键，根本不会产生 SIGINT。
- **定时器间隔可调**：`:let g:autosave_interval = 3000`（毫秒，默认 5000）。

**唯一救不了的是 `kill -9`**（信号无法被捕获）。此时交换文件是最后保障：

```bash
# 方式一：重新打开该文件，会弹 E325 ATTENTION，按提示选 (R)ecover
# 方式二：命令行直接恢复
nvim -r 文件名
# 方式三：已经在 nvim 里
:recover 文件名
```

**会话恢复**：退出时自动保存会话（`persistence.nvim`），下次启动 `:SessionLoad` 或自动恢复标签页、窗口布局、光标位置。

**`:AutoSaveAll`** — 手动保存所有已修改文件。

---

## 四、工具链

由 mason 自动管理，`ensure_installed` 中的工具缺失时会自动安装：

| 类别 | 工具 |
|---|---|
| 语言服务器 | gopls、pyright、rust-analyzer、clangd、lua-language-server、bash-language-server、docker-language-server、json-lsp、yaml-language-server、helm-ls、marksman、sqls |
| 格式化器 | stylua、clang-format、goimports、gofumpt、ruff、prettierd、yamllint、taplo |
| 调试器 | debugpy、delve、codelldb |
| 其他 | shellcheck |

手动操作：

```
:Mason            打开面板
:MasonInstall     安装工具
:MasonUpdate      更新工具
:LspInstall       安装 LSP 服务器
```

---

## 五、汉化说明

已汉化部分：

- **中文帮助文档** — vimcdoc，`:help` 全中文
- **界面提示** — 拦截 `vim.notify`，所有插件通知自动翻译
- **LSP 诊断** — 编译器报错信息逐词翻译（undefined → 未定义、type mismatch → 类型不匹配 等）
- **交互弹窗** — `vim.ui.select` 按钮（确定/取消/删除/重命名）
- **状态栏** — 模式显示为 普通/插入/可视/替换/终端
- **Telescope** — 所有搜索面板标题
- **which-key** — 快捷键分组与描述
- **快捷键描述** — 全部为中文
- **Mason / Trouble** — 面板标题

未汉化部分（受限于上游）：部分 LSP 服务器返回的完整句子仍为英文（词典可按需扩充），编辑器核心的 `:messages` 历史记录保持英文。

扩充词典：编辑 `lua/core/i18n.lua` 的 `M.dict`（通用）和 `M.lsp_dict`（诊断）。

---

## 六、常见问题

**LSP 没启动**
```
:LspInfo          查看已连接服务器
:checkhealth lsp  健康检查
```

**调试器找不到**

| 调试器 | 安装位置 | 说明 |
|---|---|---|
| codelldb | `~/.local/share/codelldb/`（wrapper 在 `~/.local/bin/codelldb`） | Rust / C / C++ |
| delve | `~/.local/share/nvim/mason/bin/dlv` | Go |
| debugpy | `~/.local/share/nvim/mason/bin/debugpy-adapter` | Python |

codelldb 不走 mason（分发包下载太慢），而是直接解压官方 `.vsix`：

```bash
# 分发包里真正的 DAP 适配器是 extension/adapter/codelldb，
# 不是 lldb/bin/lldb-server（后者只是 gdbserver，不认 --port）
~/.local/bin/codelldb --port 12345   # 能持续监听即为正常
```

**Rust 工具链**
系统需先安装 Rust（`brew install rust` 或 `rustup`），配置会自动把 `~/.cargo/bin` 加入 PATH。

**rust-analyzer**
装在 `~/.local/bin/rust-analyzer`。注意 `~/.cargo/bin/rust-analyzer` 是 rustup 的 shim，
但本机 toolchain 缺该组件，执行会报 `missing manifest in toolchain` ——
`core/paths.lua` 会显式跳过这个坏 shim。

**实时编译太吵**
保存时自动执行检查，若不想被打扰：`<leader>cz` 关闭实时编译。

---

## 七、验证状态

已在 Neovim 0.13.0-dev (macOS arm64) 上实测通过。**回归测试 78 项全通过**，
另有两组专项测试全通过（都在只加载 `core.tasks` / `core.i18n` 的最小初始化下运行，
避免 LSP 与插件干扰）：

| 专项测试 | 项数 | 内容 |
|---|---|---|
| 编译诊断去重与行号换算 | 17 | 0-based 换算、与 LSP 同行同级别去重、不同行/不同级别保留、成功后清空 |
| 编译静默行为 | 10 | `quiet`（保存触发）不弹面板不弹通知；手动执行失败弹面板并聚焦 |

另外做了「真实按 F5」的端到端验证（走 `dap.continue()`，而不是手动 `dap.run`），
五种语言均能弹出配置、建立会话、命中断点：

| 语言 | 配置来源 | 断点命中 |
|---|---|---|
| Rust | `dap.configurations.rust` | ✅ 第 3 行 |
| C | `dap.configurations.c` | ✅ 第 5 行 |
| C++ | `dap.configurations.cpp` | ✅ 第 5 行 |
| Go | `dap.configurations.go` | ✅ 第 6 行 |
| Python | `dap.configurations.python` | ✅ 第 3 行 |

### 语言服务与调试

| 项目 | 状态 | 说明 |
|---|---|---|
| Python LSP | ✅ | ruff + pyright 双服务器，诊断汉化生效 |
| Go LSP | ✅ | gopls 已连接 |
| C/C++ LSP | ✅ | clangd 已连接 |
| Rust LSP | ✅ | rust-analyzer 0.3.3097（由 rustaceanvim 独占管理，无重复客户端） |
| Python 调试 | ✅ | debugpy 1.8.22，F5 断点命中实测 |
| Go 调试 | ✅ | Delve，F5 断点命中实测 |
| C 调试 | ✅ | codelldb，F5 断点命中实测 |
| C++ 调试 | ✅ | codelldb，F5 断点命中实测 |
| Rust 调试 | ✅ | codelldb + 调试前自动 `cargo build`，F5 断点命中实测 |

### 编译与诊断

| 项目 | 状态 | 说明 |
|---|---|---|
| 配置加载 | ✅ | 无错误无警告 |
| Go 编译诊断 | ✅ | 正确定位 `main.go:6:14` |
| Rust 编译诊断 | ✅ | 正确定位 `src/main.rs:6:18` |
| 阶段编译 | ✅ | 检查/构建/运行/测试四阶段独立可执行 |
| 实时编译 | ✅ | 保存触发，1.5 秒防抖；与 LSP 诊断跨来源去重 |
| 编译诊断定位 | ✅ | 行列号已转 0-based，诊断落在真实报错行（此前整体偏移一行） |
| 诊断去重 | ✅ | 编译诊断与 LSP 同一行同级别时只保留一条，Trouble 不再三条重复 |

### 防丢与会话

| 项目 | 状态 | 实测说明 |
|---|---|---|
| 事件自动保存 | ✅ | InsertLeave / TextChanged / CursorHold(I) / FocusLost / BufLeave 全部触发 |
| 定时兜底保存 | ✅ | 5 秒一轮，`g:autosave_interval` 可调 |
| 退出前强制保存 | ✅ | 连 `:qa!` 强制退出也能落盘 |
| SIGHUP（关终端窗口） | ✅ | 信号 → 落盘 → 3 秒看门狗内 `os.exit(0)` |
| SIGTERM / SIGQUIT | ✅ | 同上；实测信号到落盘 **6 ms** |
| SIGINT | ✅ | 只保存不退出（执行 `:!cmd` 时 Ctrl+C 也会发 SIGINT，顺势退出会误伤编辑器） |
| `kill -9` 交换文件恢复 | ✅ | 重开文件弹 E325，选 `(R)` 后内容为 `UNSAVED-CRASHorig`（实测） |
| 失效进程的交换文件 | ✅ | 自定义 `SwapExists` 用 `uv.kill(pid,0)` 探活：进程已死则不拦，直接打开 |
| 活跃进程的交换文件 | ✅ | 探活成功则 `vim.v.swapchoice='e'`（只读打开），不再误删对方 swap |
| 会话持久化 | ✅ | 标签页/窗口/缓冲区完整恢复 |

### 汉化

| 项目 | 状态 | 说明 |
|---|---|---|
| 汉化：通知 | ✅ | `Saved`→`已保存`，`Loading`→`加载中` |
| 汉化：弹窗按钮 | ✅ | `Delete`→`删除`，`Cancel`→`取消` |
| 汉化：LSP 诊断 | ✅ | 300+ 词条；代码片段与 Rust 生命周期 `'static` 保持原样 |
| 汉化：编译诊断 | ✅ | `mismatched types`→`类型不匹配`（短语级优先于单词级） |
| 汉化：DAP 配置名 | ✅ | 全部配置项中文命名 |

### 已安装的工具链

| 工具 | 版本 | 路径 |
|---|---|---|
| Go | 1.27.2 | `/opt/homebrew/bin/go` |
| Rust | 1.99.1 | `~/.cargo/bin`（rustup 管理） |
| rust-analyzer | 0.3.3097-standalone | `~/.local/bin/rust-analyzer` |
| codelldb | 1.12.3 | `~/.local/share/codelldb/`（wrapper: `~/.local/bin/codelldb`） |
| clangd / gopls / pyright | mason | `~/.local/share/nvim/mason/bin` |
| delve (Go 调试) | mason | `~/.local/share/nvim/mason/bin/dlv` |
| debugpy (Python 调试) | 1.8.22 | 系统 Python + mason |
| ruff / stylua / clang-format | mason | `~/.local/share/nvim/mason/bin` |
| goimports / gofumpt / taplo | mason | `~/.local/share/nvim/mason/bin` |

### 踩过的坑（供以后排查参考）

1. **调试配置必须按 filetype 注册**（最容易踩，且测试容易漏）：
   `dap.configurations` 的 key 是**缓冲区 filetype**（`c` / `cpp` / `rust` / `go` / `python`），
   不是适配器名。写成 `dap.configurations.codelldb = {...}` 会看起来"配置已注册"，
   但按 F5 时 nvim-dap 去找 `dap.configurations.rust`，找不到 → **按 F5 毫无反应**。
   注意：只要手动 `dap.run(dap.configurations.xxx[1])` 就能跑通，所以这类错误
   用"手动跑配置"的方式测是测不出来的，必须走 `dap.continue()`。
2. **codelldb 装错文件**：分发包里 `lldb/bin/lldb-server` 只是 gdbserver，不认 `--port`；
   真正的 DAP 适配器是 `adapter/codelldb`，且需要显式 `--liblldb`。
3. **断点 verified 但不命中**：两个原因叠加 ——
   (a) codelldb 默认请求 `runInTerminal` 把程序丢到外部终端，调试器只能附加；
   配置里必须写 `terminal = 'console'`。
   (b) `/tmp` 在 macOS 是 `/private/tmp` 的符号链接，断点源路径不匹配会导致
   `Resolved locations: 0`。项目放在 `~` 下不会遇到。
4. **`args = {}` / `env = {}`**：Lua 空表会被 JSON 编码成 `[]`，codelldb 要求 map，
   报 `invalid type: sequence, expected a map`。省略这两个字段即可。
5. **dapui `size` 必须是数字**：传 `{ width, height }` 会报
   `size: expected number, got table`，且会让整个 `core.dap.setup()` 中断，
   后续所有调试配置都不注册。
6. **rustaceanvim 没有 `setup()`**：配置走 `vim.g.rustaceanvim`，
   写成 `require('rustaceanvim').setup()` 会报 `attempt to call field 'setup' (a nil value)`。
7. **同一插件起两个 lazy 条目**：给 nvim-dap 起别名 `dap-codelldb-adapter` 会让 lazy
   在 `lazy/` 下生成第二个目录，与 `nvim-dap` 并存，`require('dap')` 加载哪份不确定。
8. **汉化词典的高危词条**：`in`/`as`/`true`/`false` 这类会破坏路径与代码，
   已移除；Rust 生命周期 `'static` 需单独保护，否则被译成 `'静态的`。
   功能性单词 `is`/`the`/`this`/`that`/`of`/`to`/`from`/`by`/`with`/`for`/`while`
   也全部移除 —— 逐词替换会把整句拆成乱码，实测 rustc 的
   `expected due to this` 被译成「期望 due 到 此」。正确做法是加整句短语词条。
9. **编译器行号是 1-based，`vim.diagnostic` 是 0-based**：不转换会导致诊断标记
   画在报错行的下一行；更隐蔽的后果是「与 LSP 诊断行号永远差 1」，
   让靠行号比对做的去重逻辑一次都不命中。
10. **`rust-analyzer` 的 flycheck 与实时编译重复**：`checkOnSave = true` 时，
    同一处类型错误会被报两次（`source=rust-analyzer` 原生诊断 +
    `source=rustc` flycheck 结果），而且每次保存会跑两遍 `cargo check` 抢 target 锁。
    现已关闭 flycheck（`checkOnSave = false`），编译器级检查交给保存时的实时编译。
11. **`vim.lsp.stop_client` 不清除已发布的诊断**：测试里想隔离 LSP 必须
    `vim.diagnostic.reset(nil, bufnr)`，否则残留诊断仍会参与去重逻辑，
    让"去重是否正确"的结论完全失真。
12. **Lua 模式匹配里 `%%` 是字面量 `%`，不是转义的点号**：
    `paths.lua` 里把坏 shim 规则误写成 `'/%%.cargo/bin/...'`（两个百分号），
    实际要求路径中含一个字面 `%`，于是规则**永远匹配不上**，
    rust-analyzer 被解析成 `~/.cargo/bin` 下的 rustup shim。
    当时能用只是因为 rustup 会兜底回落到 `~/.local/bin`，属于运气。
    正确写法是 `'/%.cargo/bin/rust%-analyzer$'`（`%.` 才是字面量点号）。
13. **macOS 自带 bash 3.2 的两个坑**（写部署脚本时踩到）：
    (a) `set -u` 下写 `"...$var中文..."` 时，bash 3.2 会把紧跟变量名的中文
    全角字符当成变量名的一部分，直接报 `unbound variable`。
    **一律写成 `${var}中文`** 即可；
    (b) `printf '--version'` 会把 `--version` 当成 printf 自己的选项，
    必须写 `printf -- '%s' '--version'`。
14. **自己写的「交换文件残留」启动提示是误报源，已删除**：
    曾在 `core/session.lua` 的 `VimEnter` 里扫 `swapdir`，只要目录里有文件就
    `vim.notify` 一条「检测到 N 个未保存的交换文件」的 WARN。问题在于
    **文件数量无法区分「上次异常退出」和「另一个 nvim 正开着同一文件」**，
    多窗口编辑时每开一个新窗口都会报一次；消息又长，必然触发
    hit-enter（要按回车才继续）。现已整段移除。
    真正崩溃时不需要它：Neovim ≥0.10 自带 `swapfile` 的 `SwapExists`
    默认处理，交换文件属于**正在运行的** nvim 进程时静默跳过、属于**已死进程**
    时才弹 `E325` 对话框，判断依据比"数文件"准确得多。
    （别用 `shortmess+=A` 去压这个框 —— 那会把真崩溃的恢复提示也一起关掉。）
15. **插件用同名 augroup 把你的自动命令整组清空**（很隐蔽）：
    `Pocco81/auto-save.nvim` 内部是
    `nvim_create_augroup("AutoSave", { clear = true })`。它 `event = 'VeryLazy'`
    加载，晚于 `core/autosave.lua`，于是把我们注册的
    `CursorHoldI / FocusLost / BufLeave / VimLeavePre` **全部清掉**，
    只留它自己的 `InsertLeave / TextChanged`。
    表现是"插入模式停手不自动保存、退出不落盘"，而且**不报任何错**。
    排查方法：`nvim_get_autocmds({group='你的组名'})` 看事件是否还在。
    已移除该插件，并把组名改成独有的 `UserAutoSave`。
16. **`directory` 结尾少写 `//`，swap 文件名只用 basename**：
    写成 `~/swapdir` 时生成的是 `main.rs.swp`，不同目录的同名文件会抢同一个
    swap、互相覆盖，`SwapExists` 也会因为文件名对不上而识别不到。
    必须写 `~/swapdir//`，生成 `%Users%lixin%proj%main.rs.swp` 这种全路径转义名。
17. **libuv 的 handle 被 GC 后静默失效**：
    `local h = uv.new_signal(); h:start(...)` 这样写在函数里，函数返回后
    handle 没有引用，被 GC 回收 → 信号监听完全没反应，且**不报错**。
    定时器同理。必须用一张表持有引用（本配置里的 `keepalive`）。
18. **uv 回调里不能调 `vim.api` / `vim.cmd`**：
    `uv.new_signal()` / `uv.new_timer()` 的回调运行在 fast event 上下文，
    里面调 `vim.cmd('wall')` 会被**静默拒绝**（`pcall` 也返回 true，就是不干活）。
    实测：信号回调里直接 `vim.cmd('silent! wall')` 内容一个字都没写进去。
    必须 `vim.schedule()` 到主循环。另外 `wall` 遇到空 buffer 会报
    `E749: Empty buffer` 整体中断，逐 buffer `update` 才稳。
19. **Neovim 默认的 `SwapExists` 只读 PID，不检查进程是否还活着**：
    `runtime/lua/vim/_core/defaults.lua` 的 `nvim.swapfile` 组只要
    swap 里的 `pid > 0` 且用户相同就选 `(E)dit`，只给一条 W325。
    所以 `kill -9` 之后重开文件，它会**静默打开磁盘旧内容**，
    把交换文件里的未保存内容悄悄跳过。
    已在 `core/autosave.lua` 里覆盖：用 `uv.kill(pid, 0)` 探活，
    进程死了才 `vim.v.swapchoice = ''` 让原生对话框出现。

### 已知的上游兼容问题

- **nvim-tree + nvim 0.13-dev**：`SessionWritePre` 事件已从 Neovim 移除，但 nvim-tree 仍注册它。配置中已加兼容处理（临时屏蔽该事件注册）。
- **nvim-treesitter**：`require('nvim-treesitter.config')` 旧 API 在新版已移除，配置中做了新旧 API 自动检测。
- **dap-python**：其适配器是函数式实现，内部 `enrich_config` 负责补全 `pythonPath`。**不可覆盖 `dap.adapters.debugpy`**，否则会丢失该逻辑导致调试器无法启动。

### 网络环境备注

本机通过代理访问 GitHub 时，`git` 协议（smart HTTP）会返回 502，导致插件克隆失败。已采用的规避方案：

- 插件安装走 `codeload.github.com` 的 tarball，落到 lazy 目录后本地 `git init` 并登记到 `lazy-lock.json`
- 中文帮助 vimcdoc 安装在 `~/.local/share/nvim/plugins-local/vimcdoc`（通过 `dir` 参数指定），lazy 不再管理
- Rust 工具链使用官方 tarball 分发包手工组装

---

## 八、备份与回滚

原配置已备份至 `~/.config/nvim.backup.<时间戳>/`。回滚：

```bash
mv ~/.config/nvim ~/.config/nvim.new
mv ~/.config/nvim.backup.<时间戳> ~/.config/nvim
```

---

## 九、一键部署（全新机器）

`scripts/` 下有**三份等价实现**：`install.sh`（Shell）、`install.py`（Python）、
`install.rs`（Rust）。逻辑、步骤、日志、自检项完全一致，只是宿主语言不同 ——
新机器上哪个语言可用就用哪个。

三份都**自包含**：配置本体（`init.lua` / `lua/` / `lazy-lock.json` / `README.md` /
`快捷键手册.md` / `scripts/` 下两个 codelldb 辅助脚本，共 24 个文件）打成 tar.gz 再 base64
编码，内嵌在脚本末尾的 `payload()` / `PAYLOAD` / `PAYLOAD_B64` 常量里。运行时解到临时目录再落盘，
所以**只拷一个文件过去就能装完整套环境**。

### 9.1 选哪个版本

| 版本 | 文件 | 大小 | 运行前提 | 适合场景 |
|---|---|---|---|---|
| Shell | `install.sh` | ≈107 KB | 只需 `bash` + 系统自带 `base64/tar/curl` | **首选**，macOS 开箱即用 |
| Python | `install.py` | ≈105 KB | Python 3.8+，**只用标准库** | 想读逻辑、想改流程 |
| Rust | `install.rs` | ≈116 KB（编译后 706 KB） | 需要 `rustc` 编译一次 | 想要单文件二进制、无解释器 |

```bash
# Shell
./scripts/install.sh

# Python
python3 scripts/install.py

# Rust（先编译成二进制，之后不再需要 rustc）
rustc -O scripts/install.rs -o ~/.local/bin/nvim-install
~/.local/bin/nvim-install --check
```

### 9.2 命令行参数（三版完全一致）

```bash
./install.sh                    # 完整部署（幂等，已装的会跳过）
./install.sh --check            # 只体检，不改任何东西
./install.sh --force            # 已存在也强制重装
./install.sh --from-dir DIR     # 从本地目录部署配置（不用内嵌归档）
./install.sh --skip-plugins     # 跳过插件同步（离线时有用）
./install.sh --skip-mason       # 跳过 Mason 工具安装
./install.sh --dump-config DIR  # 只把内嵌配置解到目录 DIR，不做其他事
./install.sh --help
```

| 参数 | 作用 | 典型用途 |
|---|---|---|
| `--check` | 只读体检：打印每个工具的版本/路径，再跑一遍配置内 Lua 自检 | 装完确认、出问题先跑这个 |
| `--force` | 忽略"已存在"判断，重新下载/安装 | 怀疑安装损坏 |
| `--from-dir` | 用指定的本地目录当配置源，跳过内嵌归档 | 正在改配置，想边改边装 |
| `--dump-config` | 只解包，不安装 | 取出内嵌配置做 `diff`、或只想拿配置文件 |
| `--skip-plugins` | 不跑 `lazy.sync` | 网络差/离线 |
| `--skip-mason` | 不装 Mason 的 11 个工具 | 想先进 nvim 看看 |

### 9.3 十四个步骤

| 步骤 | 内容 | 关键说明 |
|---|---|---|
| 1 | 环境预检 | 系统/架构、Neovim ≥ 0.11、网络连通性、磁盘余量 |
| 2 | 备份 | 备份到 `~/.config/nvim.backup.<时间戳>/`，只留最近 3 份 |
| 3 | 部署配置 | 解出内嵌 tar.gz 覆盖写入 `~/.config/nvim` |
| 4 | Homebrew 依赖 | go / cmake / node |
| 5 | Rust 工具链 | rustup（失败回落 brew），并写入 shell 的 PATH |
| 6 | rust-analyzer | 装**独立二进制**到 `~/.local/bin`，绕开失效的 rustup shim |
| 7 | codelldb | 下载 vsix 解压到 `~/.local/share/codelldb`，再写 wrapper |
| 8 | Python | 确认 python3 与 venv 模块（debugpy 走 mason） |
| 9 | lazy.nvim | git 失败时自动回落 codeload 压缩包 |
| 10 | 插件同步 | `nvim --headless` 执行 `lazy.sync` |
| 11 | Mason 工具 | 11 个 LSP/DAP/格式化器，用 `vim.wait` 等待异步安装完成 |
| 12 | vimcdoc | 中文帮助文档 |
| 13 | PATH | 把 `~/.local/bin` 写进 `~/.zshrc` / `~/.bashrc`（去重） |
| 14 | 自检 | 工具版本 + 配置加载 + 自动保存五层机制 + 调试配置 |

日志同时输出到终端和：

```
~/.cache/nvim-install/install.sh.log      # Shell 版
~/.cache/nvim-install/install.py.log      # Python 版
~/.cache/nvim-install/install.rs.log      # Rust 版
```

### 9.4 自检会打印什么

`--check` 的第 14 步会在 nvim 里跑一段 Lua，实测本机输出：

```
    配置内自检：
      lazy.nvim: true
      自动保存组: 9 条 [BufLeave,CursorHold,CursorHoldI,FocusLost,InsertLeave,
                        SwapExists,TextChanged,VimLeave,VimLeavePre]
      插入模式兜底(CursorHoldI): true
      崩溃恢复(SwapExists): true
      定时保存间隔: 5000ms
      交换文件目录: /Users/lixin/.local/share/nvim/swapdir// (含 //，正确)
      调试配置: c, cpp, go, python, rust
      rust-analyzer    ~/.local/bin/rust-analyzer
      codelldb         ~/.local/bin/codelldb
      gopls            ~/.local/share/nvim/mason/bin/gopls
      ...
```

**这两行是最该看的**：

- `交换文件目录: …/swapdir//` —— 结尾必须是 `//`，否则同名文件在不同目录下会
  撞名，`SwapExists` 也就匹配不上，崩溃恢复失效（见「踩过的坑」第 16 条）。
- `自动保存组: 9 条` —— 少于 9 条说明有插件用同名 augroup 把我们的组清掉了
  （见第 15 条）。

### 9.5 自包含原理（改配置后要重新打包）

三份脚本的 payload 都是**同一份** tar.gz+base64，由 `tools/make-payload.py` 统一生成
并注入，**不要手敲 tar / base64** —— macOS 的 bsdtar 会往归档里塞 AppleDouble
（`._xxx`）文件，`__pycache__` / `*.pyc` 也容易混进去，归档凭空胖一倍还多出几十个脏文件
（这两种都实际踩过：53 个文件、146 KB）。

```bash
cd ~/.config/nvim

# 改完配置后重新打包 + 注入三份脚本（一次性）
python3 tools/make-payload.py

# 只检查内嵌载荷是否已过期（CI/提交前跑）
python3 tools/make-payload.py --check

# 只想看看归档里有什么
python3 tools/make-payload.py --dump /tmp/pv
```

`make-payload.py` 做的事：按白名单收 24 个文件（`init.lua` / `lua/` / `lazy-lock.json` /
`README.md` / `快捷键手册.md` / `scripts/install-codelldb.sh` / `scripts/build-codelldb.sh`），
`lua/langs/.gitkeep` 用来保住这个空的占位目录，权限只区分可执行与否，`gzip mtime=0` 保证**同样内容打出同样字节**，
然后替换三份脚本里的载荷区段。

注入完照例验一遍：

```bash
mkdir -p /tmp/a /tmp/b /tmp/c
./scripts/install.sh --dump-config /tmp/a  >/dev/null
python3 scripts/install.py --dump-config /tmp/b >/dev/null
rustc -O scripts/install.rs -o /tmp/i && /tmp/i --dump-config /tmp/c >/dev/null
diff -r /tmp/a /tmp/b && diff -r /tmp/a /tmp/c && echo "三版一致"
diff -r --exclude=scripts --exclude=tools --exclude='*.bak' ~/.config/nvim /tmp/a \
  && echo "与源码一致"
```

### 9.6 版本钉住的位置

```bash
CODELLDB_VERSION="1.12.3"        # codelldb
RUST_ANALYZER_TAG="2026-10-26"   # 置空则自动取 latest
```

### 9.7 改脚本时的五个易错点（都已处理，别踩回去）

1. **codelldb 的资产名随版本变**：1.12.x 是 `codelldb-darwin-arm64.vsix`
   （仓库已迁到 `vadimcn/codelldb`），旧版的 `vadimcn.vscode-lldb-*.vsix` 已不存在。
2. **rust-analyzer 不能用 `rustup component add`**：本机 toolchain 是手工组装的
   （缺 manifest），该命令会失败，所以走独立二进制；`resolve_bin()` 里还专门
   跳过了 `$HOME/.cargo/bin/rust-analyzer` 这个坏 shim。
3. **base64 参数在不同平台不同**：GNU 是 `-d`，macOS/BSD 是 `-D`。脚本用
   `printf 'aGk=' | base64 -D` 探测后再决定，别写死。
4. **Python 版做字符串模板时不能用 `%` 格式化**：内嵌的 Lua 含 `%-16s`
   这类占位符，会被 `str % args` 吃掉并抛 `TypeError`。改用
   `__OUT_FILE_PATH__` + `.replace()`。
5. **Lua 里不要在代码行尾加 `--` 注释**：`if … then f() end  -- 注释` 会把
   `end` 一起注释掉，报 `E5112: 'end' expected`；更糟的是它只在 `--check`
   时炸，不报错就只是"自检无输出"。注释另起一行。

