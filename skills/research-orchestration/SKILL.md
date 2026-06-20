---
name: research-orchestration
description: 主控 PI 编排科研循环的方法论
---

# Research Orchestration

你是主控 PI, 唯一读写 `.research/` 的角色. 你编排研究闭环, 不亲自跑长任务.

## Core Principles

1. **中央状态唯一真相源**: 只有你读写 `.research/`, 子 agent 拿切片
2. **最小 brief**: 给子 agent 的 prompt 只包含任务必需信息, 不继承主会话上下文
3. **结构化返回**: 要求子 agent 返回 JSON, 你解析后写盘
4. **增量落盘**: 每个子 agent 返回后立即写 `.research/`, 不等全部完成
5. **决策价值导向**: 重规划基于假设树状态, 内置中止判据(边际 <0.5% / 连续无提升 / 资源失衡)
6. **Fail fast**: 子 agent 失败立即记录并终止本轮, 严禁静默容错

## When to Use

在 `/research-loop:step` 命令中, 你是主控. 其他命令(init/resume/status)你只负责读写文件, 不编排子 agent.

## Orchestration Pattern

```
读 tree → 选假设
  → (按需) Agent(scout, brief=调研问题)   # 见下方 Scout 说明
  → Agent(designer, brief=最小切片)
  → 写 experiments/Exxx.md(待跑)
  → Agent(implementer, brief=实验设计)
  → Agent(runner, brief=命令+资源)
  → 回填指标
  → Agent(analyst, brief=结果+假设)
  → 翻译 verdict → 更新 tree + 写 decisions/Dxxx.md
  → 重写 DASHBOARD
```

**Scout 按需调用(不在固定流水线)**: scout 不是每轮 step 的固定环节. 仅在以下情况按需调用:
- `/research-loop:init` 阶段需要摸清 codebase 相关实现位置
- designer 需要 codebase 上下文(如 baseline ckpt 路径、可用指标、相关训练脚本位置)却无法从 brief 获取时
其余情况跳过 scout, 直接进入 designer。

## Sub-Agent Brief Templates

**Designer brief:**
```
你是实验设计专家. 假设 {hypothesis_id}: {hypothesis_content}
Codebase 约束: {paths}
设计一个判别实验验证这个假设. 返回 JSON:
{
  "variables": [...],
  "metrics": [...],
  "judge_criteria": "...",
  "commands": [...]
}
```

**Implementer brief:**
```
你是代码实现者. 实验设计: {design_json}
相关文件: {paths}
按实验设计实现代码. 完成后自检. 返回 JSON:
{
  "diff_summary": "...",
  "self_check": "pass" | "fail",
  "notes": "..."
}
```

**Runner brief:**
```
你在 slurm 计算节点执行实验. 先检查 $SLURM_JOB_ID 确认在计算节点.
命令: {cmd}
资源: {gpu}/{mem}
执行后返回 JSON:
{
  "metrics": {...},
  "artifact_path": "...",
  "status": "success" | "fail",
  "error": "..."
}
```

**Analyst brief:**
```
你是结果分析师. 实验结果: {metrics_json}
假设 {hypothesis_id}: {hypothesis_content}
成功判据: {judge_criteria}
判定假设是否被支持. 返回 JSON:
{
  "verdict": "supported" | "refuted" | "uncertain",
  "confidence": 0.0-1.0,
  "trigger_replan": true | false,
  "reasoning": "..."
}
```

**Critic brief:**(契约见 `agents/critic.md`, 字段必须一致)
```
你是实验设计的对抗性审查员. 实验设计(Round {N}): {design_json}
假设 {hypothesis_id}: {hypothesis_content}
研究动机: {idea_summary}   # IDEA.md 前 300 字
Codebase 约束: {constraints}
{若 round=2, 追加 Round 1 critic.reasoning, 要求检查是否真正回应质疑}

按 4 维度审查并返回 JSON:
{
  "verdict": "PASS" | "WARN" | "FAIL",
  "dimensions": {
    "discriminability": {"verdict": "PASS|WARN|FAIL", "reason": "..."},
    "variable_count":   {"verdict": "PASS|WARN|FAIL", "reason": "..."},
    "judge_criteria":   {"verdict": "PASS|WARN|FAIL", "reason": "..."},
    "commands":         {"verdict": "PASS|WARN|FAIL", "reason": "..."}
  },
  "reasoning": "整体评判 2-3 句, 引用具体字段值",
  "suggested_revisions": ["修订建议 1", "修订建议 2"]
}
```
主控不信任 top-level verdict, 按 4 维度机器聚合(任一 FAIL → FAIL).

**Adversary Analyst brief:**(契约见 `agents/analyst-adversary.md`, 通过 MCP llm-adversary 调用)
```
你是对抗性结果验证员, 通过外部 API 独立审查. 不参考其他审查者意见.
假设 {hypothesis_id}: {hypothesis_content}
判别标准: {judge_criteria}
实验记录(截断版, 去掉 ## 结果 章节, 不含 primary 的 reasoning):
{truncated_Exxx_md}

独立判定假设是否被支持, reasoning 引用具体数值, 返回 JSON:
{
  "verdict": "supported" | "refuted" | "uncertain",
  "confidence": 0.0-1.0,
  "adversarial_reasoning": "独立判定依据, 2-3 句, 引用数值"
}
```
主控合并: 一致→采信 primary; 分歧且 adversary confidence≥0.7→降级 uncertain; 分歧且低置信→采信 primary 附警告.

## Verdict → Tree Status 映射

三套词汇通过单向映射连接, 避免混用:
- **英文 verdict**: 只在 analyst 的 JSON 输出中出现(`supported` / `refuted` / `uncertain`)
- **中文 tree status**: 持久化到 `tree.md` 的状态(`待验` / `进行中` / `被支持` / `被推翻`)

主控 PI 收到 analyst verdict 后, 按下表翻译再写盘:

| analyst verdict | tree.md Status |
|---|---|
| supported | 被支持 |
| refuted | 被推翻 |
| uncertain | 进行中(保持, 不结案) |

严禁把英文 verdict 直接写进 tree.md, 也严禁在 tree.md 出现 `已验证`/`已否决` 等旧词汇.

## State Writing Rules

- 写 `experiments/Exxx.md` 用递增编号(E001, E002, ...), slug 取假设 ID + 动作
- 写 `decisions/Dxxx.md` 仅在假设状态变更时(verdict=supported/refuted); uncertain 不写决策记录
- 更新 `tree.md` 用精确 Edit(old_string/new_string), 不整文件重写; Status 行不加粗(`Status: 被支持`), Evidence 只增不删
- 重写 `DASHBOARD.md` 每次 step 结束时, canonical 格式如下(只含 `**IDEA**` 和 `**Active**` 两个字段行, 无 Status 行):

```markdown
# Research Dashboard

**IDEA**: <一句话>
**Active**: <N> hypotheses | **Last**: <YYYY-MM-DD>

## Active Hypotheses
- H1: <内容> (待验)

## Next Steps
1. <下一步>
```

## Replan Trigger

analyst 返回 `trigger_replan: true` 时:
1. 评估受影响的兄弟/父假设
2. 被推翻的假设标记并剪枝
3. 根据现有证据派生新子假设(如果有)
4. 检查中止判据: 若活跃假设全部边际增益 < 0.5% 或已排除所有方向, 提示"建议收敛/换方向"

## Error Handling

- 子 agent 返回 status=fail → 记录 error 到 experiments/Exxx.md → 终止本轮 step
- 子 agent 返回 JSON 格式错误 → 重试一次 → 失败则终止并记录
- 严禁吞异常或降级处理
