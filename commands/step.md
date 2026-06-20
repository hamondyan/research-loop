---
description: 跑一轮假设验证循环(designer → critic → implementer → runner → analyst → 更新状态)
---

# /research-loop:step

编排 5 个无状态子 agent 完成一轮假设验证循环: 从假设树选取待验假设 → 设计实验 → 预检审查 → 实现代码 → 执行实验 → 分析结果 → 更新假设树和决策记录.

## Journal 文件格式

每次 step 执行时, 主控在 `.research/experiments/Exxx.journal` 追加状态行 (JSONL 格式), 用于断点续跑.

**Schema**:
```jsonl
{"step":"init", "hypothesis_id":"H1.1", "experiment_id":"E001", "status":"started", "timestamp":"2026-06-20T10:00:00Z"}
{"step":"designer", "round":1, "status":"done", "timestamp":"2026-06-20T10:05:00Z"}
{"step":"critic", "round":1, "status":"done", "verdict":"FAIL", "timestamp":"2026-06-20T10:10:00Z"}
{"step":"designer", "round":2, "status":"done", "timestamp":"2026-06-20T10:15:00Z"}
{"step":"critic", "round":2, "status":"done", "verdict":"PASS", "timestamp":"2026-06-20T10:20:00Z"}
{"step":"implementer", "status":"done", "timestamp":"2026-06-20T10:30:00Z"}
{"step":"runner", "command_index":0, "status":"done", "timestamp":"2026-06-20T11:00:00Z"}
{"step":"runner", "command_index":1, "status":"done", "timestamp":"2026-06-20T11:30:00Z"}
{"step":"analyst-primary", "status":"done", "verdict":"supported", "timestamp":"2026-06-20T11:35:00Z"}
{"step":"analyst-adversary", "status":"done", "verdict":"supported", "timestamp":"2026-06-20T11:40:00Z"}
{"step":"finalize", "status":"done", "timestamp":"2026-06-20T11:45:00Z"}
```

或异常终止:
```jsonl
{"step":"terminate", "reason":"critic_round2_fail", "timestamp":"2026-06-20T10:25:00Z"}
{"step":"terminate", "reason":"runner_error", "error":"Not in slurm job", "timestamp":"2026-06-20T11:00:00Z"}
```

**字段说明**:
- `step`: 当前步骤名称 (init/designer/critic/implementer/runner/analyst-primary/analyst-adversary/finalize/terminate)
- `status`: done(成功) / fail(失败) / started(开始)
- `round`: designer/critic 的轮次 (1 或 2)
- `command_index`: runner 执行的命令索引 (0, 1, 2, ...)
- `verdict`: critic/analyst 的判决结果
- `error`: 错误信息(仅 fail/terminate 时填写)
- `reason`: 终止原因(仅 terminate 时填写)
- `timestamp`: ISO 8601 格式时间戳

**续跑规则**:
- 若最后一行是 `{"step":"finalize", "status":"done"}` 或 `{"step":"terminate"}`, 则实验已完成
- 否则视为未完成, 可从最后一个 `status=done` 的步骤后续跑

## 前置条件

- 当前目录是 git 仓库
- `.research/tree.md` 存在
- `.research/tree.md` 中至少有 1 个待验假设(`Status: 待验`)
- 当前在 slurm 管理节点或已在计算节点上

## 执行流程

### Step 0: Resume 检测(断点续跑)

在开始新实验前, 先检查是否存在未完成的实验:

1. **读取假设树并选择待验假设**:
   - 读取 `.research/tree.md`, 解析所有假设节点
   - 识别 `Status: 待验` 的假设, 按层级优先和序号优先排序
   - 选择第一个待验假设作为目标
   - 若无待验假设, 输出提示并终止(见 Step 1)

2. **扫描未完成 journal**:
   - 列出 `.research/experiments/` 目录下所有 `*.journal` 文件
   - 逐个读取, 解析每行 JSON
   - 检查 `step=init` 行的 `hypothesis_id` 是否匹配当前待验假设
   - 检查最后一行:
     - 若为 `{"step":"finalize", "status":"done"}` → 已完成, 跳过
     - 若为 `{"step":"terminate"}` → 已终止, 跳过
     - 否则 → 未完成, 可续跑

3. **构建续跑状态**:
   - 若找到未完成 journal, 解析所有 `status=done` 的步骤, 构建已完成步骤集合
   - 确定续跑点(首个未完成步骤):
     - 若 `{"step":"designer", "round":1}` 未完成 → 从 Step 2 开始
     - 若 `{"step":"critic", "round":1}` 未完成 → 从 Step 2.5 Round 1 开始
     - 若 `{"step":"implementer"}` 未完成 → 从 Step 4 开始
     - 若 `{"step":"runner", "command_index":i}` 部分完成 → 从 Step 5 的第 i+1 条命令开始
     - 若 `{"step":"analyst-primary"}` 未完成 → 从 Step 7.1 开始
   - 输出提示: `检测到未完成实验 {experiment_id}, 从 {step} 续跑`
   - 跳转到对应步骤继续执行

4. **创建新实验**:
   - 若无未完成 journal, 生成新实验编号(E001, E002, ...)
   - 创建 `.research/experiments/Exxx.journal`, 写入 init 行:
     ```json
     {"step":"init", "hypothesis_id":"H1.1", "experiment_id":"E001", "status":"started", "timestamp":"2026-06-20T10:00:00Z"}
     ```
   - 继续执行 Step 2(designer round 1)

