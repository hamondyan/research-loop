# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 这是什么

`research-loop` 是一个 **Claude Code 插件**, 为研究提供记忆辅助: 假设树状态持久化 + 格式化记录 + 上下文加载 + 跨 session 衔接。没有语言运行时, 所有产物都是 markdown(命令/skill 定义)和一个 bash hook。"代码"即 prompt 契约。

## 测试

```bash
bash tests/hook-test.sh          # SessionStart hook 单元测试(5 个用例, 唯一可自动执行的测试)
```

`tests/e2e-test.md` 是**手动**端到端测试剧本(init → 对话记录 → resume → status), 需要真实对话交互, 无法自动跑。


## 架构: 三命令 + 三原子写入函数 + 格式规范

核心模型是**中央状态唯一真相源**。理解这一点需要串读三类文件:

- **命令**(`commands/*.md`): 
  - `init` — 初始化 `.research/` 骨架(IDEA/tree/DASHBOARD + experiments/ 空目录)
  - `resume` — 读取并注入上下文(IDEA + tree + experiments 摘要, 中等详细度 ~1000-2000 字)
  - `status` — 纯读打印 DASHBOARD + 统计
  
  命令只读写 `.research/` 文件, 不调子 agent, 不做自动编排。

- **Skill**(`skills/hypothesis-tree/SKILL.md`): 
  - 规定 tree.md / experiments/Exxx.md / DASHBOARD.md 格式(Status 词汇/编号规则/append-only)
  - 定义对话中的写入触发机制(用户明确指示才写, 三种形式)
  - 定义三个原子写入操作:
    - `appendHypothesis(tree.md, 描述, 父节点)` — 追加假设
    - `createExperimentRecord(Exxx.md, 描述, 关联假设)` — 创建实验记录
    - `updateExperimentResult(Exxx.md, 结果, 结论)` — 更新结果并联动 tree
  - 定义 `updateDashboard()` 自动维护一致性
  
  这些函数不暴露为命令, 只在对话中 agent 按需调用。

- **SessionStart Hook**(`hooks/session-start`): 进入仓库时自动探测 `.research/DASHBOARD.md`, 有则提示"活跃研究存在, 用 /research-loop:resume 加载上下文"。


## 状态目录 `.research/`(运行时产物, 不在本仓库)

```
IDEA.md          # 北极星: 动机 + 核心问题, 稳定极少改
tree.md          # 假设树: 层级 + Status + Evidence 指针, 单一真相源
DASHBOARD.md     # 仪表盘: Active 假设清单 + 下一步建议(hook 探测入口)
experiments/     # 实验详细记录, 一次实验一个 Exxx.md
  E001.md
  E002.md
```

v1.0 不再使用 `decisions/` 和 `artifacts/` 子目录。

### 假设树格式 (tree.md)

```markdown
# Hypothesis Tree

## H1: [假设描述]
Status: 待验
Evidence: (empty)

### H1.1: [子假设]
Status: 进行中
Evidence: E001

## H2: [假设描述]
Status: 被支持
Evidence: E003, E005
```

**Status 词汇**(中文 4 选 1): `待验` / `进行中` / `被支持` / `被推翻`

**编号规则**: H1 / H1.1 / H1.1.1 最多三层, 永不重用

### 实验记录格式 (experiments/Exxx.md)

```markdown
# Exxx: [假设 ID] - [简短动作描述]

**Hypothesis**: [假设 ID] [假设文本]
**Date**: [YYYY-MM-DD]
**Status**: 待验 | 进行中 | 已完成

## 实验设计
**目标**: [要验证什么]
**方法**: [怎么做]
**预期**: [期望结果]

## 执行记录
[用户手动做实验的关键步骤/命令/观察]

## 结果
**数据**: [metrics / 观察]
**结论**: [支持/推翻/不确定 + 理由]

## 影响
[对假设树的影响]
```

### DASHBOARD 格式

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

## 关键不变量

- **append-only**: Evidence 字段只增不删; 假设 ID 一旦分配永不重用(即使被推翻); experiments 编号文件永不删改。
- **Status 词汇一致**: 4 个中文词汇, 不混用英文。
- **Status 不加粗**: `Status: 待验`, 不写 `**Status: 待验**`。
- **唯一写盘点**: 只有主 PI(对话中)写 `.research/`, 格式化逻辑保证一致性。三个原子写入函数实现在 SKILL 或可选的 `scripts/helpers/*.sh`。

