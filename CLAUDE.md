# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 这是什么

`research-loop` 是一个 **Claude Code 插件**, 为科研 idea 提供全生命周期管理: 假设树状态持久化 + 多 agent 协作 + 跨 session 衔接。没有语言运行时, 所有产物都是 markdown(命令/agent/skill 定义)和一个 bash hook。"代码"即 prompt 契约。

## 测试

```bash
bash tests/hook-test.sh          # SessionStart hook 单元测试(5 个用例, 唯一可自动执行的测试)
```

`tests/e2e-test.md` 是**手动**端到端测试剧本(init → status → resume → step), 其中 step 需要真实 codebase 和 slurm 计算节点, 无法自动跑。

本地验证 hook 输出:

```bash
CLAUDE_PLUGIN_ROOT=$(pwd) ./hooks/session-start   # 在带 .research/DASHBOARD.md 的 git 仓库里运行
```

无 build / lint 步骤。改完 prompt 文件无需编译。

## 架构: 主控 PI + 无状态子 agent

核心模型是**中央状态唯一真相源**。理解这一点需要串读三类文件:

- **主控 PI**(主会话): 唯一读写 `.research/` 的角色。方法论在 `skills/research-orchestration/SKILL.md`。它不跑长任务, 只构造**最小 brief** 派发给子 agent, 解析返回的 JSON 后**增量落盘**。
- **5 个无状态子 agent**(`agents/*.md`): scout(按需调研) / designer(设计实验) / implementer(写代码) / runner(slurm 上执行) / analyst(判定结果)。每个 agent 文件定义其 Input/Output JSON 契约。子 agent 不继承主会话上下文, 用 `isolation="worktree"` 隔离。
- **命令**(`commands/*.md`): `step` 是唯一编排子 agent 的命令(完整 9 步流水线); `init`/`resume`/`status` 只读写 `.research/` 文件, 不调子 agent。

`step` 流水线(见 `commands/step.md`): 选待验假设 → designer → 写 `experiments/Exxx.md` → implementer → runner(逐条命令) → 回填指标 → analyst → 翻译 verdict 更新 tree → 写 `decisions/Dxxx.md` → 重写 DASHBOARD。

子 agent 的 brief 模板在 `step.md` 内联(权威版本)和 `SKILL.md` 内各有一份, 改契约时**两处都要同步**, 还要对齐对应的 `agents/*.md`。

## 状态目录 `.research/`(运行时产物, 不在本仓库)

```
IDEA.md          # 北极星: 动机/核心假设/成功判据, 稳定极少改
tree.md          # 假设树, 单一真相源(只有主控 PI 读写)
DASHBOARD.md     # 紧凑仪表盘, SessionStart hook 的探测入口
experiments/Exxx.md   # append-only 编号文件, 永不删改
decisions/Dxxx.md     # 仅假设状态变更(supported/refuted)时创建
artifacts/       # gitignore, 大文件; 状态文件只记路径+关键指标
```

`.research/` 是插件**作用于用户仓库**时生成的, 不存在于本插件仓库内。它随研究分支 git 提交, 让代码与实验记录一次锁定、可回溯。

## 关键不变量(最容易写错的地方)

- **三套词汇单向映射, 严禁混用**:
  - analyst JSON 里的英文 verdict: `supported` / `refuted` / `uncertain`
  - 持久化到 `tree.md` 的中文 status: `待验` / `进行中` / `被支持` / `被推翻`
  - 映射: supported→被支持, refuted→被推翻, uncertain→进行中(保持不结案)
  - 严禁把英文 verdict 写进 tree.md, 严禁出现 `已验证`/`已否决` 等旧词汇。
- **`tree.md` 格式**: `Status:` 行**不加粗**(写 `Status: 被支持`, 不是 `**Status**`)。用精确 Edit 改单行, 不整文件重写。
- **append-only**: Evidence 字段只增不删; 假设 ID 一旦分配永不重用(即使被推翻); experiments/decisions 编号文件永不删改。
- **DASHBOARD canonical 格式**: 只有 `**IDEA**` 和 `**Active**` 两个字段行(`**Last**` 在 Active 行内), 无独立 Status 行。被支持/被推翻的假设不进 Active Hypotheses 清单。格式细节见 `commands/step.md` Step 9。
- **hook 静默原则**: `hooks/session-start` 在非 git 仓库 / 无 DASHBOARD / detached HEAD / 字段不完整时**静默退出无输出**, 否则输出 `hookSpecificOutput.{hookEventName, additionalContext}` JSON。改 hook 后必跑 `hook-test.sh`。

## 工程纪律(来自设计文档, 贯穿所有 prompt)

- **Fail fast, 严禁静默容错**: 子 agent 返回 `status=fail` 或 JSON 格式错误 → 重试 1 次 → 仍失败则记录错误并**终止本轮**, 不降级、不兜底。
- **决策价值导向**: 重规划基于假设树状态, 内置中止判据(边际增益 <0.5% / 连续无提升 / 资源失衡)。不为填满 ablation 而穷举。
- **slurm 约束**: runner 必须先检查 `$SLURM_JOB_ID`, 不在计算节点则返回 `status=fail`, **禁止在管理节点直接跑训练**。
- **分支约束**: `init` 检测到非实验分支会建议建新分支, 但**严禁擅自创建**, 必须用户明确同意并提供分支名。
- **日期**: 统一 ISO 8601 `YYYY-MM-DD`。

## 设计依据

`docs/specs/2026-06-16-research-loop-design.md`(设计决策表、agent 职责表)和 `docs/plans/2026-06-16-research-loop-plugin.md`(实现规划)是权威背景。改架构前先读 spec 第 2 节的决策理由。
