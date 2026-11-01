-- ============================================================
-- 汉化核心模块
-- 作用：把 Neovim / 插件的英文提示翻译成中文
-- 策略：1) 拦截 vim.notify  2) 翻译 LSP 诊断信息  3) 覆盖 ui.select/ui.input
-- ============================================================

local M = {}

-- ------------------------------------------------------------
-- 1. 通用词典：英文 -> 中文
-- ------------------------------------------------------------
M.dict = {
  -- 通知类
  ['saved'] = '已保存',
  ['Saved'] = '已保存',
  ['No write since last change'] = '没有未保存的改动',
  ['E212: No such file or directory'] = '文件或目录不存在',
  ['E37: No write since last change (add ! to override)'] = '文件已修改，未保存（加 ! 可强制退出）',
  ['Press ENTER or type command to continue'] = '按回车或输入命令继续',
  ['Press ENTER or type command to continue:'] = '按回车或输入命令继续：',

  -- 通用动作
  ['Quit'] = '退出',
  ['quit'] = '退出',
  ['Cancel'] = '取消',
  ['cancel'] = '取消',
  ['Delete'] = '删除',
  ['delete'] = '删除',
  ['Rename'] = '重命名',
  ['Copy'] = '复制',
  ['Paste'] = '粘贴',
  ['Save'] = '保存',
  ['Save as'] = '另存为',
  ['Open'] = '打开',
  ['Close'] = '关闭',
  ['Yes'] = '是',
  ['No'] = '否',
  ['Confirm'] = '确认',
  ['Error'] = '错误',
  ['Warning'] = '警告',
  ['Info'] = '提示',
  ['Success'] = '成功',
  ['Failed'] = '失败',
  ['Loading'] = '加载中',
  ['Done'] = '完成',

  -- 插件状态
  ['Installing'] = '正在安装',
  ['installed'] = '已安装',
  ['updated'] = '已更新',
  ['Updated'] = '已更新',
  ['Error while running lua'] = '执行 Lua 时出错',
  ['failed'] = '失败',
  ['Success!'] = '成功！',

  -- 搜索/查找
  ['Pattern not found'] = '未找到匹配内容',
  ['No matches found'] = '没有找到匹配项',
  ['search hit BOTTOM'] = '搜索到达底部',
  ['search hit TOP'] = '搜索到达顶部',

  -- 跳转/跳转列表
  ['No more items'] = '没有更多项',
  ['No matching item'] = '没有匹配项',
  ['More items'] = '更多项',
  ['All'] = '全部',
}