### Step 1: 读取假设树并选择待验假设

读取 `.research/tree.md`, 解析所有假设节点:

- 识别 `Status: 待验` 的假设
- 若有多个待验假设, 按层级优先(H1 > H1.1 > H1.2)和序号优先(H1 > H2 > H3)排序
- 选择第一个待验假设作为本轮目标
- 提取假设 ID 和完整描述

若无待验假设, 输出提示并终止:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠ 无待验假设
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
所有假设已处于 [进行中/被支持/被推翻] 状态.

建议:
  1. 用 /research-loop:status 查看当前状态
  2. 在 tree.md 中添加新假设
  3. 或用 /research-loop:resume 回顾整体进展并决定收敛
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 2: 调用 designer agent 设计实验

调用 `designer` agent, 传递最小 brief. designer 的输入/输出契约见 `agents/designer.md`, 必须返回如下 canonical JSON:

```python
designer_result = Agent(
    prompt=f"""
你是实验设计专家. 为假设 {hypothesis_id} 设计判别实验.

假设: {hypothesis_text}
研究动机: {research_idea}        # 从 .research/IDEA.md 读取, 限 300 字
Codebase 约束: {codebase_constraints}  # 可用指标 / baseline ckpt / 算力预算

要求:
1. 判别性实验: 能区分假设成立/不成立, 有明确 baseline 和对照组
2. 变量数量 ≤ 3, 复用现有代码避免大重构
3. judge_criteria 必须可操作, 避免模糊表述
4. commands 必须包含完整路径和参数, 可直接执行
5. 返回结构化 JSON:
   {{
       "variables": [
           {{"name": "变量名", "control": "对照组值", "treatment": "实验组值"}}
       ],
       "metrics": [
           {{"name": "指标名", "expected_direction": "higher|lower|unchanged", "threshold": 数值或null}}
       ],
       "judge_criteria": "如何判定假设成立, 1-2 句话",
       "commands": [
           {{"group": "baseline|treatment", "cmd": "完整命令", "resources": {{"gpu": N, "hours": H}}}}
       ]
   }}

返回 JSON 即可, 无需其他输出.
""",
    subagent_type="designer",
    isolation="worktree",
    description="设计实验验证假设"
)
```

**关键约束**:
- designer 只设计, 不实现代码
- 返回必须是结构化 JSON, 字段与 `agents/designer.md` 一致
- 若 designer 返回格式错误, 重试 1 次, 仍失败则终止并记录错误

**Journal 写入**:
```python
# 检查 journal 中是否已有该步骤
if not journal_has_step_done('designer', round=1):
    # 执行 designer round 1
    designer_result = Agent(...)
    
    # 追加 journal 行
    append_to_journal({
        "step": "designer",
        "round": 1,
        "status": "done",
        "timestamp": current_iso8601_time()
    })
else:
    # 从 Exxx.md 或 journal 加载已有结果
    designer_result = load_designer_output_from_experiment_doc(experiment_id, round=1)
    print("跳过 designer round 1 (已完成)")
```

### Step 2.5: Critic 预检审查

在 designer 返回设计后, 调用 `critic` agent 进行 4 维度预检审查. Critic 预检是多轮流程, 最多 2 轮:

#### Round 1: 首次审查

调用 `critic` agent, 传递假设、IDEA 摘要、codebase 约束和 designer 的完整 JSON. 契约见 `agents/critic.md`:

```python
critic_result = Agent(
    prompt=f"""
你是实验设计审查专家. 对 designer 输出进行 4 维度预检.

假设 {hypothesis_id}: {hypothesis_text}
研究动机: {research_idea}        # 从 .research/IDEA.md 读取, 限 300 字
Codebase 约束: {codebase_constraints}
Designer 设计: {designer_json}    # designer 返回的完整 JSON

要求:
1. 从 4 个维度独立审查(维度名与 agents/critic.md 契约一致):
   - **discriminability**: 实验能否明确区分假设成立/不成立, 有无 baseline/对照组
   - **variable_count**: 变量 ≤ 3; 若多变量需说明是否存在交互效应解释困难
   - **judge_criteria**: 是否可操作, 含具体阈值或统计检验, 避免模糊表述
   - **commands**: 路径是否完整、参数是否齐全、资源预算是否与实验规模匹配
2. 每个维度返回机器判决: PASS / WARN / FAIL
3. FAIL 必须给出具体修正方向, WARN 给出改进建议
4. 返回结构化 JSON(schema 与 agents/critic.md 一致, dimensions 为对象):
   {{
       "verdict": "PASS|WARN|FAIL",
       "dimensions": {{
           "discriminability": {{"verdict": "PASS|WARN|FAIL", "reason": "..."}},
           "variable_count":   {{"verdict": "PASS|WARN|FAIL", "reason": "..."}},
           "judge_criteria":   {{"verdict": "PASS|WARN|FAIL", "reason": "..."}},
           "commands":         {{"verdict": "PASS|WARN|FAIL", "reason": "..."}}
       }},
       "reasoning": "整体评判 2-3 句, 引用具体字段值",
       "suggested_revisions": ["修订建议 1", "修订建议 2"]
   }}

返回 JSON 即可, 无需其他输出.
""",
    subagent_type="critic",
    isolation="worktree",
    description="预检实验设计"
)
```

