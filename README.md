# research-loop

科研 idea 全生命周期管理插件, 为 Claude Code 提供假设树状态管理、多 agent 协作与跨 session 衔接能力。

## 功能

- **假设树状态管理**: 用 `.research/tree.md` 分层追踪研究假设(H1/H1.1/...)及其状态(待验/进行中/被支持/被推翻)
- **跨 session 衔接**: 持久化状态到 `.research/` 目录, 配合 SessionStart hook 自动探测活跃研究, 支持暂停与恢复
- **多 agent 协作**: 主控 PI 编排 scout/designer/implementer/runner/analyst 五个无状态子 agent, 中央状态唯一真相源
- **自适应重规划**: 根据 analyst 判定动态更新假设树, 触发剪枝与新假设派生

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

读取 idea 文件, 通过对话提炼动机/假设/成功判据, 建立初始假设树, 创建 `.research/` 结构。

### 恢复已有研究

```bash
/research-loop:resume
```

加载 `.research/` 状态(IDEA + tree + DASHBOARD), 解析活跃假设, 输出研究摘要和下一步建议。

### 执行单步迭代

```bash
/research-loop:step
```

主控 PI 选取待验假设 → designer 设计实验 → implementer 实现代码 → runner 在计算节点执行 → analyst 判定结果 → 更新假设树和决策记录。无需参数, 自动从 tree.md 选取下一个待验假设。

### 查看状态

```bash
/research-loop:status
```

打印 `.research/DASHBOARD.md` 全文(只读, 零副作用)。

## 状态目录结构

```
.research/
├── IDEA.md             # 研究动机、核心问题、成功判据
├── tree.md             # 假设树(分层 + 状态追踪, 单一真相源)
├── DASHBOARD.md        # 当前进展仪表盘(hook 探测入口)
├── experiments/        # 实验记录
│   ├── E001_*.md
│   └── E002_*.md
├── decisions/          # 决策记录(假设状态变更时)
│   └── D001_*.md
└── artifacts/          # 实验产出(日志/图表/checkpoint)
    └── .gitkeep
```

## 子 Agent

| Agent | 职责 |
|---|---|
| scout | 调研文献和代码库, 定位相关实现位置(按需调用) |
| designer | 针对假设设计判别实验, 返回变量/指标/判据/命令 |
| implementer | 按设计实现代码改动并自检 |
| runner | 在 slurm 计算节点执行命令, 返回指标和产出 |
| analyst | 解读结果, 判定 supported/refuted/uncertain |

## 状态词汇

- 假设状态(tree.md / DASHBOARD): `待验` / `进行中` / `被支持` / `被推翻`
- analyst 判定(JSON verdict): `supported` / `refuted` / `uncertain`, 由主控 PI 映射为中文假设状态

## 依赖

- Claude Code(支持 plugin / agent / skill / SessionStart hook)

无额外语言运行时依赖, 状态以纯 markdown 持久化。

## License

MIT License - 详见 LICENSE 文件