-- ------------------------------------------------------------
-- 2. LSP 诊断信息词典（针对常见编译器报错）
-- ------------------------------------------------------------
M.lsp_dict = {
  ['cannot find'] = '找不到',
  ['not found'] = '未找到',
  ['expected'] = '期望',
  ['unexpected'] = '意外的',
  ['unresolved'] = '未解析',
  ['unused'] = '未使用',
  ['missing'] = '缺失',
  ['invalid'] = '无效',
  ['undefined'] = '未定义',
  ['unknown'] = '未知',
  ['mismatched'] = '不匹配',
  ['redundant'] = '多余的',
  ['deprecated'] = '已废弃',
  ['unreachable'] = '不可达',
  ['duplicate'] = '重复',
  ['misplaced'] = '位置错误',
  ['incompatible'] = '不兼容',
  ['immutable'] = '不可变',
  ['overflow'] = '溢出',
  ['underflow'] = '下溢',
  ['division by zero'] = '除以零',
  ['cannot assign'] = '无法赋值',
  ['cannot move'] = '无法移动',
  ['borrowed value'] = '借用的值',
  ['does not live long enough'] = '生命周期不足',
  ['use of moved value'] = '使用了已移动的值',
  ['type mismatch'] = '类型不匹配',
  ['cannot find crate'] = '找不到 crate',
  ['unresolved import'] = '未解析的导入',
  ['no field'] = '没有该字段',
  ['no method'] = '没有该方法',
  ['method not found'] = '找不到方法',
  ['value has no field'] = '该值没有字段',
  ['takes'] = '需要参数',
  ['argument'] = '参数',
  ['this function takes'] = '此函数需要',
  ['but it was given'] = '但传入了',
  ['expected type'] = '期望类型',
  ['found'] = '实际为',
  ['missing field'] = '缺少字段',
  ['unclosed delimiter'] = '未闭合的分隔符',
  ['mismatched types'] = '类型不匹配',
  ['mismatched type'] = '类型不匹配',
  ['mismatched closing delimiter'] = '分隔符不匹配',
  ['mismatched closing'] = '闭合符号不匹配',
  ['incompatible types'] = '不兼容的类型',
  ['cannot borrow'] = '无法借用',
  ['borrow of moved value'] = '借用了已移动的值',
  ['does not have a field named'] = '没有名为',
  ['field'] = '的字段',
  ['method'] = '的方法',
  ['trait bound'] = 'trait 约束',
  ['is not satisfied'] = '未满足',
  ['the trait'] = '该 trait',
  ['is not implemented'] = '未实现',
  ['cannot find macro'] = '找不到宏',
  ['cannot find attribute'] = '找不到属性',
  ['unresolved module'] = '未解析的模块',
  ['unresolved function'] = '未解析的函数',
  ['syntax error'] = '语法错误',
  ['invalid escape sequence'] = '无效的转义序列',
  ['unexpected token'] = '意外的符号',
  ['indentation'] = '缩进',
  ['import'] = '导入',
  ['package'] = '包',
  ['function'] = '函数',
  ['variable'] = '变量',
  ['constant'] = '常量',
  ['type'] = '类型',
  ['struct'] = '结构体',
  ['enum'] = '枚举',
  ['module'] = '模块',
  ['class'] = '类',
  ['object'] = '对象',
  ['parameter'] = '参数',
  ['return'] = '返回',
  ['error'] = '错误',
  ['warning'] = '警告',
  ['note'] = '注意',
  ['help'] = '帮助',
  ['and'] = '且',
  ['or'] = '或',
  ['but'] = '但是',
  ['if'] = '如果',
  -- ----------------------------------------------------------
  -- 以下功能性单词已刻意移除，不要再加回来：
  --   is / the / this / that / of / to / from / by / with / for / while
  -- 原因：这些词单独逐词替换会把整句拆成中英混杂的乱码。
  -- 实测 rustc 的提示 "expected due to this" 被译成「期望 due 到 此」，
  -- 比不翻译更难读。正确做法是加「整句短语」词条（见下方 phrases），
  -- 让长短语先匹配，而不是靠单字拼装。
  -- ----------------------------------------------------------
  -- 常见报错片段补充
  ['expected due to this'] = '由此导致',
  ['due to this'] = '由此导致',
  ['because it is borrowed'] = '因为它已被借用',
  ['because it was mutably borrowed'] = '因为它已被可变借用',
  ['is not assignable to'] = '不能赋值给',
  ['declared type'] = '声明类型',
  ['assignable to'] = '可赋值给',
  ['expected'] = '期望',
  ['found'] = '实际为',
  ['argument'] = '参数',
  ['arguments'] = '参数',
  ['access'] = '访问',
  ['accessed'] = '被访问',
  ['is not accessed'] = '未被访问',
  ['assignable'] = '可赋值',
  ['declared'] = '声明的',
  ['more than'] = '多于',
  ['fewer than'] = '少于',
  ['characters'] = '个字符',
  ['resolved'] = '已解析',
  ['visibility'] = '可见性',
  ['private'] = '私有的',
  ['public'] = '公有的',
  ['protected'] = '受保护的',
  ['abstract'] = '抽象的',
  ['final'] = '最终的',
  ['static'] = '静态的',
  ['const'] = '常量',
  ['let'] = 'let',
  ['mut'] = '可变',
  ['ref'] = '引用',
  ['option'] = '选项',
  ['none'] = '无',
  ['some'] = '有',
  ['ok'] = '成功',
  ['err'] = '错误',
  ['value'] = '值',
  ['values'] = '值',
  ['key'] = '键',
  ['keys'] = '键',
  ['index'] = '索引',
  ['length'] = '长度',
  ['size'] = '大小',
  ['name'] = '名称',
  ['names'] = '名称',
  ['path'] = '路径',
  ['paths'] = '路径',
  ['file'] = '文件',
  ['files'] = '文件',
  ['directory'] = '目录',
  ['line'] = '行',
  ['lines'] = '行',
  ['column'] = '列',
  ['range'] = '范围',
  ['match'] = '匹配',
  ['pattern'] = '模式',
  ['regex'] = '正则',
  ['syntax'] = '语法',
  ['format'] = '格式',
  ['version'] = '版本',
  ['feature'] = '特性',
  ['trait'] = 'trait',
  ['impl'] = '实现',
  ['self'] = '自身',
  ['clone'] = '克隆',
  ['copy'] = '复制',
  ['drop'] = '丢弃',
  ['move'] = '移动',
  ['borrow'] = '借用',
  ['lifetime'] = '生命周期',
  ['generic'] = '泛型',
  ['closure'] = '闭包',
  ['iterator'] = '迭代器',
  ['async'] = '异步',
  ['await'] = '等待',
  ['spawn'] = '派生',
  ['thread'] = '线程',
  ['mutex'] = '互斥锁',
  ['channel'] = '通道',
  -- Go 特有
  ['cannot use'] = '不能使用',
  ['as'] = '作为',
  ['value'] = '值',
  ['variable declaration'] = '变量声明',
  ['assignment'] = '赋值',
  ['argument'] = '参数',
  ['untyped'] = '无类型',
  ['constant'] = '常量',
  ['missing'] = '缺失',
  ['return'] = '返回',
  ['statement'] = '语句',
  ['expression'] = '表达式',
  ['declaration'] = '声明',
  ['conversion'] = '转换',
  ['cannot convert'] = '无法转换',
  ['does not implement'] = '未实现',
  ['requires'] = '需要',
  ['pointer'] = '指针',
  ['nil'] = '空值',
  ['map'] = '映射',
  ['slice'] = '切片',
  ['interface'] = '接口',
  ['struct'] = '结构体',
  ['func'] = '函数',
  ['string'] = '字符串',
  ['int'] = '整数',
  ['bool'] = '布尔',
  ['float'] = '浮点',
  ['byte'] = '字节',
  ['rune'] = '字符',

  -- === 通用补充（诊断高频词） ===
  ['types'] = '类型',
  ['scope'] = '作用域',
  ['reference'] = '引用',
  ['bounds'] = '边界',
  ['out of bounds'] = '越界',
  ['out of range'] = '超出范围',
  ['overflowed'] = '已溢出',
  ['attempt to'] = '尝试',
  ['cannot be'] = '不能',
  ['must be'] = '必须是',
  ['should be'] = '应为',
  ['is required'] = '是必需的',
  ['not allowed'] = '不允许',
  ['not supported'] = '不支持',
  ['truncated'] = '被截断',
  ['shadowed'] = '被遮蔽',
  ['redefinition'] = '重复定义',
  ['already defined'] = '已定义',
  ['no matching'] = '没有匹配的',
  ['does not exist'] = '不存在',
  ['may not be'] = '可能不是',
  ['possibly unbound'] = '可能未绑定',
  ['is not defined'] = '未定义',
  ['possibly undefined'] = '可能未定义',
  ['is not callable'] = '不可调用',
  ['not callable'] = '不可调用',
  ['has no member'] = '没有成员',
  ['member'] = '成员',
  ['attribute'] = '属性',
  ['property'] = '属性',
  ['keyword'] = '关键字',
  ['identifier'] = '标识符',
  ['literal'] = '字面量',
  ['operator'] = '运算符',
  ['operand'] = '操作数',
  ['loop'] = '循环',
  ['block'] = '代码块',
  ['condition'] = '条件',
  ['branch'] = '分支',
  ['macro'] = '宏',
  ['variant'] = '变体',
  ['tuple'] = '元组',
  ['vector'] = '向量',
  ['array'] = '数组',
  ['integer'] = '整数',
  ['bits'] = '位',
  ['segmentation fault'] = '段错误',
  ['stack overflow'] = '栈溢出',
  ['null pointer'] = '空指针',
  ['uninitialized'] = '未初始化',
  ['unused variable'] = '未使用的变量',
  ['unused import'] = '未使用的导入',
  ['dead code'] = '死代码',
  ['never used'] = '从未使用',
  ['implicit'] = '隐式',
  ['explicit'] = '显式',
  ['cast'] = '类型转换',
  ['deprecated since'] = '自以下版本废弃',
  ['since'] = '自',
  ['platform'] = '平台',
  ['architecture'] = '架构',
  ['in this scope'] = '在此作用域中',
  ['in the current scope'] = '在当前作用域中',
  ['not a type'] = '不是类型',
  ['cannot infer'] = '无法推断',
  ['type annotation'] = '类型标注',
  ['no method named'] = '没有名为以下名称的方法',
  ['no field named'] = '没有名为以下名称的字段',
  ['this expression'] = '此表达式',
  ['this statement'] = '此语句',
  ['is private'] = '是私有的',
  ['unexpected end of file'] = '文件意外结束',
  ['expected token'] = '期望标记',
  ['expected one of'] = '期望以下之一',
  ['not enough arguments'] = '参数不足',
  ['too many arguments'] = '参数过多',
  ['invalid syntax'] = '无效语法',
  ['malformed'] = '格式错误',

  -- === 第二批补充 ===
  ['cannot'] = '无法',
  ['valid'] = '有效的',
  ['not assignable'] = '不可赋值',
  ['definition'] = '定义',
  ['usage'] = '用法',
  ['occurrence'] = '出现',
  ['receiver'] = '接收者',
  ['caller'] = '调用方',
  ['call'] = '调用',
  ['invoke'] = '调用',
  ['instantiate'] = '实例化',
  ['initialize'] = '初始化',
  ['declare'] = '声明',
  ['define'] = '定义',
  ['override'] = '重写',
  ['implement'] = '实现',
  ['inherit'] = '继承',
  ['annotation'] = '标注',
  ['decorator'] = '装饰器',
  ['generic type'] = '泛型类型',
  ['type parameter'] = '类型参数',
  ['return type'] = '返回类型',
  ['input'] = '输入',
  ['output'] = '输出',
  ['result'] = '结果',
  ['failed'] = '失败',
  ['failure'] = '失败',
  ['success'] = '成功',
  ['unsupported'] = '不支持',
  ['unsafe'] = '不安全',
  ['safe'] = '安全',
  ['required'] = '必需',
  ['optional'] = '可选',
  ['unknown type'] = '未知类型',
  ['cannot resolve'] = '无法解析',
  ['resolve'] = '解析',
  ['circular'] = '循环',
  ['dependency'] = '依赖',
  ['conflict'] = '冲突',
  ['ambiguous'] = '有歧义',
  ['multiple'] = '多个',
  ['single'] = '单个',
  ['empty'] = '空',
  ['non-empty'] = '非空',
  ['at least'] = '至少',
  ['at most'] = '至多',
}

