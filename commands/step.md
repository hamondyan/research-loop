---
description: 跑一轮假设验证循环(designer → critic → implementer → runner → analyst → 更新状态)
---

# /research-loop:step

编排 5 个无状态子 agent 完成一轮假设验证循环: 从假设树选取待验假设 → 设计实验 → 预检审查 → 实现代码 → 执行实验 → 分析结果 → 更新假设树和决策记录.

## 前置条件

- 当前目录是 git 仓库
- `.research/tree.md` 存在
- `.research/tree.md` 中至少有 1 个待验假设(`Status: 待验`)
- 当前在 slurm 管理节点或已在计算节点上

## 执行流程

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
1. 从 4 个维度独立审查:
   - **Discriminative Power**: 实验能否明确区分假设成立/不成立
   - **Feasibility**: 资源/时间预算是否合理, commands 是否可执行
   - **Alignment**: 实验设计是否对齐假设原意, 无偏移或过度简化
   - **Clarity**: judge_criteria 是否可操作, 避免模糊表述
2. 每个维度返回机器判决: PASS / WARN / FAIL
3. FAIL 必须给出具体修正方向, WARN 给出改进建议
4. 返回结构化 JSON:
   {{
       "dimensions": [
           {{
               "name": "Discriminative Power",
               "verdict": "PASS|WARN|FAIL",
               "reasoning": "判定依据, 2-3 句话",
               "suggestions": "修正方向或改进建议, FAIL 必填, WARN 选填"
           }},
           // ... 其他 3 个维度
       ]
   }}