**判决聚合机制**(机器 verdict, 不信任 critic 自己写的 top-level verdict 字段):
- 遍历 dimensions 对象的 4 个 key(discriminability/variable_count/judge_criteria/commands), 统计各维度 verdict: `fail_count`, `warn_count`, `pass_count`
- 聚合规则:
  - `fail_count > 0` → 最终判决 **FAIL**
  - `fail_count == 0 且 warn_count > 0` → 最终判决 **WARN**
  - `fail_count == 0 且 warn_count == 0` → 最终判决 **PASS**

**Round 1 后处理**:
- 若最终判决为 **PASS** 或 **WARN**: 进入 Step 3(创建实验文档), 继续流程
- 若最终判决为 **FAIL**: 进入 Round 2(设计迭代)

**Journal 写入**:
```python
# 检查 journal 中是否已有该步骤
if not journal_has_step_done('critic', round=1):
    # 执行 critic round 1
    critic_result = Agent(...)
    
    # 统计 verdict 并聚合
    final_verdict = aggregate_critic_verdict(critic_result)
    
    # 追加 journal 行
    append_to_journal({
        "step": "critic",
        "round": 1,
        "status": "done",
        "verdict": final_verdict,  # PASS / WARN / FAIL
        "timestamp": current_iso8601_time()
    })
else:
    # 从 Exxx.md 或 journal 加载已有结果
    critic_result = load_critic_output_from_experiment_doc(experiment_id, round=1)
    final_verdict = load_critic_verdict_from_journal(experiment_id, round=1)
    print(f"跳过 critic round 1 (已完成, verdict={final_verdict})")
```

#### Round 2: 设计迭代(当 Round 1 FAIL)

当 Round 1 最终判决为 FAIL 时:

1. **重新 brief designer**: 构造 Round 2 brief, 包含 Round 1 的 critic 反馈:

```python
designer_round2_result = Agent(
    prompt=f"""
你是实验设计专家. Round 1 设计未通过 critic 预检, 请根据反馈重新设计.

假设: {hypothesis_id} {hypothesis_text}
研究动机: {research_idea}
Codebase 约束: {codebase_constraints}

Round 1 设计: {round1_designer_json}

Critic 反馈(Round 1):
{critic_round1_feedback}   # 只包含 verdict=FAIL 的维度及其 suggestions

要求:
1. 针对 FAIL 维度的 suggestions, 调整实验设计
2. 变量数量 ≤ 3, judge_criteria 可操作, commands 可执行
3. 返回与 Round 1 相同格式的 JSON

返回 JSON 即可, 无需其他输出.
""",
    subagent_type="designer",
    isolation="worktree",
    description="重新设计实验(Round 2)"
)
```

2. **再次调用 critic**: 用相同流程审查 Round 2 设计, 使用 Round 2 的 designer JSON

**Journal 写入(Round 2 designer)**:
```python
if not journal_has_step_done('designer', round=2):
    designer_round2_result = Agent(...)
    append_to_journal({
        "step": "designer",
        "round": 2,
        "status": "done",
        "timestamp": current_iso8601_time()
    })
else:
    designer_round2_result = load_designer_output_from_experiment_doc(experiment_id, round=2)
    print("跳过 designer round 2 (已完成)")
```

**Journal 写入(Round 2 critic)**:
```python
if not journal_has_step_done('critic', round=2):
    critic_round2_result = Agent(...)
    final_verdict_round2 = aggregate_critic_verdict(critic_round2_result)
    append_to_journal({
        "step": "critic",
        "round": 2,
        "status": "done",
        "verdict": final_verdict_round2,
        "timestamp": current_iso8601_time()
    })
else:
    critic_round2_result = load_critic_output_from_experiment_doc(experiment_id, round=2)
    final_verdict_round2 = load_critic_verdict_from_journal(experiment_id, round=2)
    print(f"跳过 critic round 2 (已完成, verdict={final_verdict_round2})")
```

3. **Round 2 判决聚合**: 同 Round 1, 统计 4 维度 verdict 并聚合

**Round 2 后处理**:
- 若最终判决为 **PASS** 或 **WARN**: 进入 Step 3(创建实验文档), 继续流程
- 若最终判决为 **FAIL**: 进入 Round 2 FAIL 终止流程(见下节)

#### Round 2 FAIL 终止

当 Round 2 最终判决仍为 FAIL 时:
1. 在 `.research/experiments/Exxx.md` 写入 `## Critic Final Verdict` 章节(格式见 Step 3)
2. 更新实验文档 `Status: Critic 拒绝`
3. **终止本轮 step**, 不调用 implementer/runner/analyst
4. 输出摘要, 建议人工检查假设或设计

**Journal 写入(终止)**:
```python
append_to_journal({
    "step": "terminate",
    "reason": "critic_round2_fail",
    "timestamp": current_iso8601_time()
})
```

#### Override 机制