-- ------------------------------------------------------------
-- 3. 翻译函数
-- ------------------------------------------------------------
-- 预排序的诊断词条（按词长降序，避免短词先替换导致漏匹配）
M.sorted_lsp_keys = {}
for k in pairs(M.lsp_dict) do
  table.insert(M.sorted_lsp_keys, k)
end
table.sort(M.sorted_lsp_keys, function(a, b)
  return #a > #b
end)

-- 注意：逐词替换（M.lsp_dict）只能用于 LSP 诊断信息，
-- 绝不能用于通用消息——否则路径中的 "in"/"of"/"on" 会被翻译，
-- 导致 /Users/lixin/.config 变成 /Users/lix在/.c在fig 之类的破坏。

--- 通用翻译：仅整句精确匹配（安全，不会破坏路径/代码）
function M.translate(text)
  if type(text) ~= 'string' or text == '' then
    return text
  end

  -- 整句精确匹配
  if M.dict[text] then
    return M.dict[text]
  end

  -- 整句含匹配（仅长度 > 4 的词条，避免误伤短词）
  for en, zh in pairs(M.dict) do
    if #en > 4 and text:find(en, 1, true) then
      return (text:gsub(en, zh, 1))
    end
  end

  return text
end

--- 诊断专用翻译：整句匹配 + 逐词替换（仅用于 LSP/编译诊断）
-- 策略：只翻译引号外的说明文字，引号内（用户代码片段）保持原样
function M.translate_diagnostic(text)
  if type(text) ~= 'string' or text == '' then
    return text
  end

  -- 先尝试整句精确匹配
  if M.dict[text] then
    return M.dict[text]
  end

  -- Rust 生命周期保护：'a / 'static / '_ 这类单引号标注不成对，
  -- 会被当成普通文本逐词翻译（实测 'static -> '静态的，破坏诊断可读性）。
  -- 先替换成占位符，翻译完再还原。
  local lifetimes = {}
  text = text:gsub("'(%a[%w_]*)", function(ident)
    lifetimes[#lifetimes + 1] = "'" .. ident
    return '\1LIFE' .. #lifetimes .. '\1'
  end)

  -- 拆分：引号/反引号内的内容视为代码片段，不翻译
  -- 支持 " ' ` 三种引号
  local segments = {}
  local pos = 1
  local pattern = '([\'"`])([^\'"`]*)([%\'"`])'
  while true do
    local s, e, q1, body, q2 = text:find(pattern, pos)
    if not s then
      break
    end
    if s > pos then
      table.insert(segments, { code = false, text = text:sub(pos, s - 1) })
    end
    table.insert(segments, { code = true, text = text:sub(s, e) })
    pos = e + 1
  end
  if pos <= #text then
    table.insert(segments, { code = false, text = text:sub(pos) })
  end

  -- 逐词替换（按词长降序，避免短词先替换导致漏匹配）
  local function translate_plain(chunk)
    local out = chunk
    local changed = false
    for _, k in ipairs(M.sorted_lsp_keys) do
      local esc = k:gsub('([^%w])', '%%%1')
      local pat = '%f[%w]' .. esc .. '%f[%A]'
      -- 用小写探测命中（词典键都是小写）
      if out:lower():match(pat) then
        -- 1) 全小写形式
        out = out:gsub(pat, function()
          return M.lsp_dict[k]
        end)
        -- 2) 首字母大写形式（LSP 消息常以大写开头，如 "Out of range"）
        --    只做小写探测会导致这类消息漏译，退化成单词级替换
        local cap = k:sub(1, 1):upper() .. k:sub(2)
        if cap ~= k then
          local esc_cap = cap:gsub('([^%w])', '%%%1')
          out = out:gsub('%f[%w]' .. esc_cap .. '%f[%A]', function()
            return M.lsp_dict[k]
          end)
        end
        changed = true
      end
    end
    return changed and out or chunk
  end

  local parts = {}
  for _, seg in ipairs(segments) do
    if seg.code then
      table.insert(parts, seg.text) -- 代码片段原样保留
    else
      table.insert(parts, translate_plain(seg.text))
    end
  end
  local result = table.concat(parts)

  -- 还原 Rust 生命周期
  if #lifetimes > 0 then
    result = result:gsub('\1LIFE(%d+)\1', function(i)
      return lifetimes[tonumber(i)] or ''
    end)
  end
  return result
