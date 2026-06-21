# research-loop v1.0 架构转型设计: 从自动循环到研究记忆辅助系统

- 日期: 2026-06-20
- 状态: 待批准
- 形态: research-loop 插件 v1.0(架构根本性转变)
- 范围: 砍掉自动编排引擎(60-70% 代码), 保留格式化记录 + 上下文加载, 从"自动研究工具"转型为"记忆辅助系统"

## 1. 动机与核心转变

### 1.1 需求变化

**旧定位(v0.4/v0.5)**: 全自动研究循环工具 — 用户敲一个 `/research-loop:step` 命令, 插件自动跑 designer→critic→implementer→runner→analyst 全流程, 自动落盘结果。

**新定位(v1.0)**: 研究记忆辅助系统 — 用户手动做实验/分析, agent 在对话中帮忙格式化记录到 `.research/`, 并能随时加载历史上下文继续工作。插件不再主动跑任何自动化。

### 1.2 核心转变

| 维度 | v0.4/v0.5 | v1.0 |
|---|---|---|
| **触发方式** | 用户敲命令 → 插件自动跑完整循环 | 用户对话中明确指示 → agent 按需写入 |
| **编排引擎** | Workflow + 6 个子 agent + 执行后端 | 无编排, 3 个原子写入函数 |
| **用户角色** | 发起者(敲命令等结果) | 主导者(做实验, 让 agent 记录) |
| **插件职责** | 自动化研究助手 | 结构化笔记系统 + 上下文加载器 |
| **代码规模** | ~3000 行 | ~800-1000 行(减少 70%) |

### 1.3 保留的价值

尽管砍掉自动化, 以下设计仍保留:
- **.research/ 格式规范**: Status 词汇映射/tree.md 层级结构/append-only 原则/实验记录模板 — 这些让 agent 能准确理解历史
- **三个核心命令**: init(初始化) / status(汇报) / resume(注入上下文)
- **格式守护**: 写入逻辑保证一致性, 避免手动编辑格式混乱导致 agent 读不懂

---

## 2. 架构设计

### 2.1 旧架构(v0.4/v0.5, 要砍掉的)

```
主控 PI → /research-loop:step 选待验假设
  → Workflow(workflows/step.js) 编排
    → 6 个子 agent(agents/*.md): designer/critic/implementer/runner/analyst/adversary
    → 执行后端(scripts/backends/local.sh): detached 挂起命令
  → 自动落盘 `.research/`(experiments/Exxx.md / decisions/Dxxx.md / tree.md)
```

**砍掉的组件**:
- `commands/step.md` — 整个自动验证循环命令
- `agents/*.md`(7 个) — 子 agent 契约
- `workflows/step.js` — 编排脚本
- `scripts/backends/local.sh` — 执行后端
- `skills/research-orchestration/SKILL.md` — 自动编排方法论
- `decisions/` 子目录 — 与 experiments 重复
- `artifacts/` 子目录 — 产物放外面或用户自定义

### 2.2 新架构(v1.0, 记忆辅助)
```
用户手动做实验/分析
  ↓ (对话中)
Agent 识别记录需求("记下这个假设" / "更新实验结果")
  → 调内部辅助函数(helpers, 非子 agent)
    → 格式化 + 写入 `.research/`(tree.md / experiments/Exxx.md / DASHBOARD.md)

用户敲 /research-loop:resume
  → 读 IDEA.md + tree.md + experiments/*.md
  → 拼成结构化上下文(~1000-2000 字)
  → 注入对话, agent 带着记忆继续工作

用户敲 /research-loop:status
  → 读 DASHBOARD.md + 扫 tree.md 统计
  → 打印当前状态
```

**保留并改造的组件**:
- `commands/init.md` — 简化: 只建骨架, 删 scout/codebase 准备
- `commands/resume.md` — 重写: 读取+注入上下文
- `commands/status.md` — 保持: 纯读汇报
- `skills/hypothesis-tree/SKILL.md` — 改造: 加写入操作指南
- `.research/` 格式规范 — 保留核心结构, 简化实验模板

**新增组件**:
- 三个原子写入函数(在 SKILL 或 scripts/helpers/ 实现):
  - `appendHypothesis(tree.md, 假设描述, 父节点)` — 追加假设
  - `createExperimentRecord(Exxx.md, 实验描述, 关联假设)` — 创建实验记录
  - `updateExperimentResult(Exxx.md, 结果, 结论)` — 更新结果并联动 tree
- 这些函数不暴露为用户命令, 只在对话中 agent 按需调用

---

## 3. 目录结构与文件格式

### 3.1 `.research/` 目录树(精简版)