若实验文档 `.research/experiments/Exxx.md` 中存在 `## Override` 章节(人工事后添加), 则:
- **跳过整个 Step 2.5**(不调用 critic)
- **直接进入 Step 3**, 使用 Round 2 的 designer 设计(若无 Round 2 则用 Round 1)
- Override 只能在 Round 2 FAIL 终止后使用, 不影响 Round 1 FAIL(Round 1 FAIL 必须先进 Round 2)

**检测 Override 的时机**: 在 Step 2 designer 返回后, Step 2.5 开始前, 检查实验文档是否已存在且包含 `## Override` 章节. 若存在, 跳过 Step 2.5.

### Step 3: 创建实验文档 experiments/Exxx.md

解析 designer 返回的 JSON, 生成实验编号(E001, E002, ...), 写入 `.research/experiments/Exxx.md`.

**完整文档模板结构**:

```markdown
# Exxx: [假设 ID + 动作 slug]

**Hypothesis ID**: [hypothesis_id]
**Hypothesis**: [hypothesis_text]
**Status**: 待执行 | 已执行 | 执行失败 | Critic 拒绝 | 被支持 | 被推翻 | 进行中
**Created**: [今天日期 YYYY-MM-DD]

## 实验设计 (Round 1)

**实验变量**:
- [variables[].name]: control=[control] / treatment=[treatment]

**评估指标**:
- [metrics[].name]: 期望方向 [expected_direction], 阈值 [threshold]

**判别标准**: [judge_criteria]

**执行命令**:
- [baseline] [cmd]  (gpu=[N], hours=[H])
- [treatment] [cmd]  (gpu=[N], hours=[H])

## Critic Review (Round 1)

**Final Verdict**: [PASS / WARN / FAIL]

**Dimensions**:
- **discriminability**: [verdict] — [reason]
- **variable_count**: [verdict] — [reason]
- **judge_criteria**: [verdict] — [reason]
- **commands**: [verdict] — [reason]

**Reasoning**: [reasoning]
**Suggested revisions**:
[逐条列出 suggested_revisions]

[若进入 Round 2, 追加以下章节]

## 实验设计 (Round 2)

[同 Round 1 格式, 使用 designer Round 2 的 JSON]

**实验变量**:
- [variables[].name]: control=[control] / treatment=[treatment]

**评估指标**:
- [metrics[].name]: 期望方向 [expected_direction], 阈值 [threshold]

**判别标准**: [judge_criteria]

**执行命令**:
- [baseline] [cmd]  (gpu=[N], hours=[H])
- [treatment] [cmd]  (gpu=[N], hours=[H])

## Critic Review (Round 2)

**Final Verdict**: [PASS / WARN / FAIL]

**Dimensions**:
[同 Round 1 格式, 4 个维度的独立判决]

[若 Round 2 仍 FAIL, 追加以下章节并终止]

## Critic Final Verdict

**Status**: Critic 拒绝
**Date**: [今天日期 YYYY-MM-DD]

经过 2 轮审查, 实验设计仍未通过预检. 终止本轮实验.

**Round 2 FAIL 维度**:
[列出 verdict=FAIL 的维度及其 reasoning 和 suggestions]

**建议**:
1. 人工检查假设表述是否准确
2. 评估 codebase 约束是否过于严格
3. 考虑调整假设范围或拆分为更小粒度子假设

[若人工判定可继续, 追加 Override 章节]

## Override

**Acknowledged**: [日期 YYYY-MM-DD]
**Reason**: [人工判定 critic 误判的理由]

用户确认 critic 审查过于严格或误判, 强制继续执行实验.

[若无 Round 2 FAIL 或已 Override, 继续正常流程]

## 实现摘要

**Modified Files**:
[implementer 返回的 diff_summary]

**Self-check**: [pass/fail]

**Notes**:
[implementer 的 notes]

## 执行记录

### Baseline
- **命令**: [cmd]
- **状态**: [success/fail/timeout]
- **产出**: [artifact_path]
- **指标**: [metrics as key-value pairs]
[若失败, 追加 **错误**: [error]]

### Treatment
- **命令**: [cmd]
- **状态**: [success/fail/timeout]
- **产出**: [artifact_path]
- **指标**: [metrics as key-value pairs]
[若失败, 追加 **错误**: [error]]

[若任一命令失败, 追加]:
**终止原因**: [error message]

## 结果

[情况 A: 对抗验证未配置]

**Analyst (Claude)**: {primary.verdict} (confidence {primary.confidence})

{primary.reasoning}

(对抗审校未配置)

[情况 B: 对抗验证启用, verdict 一致]

**Primary Analyst (Claude)**: {primary.verdict} (confidence {primary.confidence})

{primary.reasoning}

**Adversarial Analyst ({adversary_model} via MCP)**: {adversary.verdict} (confidence {adversary.confidence})

{adversary.adversarial_reasoning}

**Final Verdict**: {final_verdict} (confidence {primary.confidence})

两位分析师判定一致, 结论稳固.

[情况 C: 对抗验证启用, verdict 分歧且 adversary.confidence >= 0.7]

**Primary Analyst (Claude)**: {primary.verdict} (confidence {primary.confidence})

{primary.reasoning}

**Adversarial Analyst ({adversary_model} via MCP)**: {adversary.verdict} (confidence {adversary.confidence})

{adversary.adversarial_reasoning}

**Final Verdict**: uncertain (降级)

分析师判定存在分歧(primary: {primary.verdict}, adversary: {adversary.verdict}), 且 adversary 信心度 >= 0.7, 结论降级为 uncertain. 建议人工复核或增加样本量.

[情况 D: 对抗验证启用, verdict 分歧但 adversary.confidence < 0.7]

**Primary Analyst (Claude)**: {primary.verdict} (confidence {primary.confidence})

{primary.reasoning}

**Adversarial Analyst ({adversary_model} via MCP)**: {adversary.verdict} (confidence {adversary.confidence})

{adversary.adversarial_reasoning}

**Final Verdict**: {primary.verdict} (confidence {primary.confidence})

Adversary 持不同意见(adversary: {adversary.verdict})但信心度 < 0.7, 采用 primary 判定. 存在一定不确定性.
```

