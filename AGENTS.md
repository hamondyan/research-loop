# CLAUDE.md

This file provides guidance when working in this repository.

## 这是什么

`research-loop` 是一个 Claude/Codex 兼容的 skill 插件。核心能力是研究记忆辅助: 假设树状态持久化、实验记录、上下文加载和按需写入。

没有语言运行时; 主要产物是 markdown skill 和插件 manifest。"代码"即 prompt 契约。

## 当前架构

核心模型是中央状态唯一真相源。当前只维护 skill 入口:

- `skills/research-loop-init/SKILL.md`: 初始化 `.research/` 骨架。
- `skills/research-loop-resume/SKILL.md`: 读取并注入研究上下文。
- `skills/research-loop-status/SKILL.md`: 只读打印 `DASHBOARD.md`。
- `skills/hypothesis-tree/SKILL.md`: 规定 tree / experiment / dashboard 格式和按需写入规则。

插件 manifest 分开维护:

- `.claude-plugin/plugin.json`: Claude 发现插件。
- `.codex-plugin/plugin.json`: Codex 发现插件, 必须包含 `"skills": "./skills/"`。

不要恢复 `commands/*.md` 或 hook 作为主入口; 这样会导致 Claude/Codex 双端重复维护。

## 测试

```bash
bash tests/structure-test.sh
```

`tests/e2e-test.md` 是手动端到端测试剧本, 需要真实对话交互, 无法自动跑。

## 状态目录 `.research/`

运行时产物不在本仓库内:

```text
IDEA.md
tree.md
DASHBOARD.md
experiments/
  E001.md
  E002.md
```

## 假设树格式

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

状态词汇只允许: `待验` / `进行中` / `被支持` / `被推翻`。

## 实验记录格式

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

## 关键不变量

- Evidence 字段只增不删。
- 假设 ID 一旦分配永不重用。
- experiments 编号文件永不删改。
- `tree.md` 的 `Status:` 不加粗。
- 只有主对话 agent 写 `.research/`; 不用子 agent 直接写状态文件。
- 实验设计以决策价值和性能为导向, 不做低信息增益的穷举式验证。