```
.research/
├── IDEA.md                    # 研究动机(一句话 + 详细背景)
├── tree.md                    # 假设树: 层级 + Status + Evidence 指针
├── DASHBOARD.md               # 仪表盘: Active 假设 + 下一步
└── experiments/               # 实验详细记录(一次实验一个文件)
    ├── E001.md
    ├── E002.md
    └── ...
```

**砍掉**: `decisions/`(与 experiments 重复), `artifacts/`(产物放外面)

### 3.2 IDEA.md 格式(复用 v0.4)

```markdown
# Research IDEA

**一句话**: [研究的核心问题, 50 字内]

## 动机

[详细背景: 为什么做这个研究, 当前痛点, 预期目标, 200-500 字]
```

**写入**: init 时生成, 之后很少改

### 3.3 tree.md 格式(复用 v0.4 Status 词汇)

```markdown
# Hypothesis Tree

- H1: [假设描述] (Status: 待验, Evidence: (empty))
  - H1.1: [子假设] (Status: 进行中, Evidence: E001)
- H2: [假设描述] (Status: 被支持, Evidence: E003, E005)
```

**关键约定**(继承 v0.4):
- **Status 词汇**: `待验` / `进行中` / `被支持` / `被推翻`(中文 4 选 1)
- **Evidence**: 指向 experiments/Exxx.md, 只增不删(append-only)
- **层级**: H1 / H1.1 / H1.1.1 最多三层
- **Status 不加粗**: `Status: 待验`, 不写 `**Status: 待验**`

**写入时机**: 
- init 建空树或根据 IDEA 生成 1-2 个初始假设
- 用户说"记下这个假设"→ `appendHypothesis()` 追加
- 实验结论出来 → `updateExperimentResult()` 联动更新 Status+Evidence

### 3.4 DASHBOARD.md 格式(复用 v0.4 canonical)

```markdown
# Research Dashboard

**IDEA**: [IDEA 一句话]
**Active**: [待验+进行中数量] hypotheses | **Last**: [YYYY-MM-DD]

## Active Hypotheses
- H1: [描述] (待验)
- H1.1: [描述] (进行中)

## Next Steps
1. [下一步建议]
```

**关键约定**:
- 只含 `待验`/`进行中` 假设, `被支持`/`被推翻` 不进(已结案)
- `**Last**` 在 `**Active**` 行内, 不独立

**写入时机**: init 初版 + 假设状态变化时刷新

### 3.5 experiments/Exxx.md 格式(简化 v0.4 模板)

```markdown
# Exxx: [假设 ID] - [简短动作描述]

**Hypothesis**: [hypothesis_id] [hypothesis_text]
**Date**: [YYYY-MM-DD]
**Status**: 待验 | 进行中 | 已完成

## 实验设计

**目标**: [要验证什么]
**方法**: [怎么做, 变量/对照组]
**预期**: [期望结果]

## 执行记录

[用户手动做实验的关键步骤/命令/观察]

## 结果

**数据**: [metrics / 观察现象]
**结论**: [支持/推翻/不确定 + 理由]

## 影响

[对假设树的影响: 哪个假设状态要变, 是否派生新假设]
```

**简化点**(相比 v0.4):
- 删 critic/implementer/adversary/backend/句柄 等自动化字段
- 保留核心四段: 设计/执行/结果/影响
- 允许增量补充(不要求一次性填满)

**写入时机**: 
- 用户说"记录实验" → `createExperimentRecord()` 生成骨架
- 实验过程中 → 对话中逐步补充"执行记录"段
- 完成后 → `updateExperimentResult()` 填"结果"段并联动 tree

### 3.6 编号规则(继承 v0.4)

- **假设 ID**: H1, H1.1, H2, ...(层级编号, 永不重用)
- **实验 ID**: E001, E002, ...(递增, 扫 experiments/ 最大+1, append-only)
- **日期**: ISO 8601 `YYYY-MM-DD`

---

## 4. 三个命令的行为

### 4.1 `/research-loop:init <idea_file>`

**职责**: 初始化 `.research/` 骨架, 研究开始时调一次

**行为**:
1. 检查 `.research/` 是否已存在, 有则报错(防覆盖)
2. 创建目录: `mkdir -p .research/experiments`
3. 生成 IDEA.md(从 idea_file 提取)
4. 生成 tree.md(空树或推导 1-2 个初始假设, 用户确认)
5. 生成 DASHBOARD.md 初版
6. 输出: "✓ 研究记忆系统已初始化, 下一步: /research-loop:resume 或开始对话"

**写入**: IDEA.md / tree.md / DASHBOARD.md

### 4.2 `/research-loop:status`

**职责**: 打印当前状态, 纯读, 零副作用