end

-- ------------------------------------------------------------
-- 4. 拦截 vim.notify —— 所有插件的提示都走这里
-- ------------------------------------------------------------
function M.setup_notify()
  local orig_notify = vim.notify
  local notify_on = true

  vim.notify = function(msg, level, opts)
    if not notify_on then
      return orig_notify(msg, level, opts)
    end
    local text = type(msg) == 'string' and msg or vim.inspect(msg)

    -- 标题翻译
    local title = opts and opts.title
    if title then
      local zh_title = M.dict[title] or title
      opts = vim.tbl_extend('force', opts or {}, { title = zh_title })
    end

    local zh = M.translate(text)

    -- 级别对应的中文标签
    local level_tag = {
      [vim.log.levels.ERROR] = '错误',
      [vim.log.levels.WARN] = '警告',
      [vim.log.levels.INFO] = '提示',
      [vim.log.levels.DEBUG] = '调试',
      [vim.log.levels.TRACE] = '追踪',
    }
    local tag = level_tag[level]

    if tag and not zh:find(tag, 1, true) then
      zh = ('[%s] %s'):format(tag, zh)
    end

    return orig_notify(zh, level, opts)
  end

  -- 提供关闭开关，个别插件提示需要原文时可用
  vim.notify_raw = orig_notify
  vim.g.notify_disabled = false