**章节生成规则**:
1. `## 实验设计 (Round 1)` 和 `## Critic Review (Round 1)` 总是生成
2. 若 Round 1 FAIL 进入 Round 2, 追加 `## 实验设计 (Round 2)` 和 `## Critic Review (Round 2)`
3. 若 Round 2 FAIL, 追加 `## Critic Final Verdict`, 设置 `Status: Critic 拒绝`, 不生成后续 "执行记录" 和 "结果" 章节
4. 若 Round 1 PASS/WARN 或 Round 2 PASS/WARN, 生成 "执行记录" 和 "结果" 章节(待 runner 和 analyst 回填)
5. 若检测到 Override, 跳过 Critic Review 章节, 直接生成 Design + 执行记录 + 结果

若 `.research/experiments/` 目录不存在, 先创建.

### Step 4: 调用 implementer agent 实现实验代码

调用 `implementer` agent, 传递实验设计和相关文件路径. 契约见 `agents/implementer.md`:

```python
implementer_result = Agent(
    prompt=f"""
你是代码实现者. 根据实验设计实现代码修改.

实验设计: {{"variables": [...], "commands": [...]}}   # 来自 designer_result
相关文件: {related_files}
代码库路径: {codebase_root}

要求:
1. 按实验设计实现必要的代码改动(配置文件 / 训练脚本等)
2. 不修改无关文件, diff 必须最小化, 遵循项目现有代码风格
3. 完成后自检: 运行 lint 和相关 unit test
4. 返回结构化 JSON:
   {{
       "diff_summary": "修改了哪些文件, 每个文件做了什么, 3-5 句话",
       "self_check": "pass|fail",
       "notes": "实现过程中的关键决策或权衡"
   }}

返回 JSON 即可, 无需其他输出.
""",
    subagent_type="implementer",
    isolation="worktree",
    description="实现实验代码"
)
```

**关键约束**:
- implementer 必须自检(lint + unit test), `self_check=fail` 时终止本轮并记录 `notes`
- 不引入新依赖, diff 最小化
- 若 implementer 返回格式错误, 重试 1 次, 仍失败则终止

**Journal 写入**:
```python
if not journal_has_step_done('implementer'):
    implementer_result = Agent(...)
    
    if implementer_result['self_check'] == 'fail':
        append_to_journal({
            "step": "terminate",
            "reason": "implementer_self_check_fail",
            "error": implementer_result['notes'],
            "timestamp": current_iso8601_time()
        })
        # 终止流程
        return
    
    append_to_journal({
        "step": "implementer",
        "status": "done",
        "timestamp": current_iso8601_time()
    })
else:
    implementer_result = load_implementer_output_from_experiment_doc(experiment_id)
    print("跳过 implementer (已完成)")
```

### Step 5: 调用 runner agent 执行实验

对 designer 返回的每条 command(baseline/treatment), 调用 `runner` agent. 契约见 `agents/runner.md`:

```python
runner_result = Agent(
    prompt=f"""
你在 slurm 计算节点执行实验. 先检查 $SLURM_JOB_ID 确认在计算节点.

命令: {cmd}
资源: gpu={gpu} hours={hours}
实验 ID: {experiment_id}
结果目录: {output_dir}

要求:
1. 检查 $SLURM_JOB_ID: 若不存在, 说明当前在管理节点, 返回 status=fail,
   error="Not in slurm job. Please allocate compute node first.", 不可在管理节点直接执行
2. 增量写盘: 实验记录写到 output_dir/experiment_log.jsonl, 每条一行 JSON
3. 捕获 stderr 和 exit code; 超时 status=timeout 并 kill 进程
4. 返回结构化 JSON:
   {{
       "metrics": {{"metric_name": value, ...}},
       "artifact_path": "产出文件路径(ckpt/log/结果json)",
       "status": "success|fail",
       "error": "错误信息, status != success 时填写, 否则 null"
   }}

返回 JSON 即可, 无需其他输出.
""",
    subagent_type="runner",
    isolation="worktree",
    description="执行实验脚本"
)
```

**关键约束**:
- **Slurm 环境检查**: runner 必须检查 `$SLURM_JOB_ID`, 不存在则返回 `status=fail`, 禁止在管理节点直接执行训练任务
- **增量写盘**: 每条命令完成立即写 `experiment_log.jsonl`, 避免长时间运行后丢失记录
- **失败终止**: 任一 command 返回 `status != success` 立即停止, 不继续执行后续命令