返回 JSON 即可, 无需其他输出.
""",
    subagent_type="critic",
    isolation="worktree",
    description="预检实验设计"
)
```

**判决聚合机制**(机器 verdict):
- 统计 4 个维度的 verdict: `fail_count`, `warn_count`, `pass_count`
- 聚合规则:
  - `fail_count > 0` → 最终判决 **FAIL**
  - `fail_count == 0 且 warn_count > 0` → 最终判决 **WARN**
  - `fail_count == 0 且 warn_count == 0` → 最终判决 **PASS**

**Round 1 后处理**:
- 若最终判决为 **PASS** 或 **WARN**: 进入 Step 3(创建实验文档), 继续流程
- 若最终判决为 **FAIL**: 进入 Round 2(设计迭代)

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

#### Override 机制

若实验文档 `.research/experiments/Exxx.md` 中存在 `## Override` 章节(人工事后添加), 则:
- **跳过整个 Step 2.5**(不调用 critic)
- **直接进入 Step 3**, 使用 Round 2 的 designer 设计(若无 Round 2 则用 Round 1)
- Override 只能在 Round 2 FAIL 终止后使用, 不影响 Round 1 FAIL(Round 1 FAIL 必须先进 Round 2)

**检测 Override 的时机**: 在 Step 2 designer 返回后, Step 2.5 开始前, 检查实验文档是否已存在且包含 `## Override` 章节. 若存在, 跳过 Step 2.5.

### Step 3: 创建实验文档 experiments/Exxx.md

解析 designer 返回的 JSON, 生成实验编号(E001, E002, ...), 写入 `.research/experiments/Exxx.md`.

**文档结构**:

```markdown
# Exxx: [假设 ID + 动作 slug]

**Hypothesis**: [hypothesis_id] [hypothesis_text]
**Status**: 待执行
**Created**: [今天日期 YYYY-MM-DD]

## Design (Round 1)

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
- **Discriminative Power**: [verdict] — [reasoning]
  [若有 suggestions: "→ 修正方向: [suggestions]"]
- **Feasibility**: [verdict] — [reasoning]
  [若有 suggestions: "→ 修正方向: [suggestions]"]
- **Alignment**: [verdict] — [reasoning]
  [若有 suggestions: "→ 修正方向: [suggestions]"]
- **Clarity**: [verdict] — [reasoning]
  [若有 suggestions: "→ 修正方向: [suggestions]"]

[若进入 Round 2, 追加以下章节]

## Design (Round 2)

[同 Round 1 格式, 使用 designer Round 2 的 JSON]

## Critic Review (Round 2)

[同 Round 1 格式, 使用 critic Round 2 的反馈]

[若 Round 2 仍 FAIL, 追加以下章节]

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

[若无 Round 2 FAIL, 继续正常流程]

## 执行记录

[待 runner 回填]

## 结果

[待 analyst 回填]
```

**章节生成规则**:
1. `## Design (Round 1)` 和 `## Critic Review (Round 1)` 总是生成
2. 若 Round 1 FAIL 进入 Round 2, 追加 `## Design (Round 2)` 和 `## Critic Review (Round 2)`
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

### Step 7: 调用 analyst agent 分析结果

调用 `analyst` agent, 传递实验结果和假设. 契约见 `agents/analyst.md`:

```python
analyst_result = Agent(
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
```

**关键约束**:
- analyst 只分析已有数据, 不运行新实验
- `verdict` 字段必须是 `supported` / `refuted` / `uncertain` 之一(英文, 只在 analyst JSON 输出中出现)
- 若数据不足无法判定, 返回 `verdict: "uncertain"` 并说明原因

### Step 8: 更新假设树和创建决策记录

主控 PI 将 analyst 的英文 verdict 翻译为中文 tree status, 映射规则:

| analyst verdict | tree.md Status |
|---|---|
| supported | 被支持 |
| refuted | 被推翻 |
| uncertain | 进行中(保持, 不结案) |

**8.1 更新 `.research/tree.md`**(用精确 Edit, 不整文件重写, Status 不加粗):

```markdown
### H1.1: 增加 instruction token 的 loss 权重能提升否定词敏感度
Status: 被支持
Evidence: E001
Parent: H1
```

- 找到对应假设节点, 把 `Status:` 行从 `待验`/`进行中` 改为映射后的值
- 把实验 ID 追加到 `Evidence:` 行(Evidence 只增不删; 原为 `(empty)` 则替换为该 ID)

**8.2 创建决策记录 `.research/decisions/Dxxx.md`**(仅在 verdict=supported/refuted, 即假设状态变更时):

```markdown
# Dxxx: [hypothesis_id] [被支持/被推翻]

**Hypothesis**: [hypothesis_id] [hypothesis_text]
**Date**: [今天日期 YYYY-MM-DD]
**Experiment**: [Exxx]
**Verdict**: [supported/refuted] (confidence [confidence])

## 结论

[reasoning]

## 数据对比

**baseline**: [baseline metrics]
**treatment**: [treatment metrics]

## 重规划

trigger_replan: [true/false]
[若 true, 说明受影响的兄弟/父假设和派生的新子假设]
```

若 `verdict=uncertain`, 不创建决策记录, 仅在实验文档结果章节记录, 假设保持 `进行中`.

若 `.research/decisions/` 目录不存在, 先创建.

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

7. **verdict → status 映射**: 英文 verdict 只在 analyst JSON 输出中出现; 持久化到 tree.md 的是中文 status(被支持/被推翻/进行中), 由主控 PI 按 Step 8 映射表翻译

8. **增量写盘**: runner 每完成一条 command 立即更新 `experiment_log.jsonl`, 避免长时间运行后数据丢失

9. **Slurm 环境约束**: runner 必须检查 `$SLURM_JOB_ID`, 在管理节点上禁止直接执行训练任务

10. **失败记录**: 任一步骤失败, 在对应文档(experiments/Exxx.md)中记录错误, 并终止流程, 严禁静默容错或降级

11. **日期格式**: 统一使用 ISO 8601 格式 `YYYY-MM-DD`

12. **编号自增**: experiments 和 decisions 编号从 001 开始, 自动递增(读取现有文件数量 +1)