end

-- ------------------------------------------------------------
-- 5. 翻译 vim.ui.select / vim.ui.input 的按钮文案
-- ------------------------------------------------------------
function M.setup_ui()
  local orig_select = vim.ui.select
  vim.ui.select = function(items, opts, on_choice)
    local zh_items = vim.tbl_map(function(item)
      local it = vim.deepcopy(item)
      if it[2] then
        it[2] = M.dict[it[2]] or it[2]
      end
      return it
    end, items)
    return orig_select(zh_items, opts, on_choice)
  end
end

-- ------------------------------------------------------------
-- 6. 翻译 LSP 诊断信息
-- ------------------------------------------------------------
-- 说明：不包装 vim.diagnostic.handlers（0.13 中 handlers 结构已变，
-- 包装会破坏 show/hide 的调用约定）。改为在诊断设置后翻译消息。
function M.setup_diagnostics()
  -- 翻译诊断消息：拦截 vim.diagnostic.set 的入参
  local orig_set = vim.diagnostic.set
  vim.diagnostic.set = function(namespace, bufnr, diagnostics, opts)
    if type(diagnostics) == 'table' then
      for _, diag in ipairs(diagnostics) do
        if type(diag) == 'table' and type(diag.message) == 'string' then
          diag.message = M.translate_diagnostic(diag.message)
        end
      end
    end
    return orig_set(namespace, bufnr, diagnostics, opts)
  end

  -- LSP 客户端推送的诊断也要翻译：拦截 on_diagnostics 回调
  local orig_on_diagnostics = vim.lsp.handlers['textDocument/publishDiagnostics']
  if orig_on_diagnostics then
    vim.lsp.handlers['textDocument/publishDiagnostics'] = function(err, result, ctx, cfg)
      if result and type(result.diagnostics) == 'table' then
        for _, diag in ipairs(result.diagnostics) do
          if type(diag.message) == 'string' then
            diag.message = M.translate_diagnostic(diag.message)
          end
        end
      end
      return orig_on_diagnostics(err, result, ctx, cfg)
    end
  end
end

-- ------------------------------------------------------------
-- 7. 翻译 :messages 历史里的英文
-- ------------------------------------------------------------
function M.setup_messages()
  local orig_echo = vim.api.nvim_echo
  vim.api.nvim_echo = function(chunks, history, opts)
    for _, chunk in ipairs(chunks) do
      if type(chunk[1]) == 'string' then
        chunk[1] = M.translate(chunk[1])
      end
    end
    return orig_echo(chunks, history, opts)
  end
end

-- ------------------------------------------------------------
-- 8. 翻译内置命令提示（如 "Press ENTER"）
-- ------------------------------------------------------------
function M.setup_messages_cmd()
  -- 命令名必须以大写字母开头，故用 Help 作为中文帮助入口
  vim.api.nvim_create_user_command('Help', function()
    vim.cmd('help')
  end, { desc = '打开中文帮助文档' })
end

function M.setup()
  M.setup_notify()
  M.setup_ui()
  M.setup_diagnostics()
  M.setup_messages()
  M.setup_messages_cmd()
end

return M