**Journal 写入(逐命令)**:
```python
commands = designer_result['commands']  # baseline, treatment, ...
for i, cmd_spec in enumerate(commands):
    if journal_has_step_done('runner', command_index=i):
        print(f"跳过 runner command {i} (已完成)")
        continue
    
    runner_result = Agent(
        subagent_type='runner',
        prompt=f"""执行命令 {i}: {cmd_spec['cmd']}""",
        ...
    )
    
    if runner_result['status'] != 'success':
        append_to_journal({
            "step": "runner",
            "command_index": i,
            "status": "fail",
            "error": runner_result['error'],
            "timestamp": current_iso8601_time()
        })
        append_to_journal({
            "step": "terminate",
            "reason": "runner_error",
            "error": runner_result['error'],
            "timestamp": current_iso8601_time()
        })
        # 终止流程, 不执行后续命令
        return
    
    append_to_journal({
        "step": "runner",
        "command_index": i,
        "status": "done",
        "timestamp": current_iso8601_time()
    })
```

### Step 6: 回填实验文档的执行记录

解析 runner 返回的 JSON, 更新 `.research/experiments/Exxx.md` 的 "执行记录" 章节:

```markdown
## 执行记录

**baseline**:
- 命令: [cmd]
- 状态: [status]
- 产出: [artifact_path]
- 指标: [metrics]

**treatment**:
- 命令: [cmd]
- 状态: [status]
- 产出: [artifact_path]
- 指标: [metrics]
```

若 runner 返回 `status != success`, 在 "执行记录" 章节追加错误信息:

```markdown
## 执行记录

**错误**: [runner 返回的 error]
**建议**: [如: 检查 slurm 作业状态 / 查看日志文件]
```

更新实验文档的 `Status` 字段为 `已执行` 或 `执行失败`.

### Step 7: 调用 analyst agent 分析结果并进行对抗验证

#### 7.1 Primary Analyst 分析

调用 `analyst` agent, 传递实验结果和假设. 契约见 `agents/analyst.md`:

```python
if not journal_has_step_done('analyst-primary'):
    primary_result = Agent(
        prompt=f"""
    你是结果分析师. 解读实验结果, 判定假设是否成立.

    假设 {hypothesis_id}: {hypothesis_text}
    成功判据: {judge_criteria}        # 来自 designer_result
    实验结果: [
        {{"group": "baseline", "metrics": {{...}}}},
        {{"group": "treatment", "metrics": {{...}}}}
    ]                                  # 来自各 runner_result

    要求:
    1. 对比 baseline 和 treatment 指标, reasoning 必须引用具体数值
    2. 判定 verdict; uncertain 必须说明原因(数据不足/判据模糊/结果矛盾)
    3. confidence < 0.7 或假设被强力反驳/发现新假设时, trigger_replan=true
    4. 返回结构化 JSON:
       {{
           "verdict": "supported|refuted|uncertain",
           "confidence": 0.0-1.0,
           "trigger_replan": true|false,
           "reasoning": "判定依据, 2-3 句话, 引用具体数值"
       }}

    返回 JSON 即可, 无需其他输出.
    """,
        subagent_type="analyst",
        isolation="worktree",
        description="分析实验结果"
    )
    
    append_to_journal({
        "step": "analyst-primary",
        "status": "done",
        "verdict": primary_result['verdict'],
        "timestamp": current_iso8601_time()
    })
else:
    primary_result = load_analyst_output_from_experiment_doc(experiment_id, analyst_type='primary')
    print("跳过 analyst-primary (已完成)")
```

#### 7.2 Adversarial Verification (对抗验证)

在 primary analyst 返回后, 进行跨模型对抗验证以提升结论稳健性.

**步骤**:

1. **检查 MCP llm-adversary 可用性**:
   - 检查 MCP server `llm-adversary` 是否已注册(查询可用的 MCP tools 中是否包含 `mcp__llm_adversary__chat`)
   - 若不可用: 跳过对抗验证, 直接使用 primary analyst 的结果, 在 Exxx.md 的 ## 结果 章节注明 `(对抗审校未配置)`
   - 若可用: 继续步骤 2