**行为**:
1. 检查 DASHBOARD.md, 不存在则提示 init
2. 读取并打印 DASHBOARD.md 全文
3. 追加统计(扫描生成, 不写文件): 总假设数(待验/进行中/被支持/被推翻分布) + 实验数

**读取**: DASHBOARD.md / tree.md / experiments/(计数)

### 4.3 `/research-loop:resume`

**职责**: 加载 `.research/` 状态, 注入上下文到对话

**行为**:
1. 检查 `.research/`, 不存在则提示 init
2. 读取并解析:
   - IDEA.md → 动机
   - tree.md → 假设树(所有假设+Status+Evidence)
   - experiments/*.md → 扫描, 提取摘要(Hypothesis/Date/结论, 不读全文)
3. 拼成结构化上下文字符串(中等详细度, ~1000-2000 字):
   ```markdown
   # 研究上下文
   ## 研究动机
   [IDEA 一句话 + 核心背景]
   ## 假设树
   [层级+Status+Evidence]
   ## 实验历史(摘要)
   - E001 (日期): 验证 H1, 结论=支持, 因为 [一句话]
   ...
   ## 当前状态
   [Active 假设 + 下一步]
   ```
4. 注入对话(system reminder 或对话开头插入)
5. 输出: "✓ 研究上下文已加载, [总假设数]个假设 | [实验数]个实验"

**读取**: IDEA.md / tree.md / experiments/*.md / DASHBOARD.md

**关键**: 摘要而非全文(控制 token), 中等详细度(符合用户选的"中量")

---

## 5. 对话中的按需写入规则

### 5.1 触发机制: 用户明确指示

**原则**: agent 不主动/不猜测/不自动后台写, 只在用户**明确指示**时写

**明确指示三种形式**:
1. **直接命令**: "记下这个假设 H3", "把实验写进 E004"
2. **确认式**: agent 问"要不要记录到 tree.md?", 用户说"好"
3. **隐含但明确**: 结构化讨论后说"保存"/"记录"/"写下来"

**不触发**(避免误判):
- 只是讨论/头脑风暴, 没说"记下来" → 不写
- 探索性"我觉得可能是 X" → 不写, 除非明确说"加到假设树"
- agent 自己推测 → 不写, 必须用户确认

### 5.2 三个原子写入操作

#### 5.2.1 `appendHypothesis(tree.md, 描述, 父节点)`

**触发**: "记下这个假设: [描述]" / "把 X 加到假设树"

**行为**:
1. 读 tree.md 解析现有 ID
2. 确定新 ID: 指定父节点则 H1.N, 否则顶层 HM
3. 追加行: `- HX: [描述] (Status: 待验, Evidence: (empty))`
4. 刷新 DASHBOARD
5. 输出: "✓ 假设 HX 已记录, Status: 待验"

**边界**: 描述太模糊先提炼, 默认顶层除非明确说"子假设"

#### 5.2.2 `createExperimentRecord(描述, 关联假设)`

**触发**: "帮我记录这次实验" / "创建实验记录"

**行为**:
1. 扫 experiments/ 取最大编号+1 → Exxx
2. 生成 Exxx.md 骨架(填用户提供信息, 其余待补充)
3. 关联假设 `待验`→`进行中`(在 tree.md)
4. 刷新 DASHBOARD
5. 输出: "✓ 实验 Exxx 已创建, 你可以随时让我更新段落"

**边界**: 骨架后允许增量补充(手动编辑或对话中追加)

#### 5.2.3 `updateExperimentResult(Exxx.md, 结果, 结论)`

**触发**: "E003 结果出来了, [数据], 结论是支持 H1"

**行为**:
1. 读 Exxx.md 填 `## 结果` 段
2. 更新 Status: `进行中`→`已完成`
3. 如果结论是 `支持`/`推翻`, 联动 tree.md:
   - 假设 Status: `进行中`→`被支持`/`被推翻`
   - Evidence 追加 Exxx
4. 刷新 DASHBOARD
5. 输出: "✓ E003 结果已记录, H1→被支持 (Evidence: E001, E003)"

**边界**: 结论 `不确定` 则假设保持 `进行中`

#### 5.2.4 `updateDashboard()`(自动调用)

其他三个操作调用, 扫 tree.md 统计 Active 假设, 重写 DASHBOARD.md

### 5.3 格式守护

所有写入:
1. 遵循 §3 格式规范(Status 词汇/编号/不加粗)
2. Append-only(ID 永不重用, Evidence 只增)
3. 原子性(全成功或全失败)
4. 确认反馈(明确告知写了什么)

### 5.4 实现方式

**位置**: `skills/hypothesis-tree/SKILL.md` 或 `scripts/helpers/*.sh`

**不拆子 agent**, 主 PI 直接调用工具函数

---

## 6. 迁移路径

### 6.1 代码迁移

1. **归档 v0.4/v0.5**:
   ```bash
   git branch -m feat/v0.4-workflow-runtime archive/auto-research-loop
   ```
   保留历史不删

2. **新分支从 main**:
   ```bash
   git checkout main
   git checkout -b feat/research-memory-system
   ```
   全新开始, 不 cherry-pick(旧代码偏离目标太远)

### 6.2 文件处理

**完全删除**: agents / workflows / scripts/backends / tests/backend* / tests/e2e-v0.5* / skills/research-orchestration

**保留改造**: init/status/resume 命令 + hypothesis-tree SKILL + README/CLAUDE.md

**新增**: helpers 函数 + 本设计文档 + 实现计划

### 6.3 用户数据兼容

- **向后兼容读**: resume/status 能读旧格式(即使有 decisions/artifacts)
- **不删旧目录**: 插件不动 decisions/artifacts, 用户自行归档
- **init 不建旧目录**: v1.0 只建 experiments

### 6.4 代码量

- v0.4/v0.5: ~3000 行
- v1.0 预计: ~800-1000 行(减 70%)

---

## 7. 交付清单

### 7.1 修改/新增

```
commands/init.md              # 简化: 删 scout/args 准备
commands/resume.md            # 重写: 读取+注入上下文
commands/status.md            # 保持(几乎不改)
skills/hypothesis-tree/SKILL.md  # 加写入操作指南
scripts/helpers/              # 新增: 三个原子函数(可选, 或在 SKILL 实现)
README.md                     # 重写: 从"自动工具"改"记忆系统"
CLAUDE.md                     # 重写: 删 Workflow/agents 架构
.claude-plugin/plugin.json    # 0.5.0 → 1.0.0, 改 description
docs/specs/2026-06-20-research-memory-system-design.md  # 本文档
```

### 7.2 删除

```
commands/step.md
agents/*.md (7 个)
workflows/step.js
scripts/backends/local.sh
tests/backend-local-test.sh
tests/e2e-v0.5-resumable.md
skills/research-orchestration/
```

### 7.3 验证

- 手动 walkthrough: init → 手动编辑 → resume 正确读取
- 对话测试: "记下假设 H3" → tree.md 正确追加
- 格式校验: 写入后的文件符合 §3 规范

---

## 8. 关键不变量(继承 v0.4)

- **append-only**: 假设/实验 ID 永不重用, Evidence 只增不删
- **Status 词汇一致**: 4 个中文词汇, 不混用英文
- **Status 不加粗**: 纯文本格式
- **三套词汇映射**(如果需要多语言, 保留映射表)
- **唯一写盘点**: 只有主 PI(对话中)写 `.research/`, 格式化逻辑保证一致性

---

## 9. 与 v0.4/v0.5 的对比总结

| 维度 | v0.4/v0.5 | v1.0 |
|---|---|---|
| **定位** | 全自动研究工具 | 记忆辅助系统 |
| **触发** | 用户敲命令 | 对话中明确指示 |
| **编排** | Workflow + 6 子 agent | 无, 3 个原子函数 |
| **用户角色** | 发起者 | 主导者 |
| **代码量** | ~3000 行 | ~800-1000 行 |
| **目录结构** | IDEA/tree/DASHBOARD + experiments/decisions/artifacts | IDEA/tree/DASHBOARD + experiments |
| **命令** | init/step/resume/status | init/resume/status |
| **写入逻辑** | step 自动落盘 | 对话中按需写入 |
| **格式规范** | Status 词汇/append-only/编号(保留) | 同左(继承) |

---

## 10. 风险与缓解

| 风险 | 缓解 |
|---|---|
| agent 误判"用户是否想记录" | 明确触发规则 + 确认式交互("要不要记录?") |
| 用户手动编辑破坏格式 | resume 前校验格式, 报错提示修复; 或提供 `validate` 命令检查 |
| 对话中写入失败(权限/磁盘满) | 原子性保证 + 清晰错误提示, 不留半截 |
| 旧用户不理解新定位 | README 显著说明转变 + 提供迁移指南 + 归档分支保留旧版 |

---

## 11. 未来扩展(不在 v1.0 范围)

- **选择性注入**: resume 时用户指定只注入相关假设(如"只注入 H1 分支")
- **多语言词汇**: 支持英文 Status 词汇, 自动映射
- **协作模式**: 多人共同维护 `.research/`, 冲突检测
- **可视化**: 假设树图形化展示(不在插件范围, 可以外部工具读 tree.md 渲染)

这些不在 v1.0 做, 保持 YAGNI。
