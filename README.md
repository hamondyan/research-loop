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

## 对抗审校 (v0.3)

### Critic Agent: 实验设计预检

在 designer 生成实验设计后, critic agent 进行 4 维度审查:
- **可判别性**: 实验能区分假设成立/不成立吗?
- **变量数**: 变量 ≤ 3 吗? 交互效应可解释吗?
- **judge_criteria**: 是否含具体阈值和统计检验?
- **commands**: 路径完整、资源预算合理吗?

若 Round 1 FAIL, designer 收到反馈重设计 (Round 2). 两轮后仍 FAIL 则终止, 用户可添加 `## Override` 段落强制继续.

### Adversary Analyst: 跨模型验证

primary analyst (Claude) 判定结果后, adversary analyst (通过 MCP llm-chat 调用 DeepSeek/GPT 等) 独立验证.

**Reviewer Independence**: adversary 只读截断版 experiments/Exxx.md (不含 primary 的 reasoning), 避免被引导.

**Verdict 合并**:
- 一致 → 采信 primary
- 分歧 + adversary 高置信度 (≥0.7) → 降级为 uncertain
- 分歧 + adversary 低置信度 → 采信 primary, 附警告

### 安装 MCP llm-adversary

见 `mcp-servers/llm-chat/README.md`.

## 断点续跑 (v0.3)

### Journal 状态机

每次 step 执行时, 主控在 `.research/experiments/Exxx.journal` (JSONL 格式) 记录各步骤完成状态:
- designer round 1/2 done
- critic round 1/2 done
- implementer done
- runner command 0/1/2 done/fail
- analyst-primary/adversary done
- finalize done / terminate

### Resume 逻辑

下次 `/research-loop:step` 时:
1. 检测当前待验假设是否有未完成 journal
2. 若有, 从首个 non-done 步骤续跑 (跳过已完成的 designer/implementer/runner[0-N])
3. 若无, 正常创建新实验

**场景示例**: runner 第 2 条命令超时 → 用户修复 slurm 配置 → 再次 step → 跳过 designer/critic/implementer/runner[0-1], 从 runner[2] 续跑.

## 状态词汇

- 假设状态(tree.md / DASHBOARD): `待验` / `进行中` / `被支持` / `被推翻`
- analyst 判定(JSON verdict): `supported` / `refuted` / `uncertain`, 由主控 PI 映射为中文假设状态

## 依赖

- Claude Code(支持 plugin / agent / skill / SessionStart hook)

无额外语言运行时依赖, 状态以纯 markdown 持久化。

## License

MIT License - 详见 LICENSE 文件
