# research-loop 设计文档

- 日期: 2026-06-16
- 状态: 已批准, 待进入实现规划
- 形态: 独立 Claude Code 插件 `research-loop`

## 1. 背景与动机

科研迭代的本质是一个闭环: idea → 假设 → 规划 → 跑实验 → 验证结果 → 修订规划。当前痛点是这个闭环的状态散落在人脑和零散笔记里, 跨 session 容易断裂, 多 agent 协作时记忆容易发散。

本插件给科研迭代过程建一个"持久化状态 + 多 agent 协作"的脚手架, 让研究状态可追溯、跨 session 不中断、重规划有据可查。

设计不从零造轮子, 而是组合已有基础设施: superpowers 的 SessionStart hook 注入机制、`dispatching-parallel-agents` 的隔离子 agent 模式、Claude Code 的插件/skill/command 体系。

## 2. 核心设计决策

| 决策 | 选择 | 理由 |
|---|---|---|
| 状态存放位置 | 仓库内 `.research/`, 随研究分支 git 提交 | 与被验证代码强绑定, 一次 commit 同时锁定代码与实验记录, 支持 git 回溯, 可复现 |
| 多 agent 模型 | 主控 PI + 无状态专家子 agent | 中央状态唯一真相源, 记忆零发散, 匹配 superpowers 隔离上下文模式 |
| 状态建模 | 假设树 | 匹配决策价值导向, 重规划闭环可追溯, 防穷举 |
| Hook 加载策略 | 自动探测分支 + 注入一行提示, 不自动加载状态内容 | 零被动开销且不会忘, 加载与否完全可控 |
| 打包形态 | 独立插件 | 可移植、可分享、自带 hook 与命令、版本化 |

## 3. 状态目录 schema

研究状态放在仓库根的 `.research/` 目录, 随研究分支提交:

```
.research/
├── IDEA.md                    # 北极星: 动机 / 核心假设 / 成功判据. 稳定, 极少改
├── tree.md                    # 假设树: 节点=可证伪子假设, 状态∈{待验,进行中,被支持,被推翻}
├── DASHBOARD.md               # 紧凑仪表盘: 活跃假设 + 最近验证 + 下一步. 主控每次收工时重写
├── experiments/
│   └── E001-<slug>.md         # 单个实验: 关联假设 ID / 设置 / 命令 / 结果 / 结论
├── decisions/
│   └── D001-<slug>.md         # 决策日志: 为何推翻 / 新增假设, 为何改规划
└── artifacts/                 # gitignore: ckpt / 原始日志 / eval 原始输出. 状态文件只记录路径与关键指标
```

设计要点:

- `tree.md` 是单一真相源。每个假设有稳定 ID(H1, H1.1, H2 ...)、状态、支撑/反对它的实验 ID 列表。
- 实验和决策都是 append-only 编号文件, 永不删改, 保证 git 可追溯。
- `artifacts/` 进 `.gitignore`, 大文件不污染仓库; 状态文件里只记录路径和关键指标。
- 规划不是独立文件, 而是从假设树状态派生(哪些假设待验 → 下一步做什么), 体现决策价值导向。

## 4. 多 agent 协作架构

### 4.1 角色划分

主控 PI(主会话)是唯一读写 `.research/` 的角色, 驱动整个研究闭环, 维护假设树和仪表盘。它不亲自跑长任务, 而是构造最小 brief 派发给专家子 agent。

专家子 agent 无状态, 每次新开, 不继承主会话上下文:

| 子 agent | 职责 | 输入(brief 切片) | 结构化返回 |
|---|---|---|---|
| scout(调研) | 查文献 / 查 codebase, 定位相关实现 | 一个待调研问题 + 范围 | 结论 + 关键路径/引用, 不返回文件堆 |
| designer(设计) | 针对某假设设计实验方案 | 假设 ID + 内容 + 约束 | 实验设计(变量/指标/judge 判据) |
| implementer(实现) | 写/改代码实现某实验 | 实验设计 + 相关文件路径 | diff 摘要 + 自检结果 |
| runner(跑实验) | 在计算节点跑实验, 收集指标 | 命令 + 资源要求 | 关键指标 + artifact 路径, 不返回原始日志 |
| analyst(分析) | 解读结果, 判断假设支持/推翻 | 实验结果 + 关联假设 | 判定 + 置信度 + 是否触发重规划 |

### 4.2 核心数据流(一个研究循环)

```
主控读 DASHBOARD/tree → 选一个待验假设
  → designer 设计实验 → 主控写 experiments/Exxx.md(待跑)
  → implementer 实现 → runner 在计算节点跑 → 回填指标
  → analyst 判定 → 主控更新 tree.md(假设状态) + 写 decisions/Dxxx.md
  → 主控重写 DASHBOARD.md → 决定下一个假设 / 重规划
```

### 4.3 记忆分配

- 中央状态 `.research/` 是唯一持久化真相源, 只有主控读写。
- 子 agent 零持久记忆, 每次拿主控构造的最小 brief, 做完返回结构化结果即销毁, 不存在多份发散记忆。
- 子 agent 的"记忆"就是主控喂给它的那块状态切片, 主控是记忆的唯一编排者。

子 agent 无状态的理由: 匹配 superpowers 的 `dispatching-parallel-agents` 模式, 隔离上下文、防止污染主会话、防止多 agent 状态发散。子 agent 越无历史包袱、brief 越精确, 结果越可控。

### 4.4 并行约束