2. **准备截断版实验文档**:
   - 读取 `.research/experiments/Exxx.md`
   - 查找 `\n## 结果\n` 位置, 截取该位置之前的全部内容(保留 ## 假设, ## Design, ## 执行记录等, 移除 ## 结果)
   - 截断后的文档应包含 hypothesis, judge_criteria, commands, metrics 等原始数据, 但不包含 primary analyst 的 reasoning/verdict

3. **调用 adversary analyst**:
   ```python
   if not journal_has_step_done('analyst-adversary'):
       adversary_result = Agent(
           prompt=f"""
       你是跨模型对抗审查员. 从原始实验数据独立推导结论, 不得参考 primary analyst 的判定.

       实验文档(已截断, 无 primary 结论):
       {truncated_experiment_content}

       要求:
       1. 从原始 metrics 和执行记录推导判定, 不得参考他人结论
       2. reasoning 必须引用具体数值
       3. 若数据不足/矛盾, 返回 verdict="uncertain"
       4. 返回结构化 JSON:
          {{
              "verdict": "supported|refuted|uncertain",
              "confidence": 0.0-1.0,
              "adversarial_reasoning": "独立判定依据, 2-3 句话"
          }}

       返回 JSON 即可, 无需其他输出.
       """,
           subagent_type="analyst-adversary",
           isolation="worktree",
           description="对抗验证实验结果"
       )
       
       append_to_journal({
           "step": "analyst-adversary",
           "status": "done",
           "verdict": adversary_result['verdict'],
           "timestamp": current_iso8601_time()
       })
   else:
       adversary_result = load_analyst_output_from_experiment_doc(experiment_id, analyst_type='adversary')
       print("跳过 analyst-adversary (已完成)")
   ```

4. **Verdict 合并逻辑**:
   - 若 `primary.verdict == adversary.verdict`: 结论一致, 采用 primary verdict, 在结果中注明 "两位分析师一致"
   - 若 `primary.verdict != adversary.verdict 且 adversary.confidence >= 0.7`: 存在有力分歧, 最终 verdict 降级为 `uncertain`, 在结果中说明 "分析师判定分歧, 降级为 uncertain"
   - 若 `primary.verdict != adversary.verdict 且 adversary.confidence < 0.7`: 分歧但 adversary 信心不足, 采用 primary verdict, 在结果中注明 "adversary 持不同意见但信心不足, 采用 primary 判定"

5. **更新实验文档 ## 结果 章节**(见 Step 7.3 详细格式)

#### 7.3 写入 ## 结果 到 Exxx.md

根据是否启用对抗验证, 使用不同格式:

**情况 A: 对抗验证未配置**

```markdown
## 结果

**Analyst (Claude)**: {primary.verdict} (confidence {primary.confidence})

{primary.reasoning}

(对抗审校未配置)
```

**情况 B: 对抗验证启用, verdict 一致**

```markdown
## 结果

**Primary Analyst (Claude)**: {primary.verdict} (confidence {primary.confidence})

{primary.reasoning}

**Adversarial Analyst ({adversary_model} via MCP)**: {adversary.verdict} (confidence {adversary.confidence})

{adversary.adversarial_reasoning}

**Final Verdict**: {final_verdict} (confidence {primary.confidence})

两位分析师判定一致, 结论稳固.
```

**情况 C: 对抗验证启用, verdict 分歧且 adversary.confidence >= 0.7**

```markdown
## 结果

**Primary Analyst (Claude)**: {primary.verdict} (confidence {primary.confidence})

{primary.reasoning}

**Adversarial Analyst ({adversary_model} via MCP)**: {adversary.verdict} (confidence {adversary.confidence})

{adversary.adversarial_reasoning}

**Final Verdict**: uncertain (降级)

分析师判定存在分歧(primary: {primary.verdict}, adversary: {adversary.verdict}), 且 adversary 信心度 >= 0.7, 结论降级为 uncertain. 建议人工复核或增加样本量.
```

**情况 D: 对抗验证启用, verdict 分歧但 adversary.confidence < 0.7**

```markdown
## 结果

**Primary Analyst (Claude)**: {primary.verdict} (confidence {primary.confidence})

{primary.reasoning}

**Adversarial Analyst ({adversary_model} via MCP)**: {adversary.verdict} (confidence {adversary.confidence})

{adversary.adversarial_reasoning}

**Final Verdict**: {primary.verdict} (confidence {primary.confidence})

Adversary 持不同意见(adversary: {adversary.verdict})但信心度 < 0.7, 采用 primary 判定. 存在一定不确定性.
```

**关键约束**:
- primary analyst 只分析已有数据, 不运行新实验
- `verdict` 字段必须是 `supported` / `refuted` / `uncertain` 之一(英文, 只在 analyst JSON 输出中出现)
- 若数据不足无法判定, primary 返回 `verdict: "uncertain"` 并说明原因
- adversary 必须从截断版文档独立推导, 严禁看到 primary 的 reasoning/verdict
- final verdict 用于后续 tree.md 状态更新和决策记录创建

### Step 8: 更新假设树和创建决策记录

主控 PI 将 analyst 的英文 verdict 翻译为中文 tree status, 映射规则:

| final_verdict (来自 Step 7) | tree.md Status |
|---|---|
| supported | 被支持 |
| refuted | 被推翻 |
| uncertain | 进行中(保持, 不结案) |

**注意**: 使用 Step 7 产出的 `final_verdict` (经对抗验证合并后的结果), 而非直接使用 `primary.verdict`.

**8.1 更新 `.research/tree.md`**(用精确 Edit, 不整文件重写, Status 不加粗):

```markdown
### H1.1: 增加 instruction token 的 loss 权重能提升否定词敏感度
Status: 被支持
Evidence: E001
Parent: H1
```

- 找到对应假设节点, 把 `Status:` 行从 `待验`/`进行中` 改为映射后的值
- 把实验 ID 追加到 `Evidence:` 行(Evidence 只增不删; 原为 `(empty)` 则替换为该 ID)

**8.2 创建决策记录 `.research/decisions/Dxxx.md`**(仅在 final_verdict=supported/refuted, 即假设状态变更时):

```markdown
# Dxxx: [hypothesis_id] [被支持/被推翻]

**Hypothesis**: [hypothesis_id] [hypothesis_text]
**Date**: [今天日期 YYYY-MM-DD]
**Experiment**: [Exxx]
**Verdict**: [final_verdict] (confidence [primary.confidence])
**Adversarial Verification**: [是/否, 若是则注明一致性状态]

## 结论

[primary.reasoning]

[若启用对抗验证, 追加]:
**Adversarial Review**: [一致/分歧但采用 primary/等]
[adversary.adversarial_reasoning]

## 数据对比

**baseline**: [baseline metrics]
**treatment**: [treatment metrics]

## 重规划

trigger_replan: [primary.trigger_replan]
[若 true, 说明受影响的兄弟/父假设和派生的新子假设]
```

若 `final_verdict=uncertain`, 不创建决策记录, 仅在实验文档结果章节记录, 假设保持 `进行中`.

若 `.research/decisions/` 目录不存在, 先创建.

**Journal 写入(完成)**:
```python
append_to_journal({
    "step": "finalize",
    "status": "done",
    "timestamp": current_iso8601_time()
})
```

### Step 9: 重写 DASHBOARD.md

读取 `.research/tree.md` 和决策记录, 重新生成 `.research/DASHBOARD.md`(canonical 格式, 字段 `**Last**`):

```markdown
# Research Dashboard

**IDEA**: [从 IDEA.md 提取一句话概括]
**Active**: [待验+进行中假设数量] hypotheses | **Last**: [今天日期 YYYY-MM-DD]

## Active Hypotheses

- H1: [假设描述] (待验)
- H2.1: [假设描述] (进行中)

## Next Steps

1. [从 analyst 的 reasoning / replan 提取下一步]
2. [若有其他待验假设, 列出]
```

被支持/被推翻的假设不进 Active Hypotheses 清单(已结案); 仅 `待验`/`进行中` 进清单.

### Step 10: 输出摘要

输出本轮验证循环的完整摘要:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Research Step Completed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Hypothesis Tested
[hypothesis_id]: [hypothesis_text]

## Experiment
Exxx: [variables 摘要]
  baseline: [cmd 摘要]
  treatment: [cmd 摘要]

## Result
[被支持 / 被推翻 / 进行中(uncertain)]  (confidence [confidence])

[reasoning 一句话摘要]

## Next Step
[analyst reasoning / replan 建议的下一步]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 Artifacts Created
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Experiment:  .research/experiments/Exxx.md
Decision:    .research/decisions/Dxxx.md   (仅 supported/refuted)
Updated:     .research/tree.md
Updated:     .research/DASHBOARD.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 实现注意

1. **子 agent 隔离**: 每个子 agent 使用 `isolation="worktree"` 隔离上下文, 避免污染主环境

2. **最小 brief 传递**: 每个子 agent 只接收必要信息, 避免传递整个 .research/ 目录

3. **结构化返回强制**: 所有子 agent 必须返回 JSON, 字段与对应 `agents/*.md` 契约一致; 若格式错误重试 1 次, 仍失败则终止

4. **Critic 判决聚合**: critic 返回 4 个维度的独立 verdict, 主控 PI 按聚合规则计算最终判决(任一 FAIL → 最终 FAIL; 无 FAIL 但有 WARN → 最终 WARN; 全 PASS → 最终 PASS); 最终判决决定流程走向(PASS/WARN 继续, FAIL 进入 Round 2 或终止)

5. **Critic 多轮迭代**: Round 1 FAIL 必须进入 Round 2, Round 2 FAIL 终止流程并写入 `## Critic Final Verdict`; 每轮都在 Exxx.md 追加对应的 Design 和 Critic Review 章节, 保留所有历史记录

6. **Override 检测**: 在 Step 2.5 开始前, 检查实验文档是否已存在且包含 `## Override` 章节; 若存在则跳过 Step 2.5, 直接进入 Step 3; Override 只能在 Round 2 FAIL 后人工添加

7. **verdict → status 映射**: 英文 verdict 只在 analyst JSON 输出中出现; 持久化到 tree.md 的是中文 status(被支持/被推翻/进行中), 由主控 PI 按 Step 8 映射表翻译; 使用 Step 7 合并后的 `final_verdict`, 而非直接使用 `primary.verdict`

8. **对抗验证流程**: Step 7 先调用 primary analyst, 然后检查 MCP llm-adversary 可用性; 若不可用跳过并标注, 若可用则截断 Exxx.md(移除 ## 结果), 调用 adversary analyst, 按合并规则产出 final_verdict; 截断必须确保 adversary 看不到 primary 的 reasoning/verdict, 保持 reviewer-independence

9. **Verdict 合并规则**: (1) primary == adversary → 采用 primary, 注明一致; (2) primary != adversary 且 adversary.confidence >= 0.7 → final = uncertain, 注明分歧降级; (3) primary != adversary 且 adversary.confidence < 0.7 → 采用 primary, 注明 adversary 质疑但信心不足

10. **增量写盘**: runner 每完成一条 command 立即更新 `experiment_log.jsonl`, 避免长时间运行后数据丢失

11. **Slurm 环境约束**: runner 必须检查 `$SLURM_JOB_ID`, 在管理节点上禁止直接执行训练任务

12. **失败记录**: 任一步骤失败, 在对应文档(experiments/Exxx.md)中记录错误, 并终止流程, 严禁静默容错或降级

13. **日期格式**: 统一使用 ISO 8601 格式 `YYYY-MM-DD`

14. **编号自增**: experiments 和 decisions 编号从 001 开始, 自动递增(读取现有文件数量 +1)
