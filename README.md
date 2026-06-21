# research-loop

研究记忆辅助系统 — 用户手动做实验/分析, agent 在对话中帮忙格式化记录到 `.research/`, 并能随时加载历史上下文继续工作。

## 功能

- **假设树状态管理**: 用 `.research/tree.md` 分层追踪研究假设(H1/H1.1/...)及其状态(待验/进行中/被支持/被推翻)
- **实验记录**: 每个实验一个 `.research/experiments/Exxx.md`, 记录设计/执行/结果/影响
- **格式化写入**: agent 在对话中按需写入(用户明确指示才写), 保证格式一致性
- **上下文加载**: `/research-loop:resume` 注入假设树+动机+实验历史摘要(中等详细度, ~1000-2000 字), agent 带着记忆继续工作
- **跨 session 衔接**: 状态持久化到 `.research/` 目录, SessionStart hook 自动探测活跃研究并提示

## 安装

复制插件目录到 Claude Code 插件路径:

```bash
cp -r research-loop ~/.claude/plugins/
```

重启 Claude Code 或重新加载配置。SessionStart hook 会在进入仓库时自动探测 `.research/DASHBOARD.md` 并注入研究上下文。

## 使用

### 初始化研究项目

```bash
/research-loop:init <idea文件>
```

读取 idea 文件, 通过对话提炼动机/假设, 建立初始假设树, 创建 `.research/` 结构。只在研究开始时调一次。

### 对话中记录假设和实验

**记录假设**:
```
用户: "我觉得模型在负样本上过拟合了, 记下这个假设"
Agent: ✓ 假设 H1 已记录到 tree.md (Status: 待验)
```

**记录实验**:
```
用户: "帮我记录这次实验, 验证 H1"
Agent: ✓ 实验 E001 已创建 (experiments/E001.md)

(用户手动做实验...)

用户: "E001 结果出来了, accuracy 从 0.85 降到 0.72, 结论是支持 H1"
Agent: ✓ E001 结果已记录, H1→被支持 (Evidence: E001)
```

### 加载上下文继续工作

```bash
/research-loop:resume
```

加载 `.research/` 状态(IDEA + tree + experiments 摘要), 注入对话上下文(~1000-2000 字), agent 带着记忆继续分析和记录。

### 查看状态

```bash
/research-loop:status
```

打印 `.research/DASHBOARD.md` 全文(只读, 零副作用)。

## 状态目录结构

```
.research/
├── IDEA.md             # 研究动机和核心问题
├── tree.md             # 假设树(分层 + 状态追踪, 单一真相源)
├── DASHBOARD.md        # 当前进展仪表盘(hook 探测入口)
└── experiments/        # 实验详细记录(一次实验一个文件)
    ├── E001.md
    └── E002.md
```

v1.0 不再使用 `decisions/` 和 `artifacts/` 子目录(与 experiments 重复/产物放外面)。

## 子 Agent

| Agent | 职责 |
|---|---|
| scout | 调研文献和代码库, 定位相关实现位置(按需调用) |
| designer | 针对假设设计判别实验, 返回变量/指标/判据/命令 |
| implementer | 按设计实现代码改动并自检 |
| runner | 在 slurm 计算节点执行命令, 返回指标和产出 |
| analyst | 解读结果, 判定 supported/refuted/uncertain |

## 对抗审校 (v0.3)

## 关键不变量

- **append-only**: 假设/实验 ID 一旦分配永不重用(即使被推翻), Evidence 只增不删
- **Status 词汇**: `待验` / `进行中` / `被支持` / `被推翻` (中文 4 选 1, 不混用英文)
- **Status 不加粗**: 纯文本 `Status: 待验`, 不写 `**Status: 待验**`
- **唯一写盘点**: 只有主 PI(对话中)写 `.research/`, 格式化逻辑保证一致性

## 依赖

- Claude Code(支持 plugin / command / skill / SessionStart hook)
- bash(可选, 如果用辅助脚本实现写入函数)
- (可选)MCP llm-chat + 外部 OpenAI 兼容 API, 用于 adversary 跨模型对抗审校(v0.3 遗留, v1.0 未实现)

状态以纯 markdown 持久化; 写入逻辑在 `skills/hypothesis-tree/SKILL.md` 或可选的 `scripts/helpers/*.sh`。

## License

MIT License - 详见 LICENSE 文件
