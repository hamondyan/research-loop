# research-loop

研究记忆辅助系统: 用户手动做实验/分析, agent 在对话中帮忙格式化记录到 `.research/`, 并能随时加载历史上下文继续工作。

## 功能

- **假设树状态管理**: 用 `.research/tree.md` 分层追踪研究假设及其状态。
- **实验记录**: 每个实验一个 `.research/experiments/Exxx.md`, 记录设计、执行、结果和影响。
- **格式化写入**: 用户明确要求记录时, agent 按规范写入。
- **上下文加载**: `research-loop-resume` skill 加载动机、假设树和实验历史摘要。
- **双端兼容**: Claude 和 Codex 共用 `skills/*/SKILL.md`, 只分别维护插件 manifest。

## 安装

Claude:

```bash
cp -r research-loop ~/.claude/plugins/
```

Codex:

```bash
cp -r research-loop ~/plugins/
```

## 使用

### 初始化研究项目

对 agent 说:

```text
使用 research-loop-init, 从 idea.md 初始化研究记忆。
```

它会读取 idea 文件, 通过对话提炼动机、假设和成功判据, 然后创建 `.research/` 结构。只在研究开始时调用一次。

### 对话中记录假设和实验

记录假设:

```text
我觉得模型在负样本上过拟合了, 记下这个假设。
```

记录实验:

```text
帮我记录这次实验, 验证 H1。
```

更新结果:

```text
E001 结果出来了, accuracy 从 0.85 降到 0.72, 结论是支持 H1。
```

### 加载上下文继续工作

对 agent 说:

```text
使用 research-loop-resume 恢复当前研究上下文。
```

### 查看状态

对 agent 说:

```text
使用 research-loop-status 查看当前研究状态。
```

## 状态目录结构

```text
.research/
├── IDEA.md
├── tree.md
├── DASHBOARD.md
└── experiments/
    ├── E001.md
    └── E002.md
```

## Skills

- `research-loop-init`: 初始化 `.research/`。
- `research-loop-resume`: 加载研究上下文。
- `research-loop-status`: 只读打印 `DASHBOARD.md`。
- `hypothesis-tree`: 规定假设树和实验记录的读写格式。

## 关键不变量

- 假设和实验 ID 一旦分配永不重用。
- Evidence 只增不删。
- 假设状态只使用 `待验` / `进行中` / `被支持` / `被推翻`。
- `tree.md` 中状态写成纯文本 `Status: 待验`, 不写 `**Status: 待验**`。