多个独立假设的实验可并行派发(独立 runner/implementer), 但写回 `.research/` 永远串行经过主控, 避免写冲突。

## 5. Hook 与跨 session 衔接

### 5.1 SessionStart hook(轻探测)

hook 脚本逻辑(每次 session startup/clear/compact 触发):

1. 判断当前目录是否 git 仓库, 取当前分支名。
2. 检测 `.research/DASHBOARD.md` 是否存在。
3. 存在则注入一行提示 + 极短摘要(假设树根问题 + 活跃假设数 + 最近验证日期), 提示用 `/research:resume` 加载; 不存在则静默退出 exit 0。
4. 注入内容走 `hookSpecificOutput.additionalContext`(Claude Code 格式)。

注入示例(仅此而已, 不含状态全文):

```
<research-context>
当前分支 starVLA_dev 有进行中的研究: "<IDEA 一句话>"
活跃假设 3 个, 最近验证 2026-06-15. 用 /research:resume 加载完整状态.
</research-context>
```

设计要点:

- hook 不读 tree.md/experiments 全文, 只读 DASHBOARD.md 顶部几行(主控预生成的摘要区), token 代价恒定且极小。
- hook 是插件自带的 `hooks/hooks.json` + 脚本, 安装插件即生效, 无需手动改 settings.json。
- Let it crash 原则: hook 脚本严格 `set -euo pipefail`, 但探测失败(非仓库/无状态)是正常情况走静默 exit 0, 不算错误。

### 5.2 跨 session 衔接完整链路

```
session 结束: 主控收工时已把最新状态写进 .research/ 并重写 DASHBOARD.md
  ↓ (git commit 随分支)
新 session 启动: hook 探测到 → 注入一行提示
  ↓
你/主控: /research:resume → 主控读取 DASHBOARD + tree → 恢复完整研究上下文
  ↓
继续循环
```

状态落盘在 `.research/`(随 git 提交), hook 负责"提醒别忘了", `/research:resume` 负责"按需拉回上下文", 三者解耦。

## 6. 插件结构、命令与自适应重规划

### 6.1 插件目录结构

```
research-loop/
├── .claude-plugin/plugin.json     # 清单
├── hooks/
│   ├── hooks.json                 # SessionStart 注册
│   └── session-start              # 轻探测脚本(无扩展名, 同 superpowers 约定)
├── commands/
│   └── research/                  # 命名空间子目录, 调用形如 /research:init
│       ├── init.md                # /research:init: 从 idea 文件初始化 .research/
│       ├── resume.md              # /research:resume: 加载状态恢复上下文
│       ├── step.md                # /research:step: 跑一轮假设验证循环
│       └── status.md              # /research:status: 打印仪表盘
├── skills/
│   ├── research-orchestration/    # 主控 PI 方法论(核心 SKILL.md)
│   └── hypothesis-tree/           # 假设树读写规范 SKILL.md
└── agents/
    ├── scout.md  designer.md  implementer.md  runner.md  analyst.md
```

### 6.2 命令职责

- `/research:init <idea文件>`: 主控读 idea, 与用户对话提炼出 IDEA.md + 初始假设树, 落盘 `.research/`。此时建议确认是否新开研究分支, 遵守"禁止擅自开分支", 必经用户同意。
- `/research:resume`: 读 DASHBOARD + tree, 恢复上下文, 报告当前在哪、下一步是什么。
- `/research:step`: 跑一个完整假设验证循环(designer→implementer→runner→analyst→更新状态), 收工时重写 DASHBOARD。
- `/research:status`: 只读打印仪表盘, 零副作用。

### 6.3 自适应重规划机制

重规划不是另起炉灶, 而是假设树状态变化的自然结果:

```
analyst 判定某假设 → 写 decisions/Dxxx.md
  ├─ 被支持 → 树上标记, 派生下游假设(它解锁了什么新问题?)
  ├─ 被推翻 → 树上标记, 触发重规划: 这条死了, 剪枝; 它影响哪些兄弟/父假设?
  └─ 不确定 → 设计更强的判别实验
  ↓
主控重写 DASHBOARD: 重新排下一步该验哪个假设
  ↓ (中止判据, 遵守决策价值导向)
若活跃假设全部边际增益 < 阈值 / 已排除方向 → 主控提示"建议收敛/换方向", 不穷举
```

设计要点:

- 重规划有据可查, 每次规划变动都对应一条 `decisions/Dxxx.md`, 说明"哪个实验结果推翻了哪个假设, 所以规划怎么变"。
- 内置中止判据(对接决策价值导向): 连续多组无提升且已排除方向、边际提升 < 0.5%、资源/收益失衡时, 主控主动提示收敛, 而不是无脑往下跑。
- `/research:step` 是无状态子 agent 编排的落地点, 内部就是 4.2 那条数据流。

## 7. 验证策略

- hook 脚本: 单测探测逻辑(仓库/非仓库/有状态/无状态四种情况, 确保静默退出正确)。
- 命令与 skill: 按 superpowers 的 `writing-skills` 方法, 用压力场景跑子 agent, 看不带 skill 时是否发散, 带上后是否合规。
- 端到端: 用一个玩具假设走完整 init→step→resume 循环, 验证状态落盘与恢复。

## 8. 非目标(YAGNI)

- 不做角色持久记忆(各 agent 独立记忆), 避免发散。
- 不做 hook 全量状态注入, 避免 token 膨胀。
- 不做 `.research/` 之外的独立规划文件, 规划从假设树派生。
- 不做与当前研究目标无关的重构。
