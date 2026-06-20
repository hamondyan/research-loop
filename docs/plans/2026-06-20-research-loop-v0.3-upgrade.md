# research-loop v0.3 升级实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 research-loop 插件添加 critic agent (实验设计审查), adversary analyst (跨模型对抗验证), 和 journal resume (断点续跑) 三个核心能力

**Architecture:** 
- research-loop 是纯 markdown/prompt 插件, 无语言运行时
- 主控 PI 通过 markdown 文档 (commands/step.md) 定义流水线逻辑, 通过 Agent tool 调用子 agent
- 新增 2 个子 agent 定义 (agents/critic.md, agents/analyst-adversary.md)
- 复制 auto-research 的 MCP llm-chat server (MIT 协议) 提供外部 API 桥接
- Journal 用 JSONL 格式记录状态机检查点, 支持 resume

**Tech Stack:** 
- Markdown (agent 契约定义, 主控流水线逻辑)
- Python (MCP server, 从 auto-research 复制)
- JSONL (journal 文件格式)
- Claude Code Agent tool + MCP protocol

**关键约束:**
- 遵守 research-loop 的 7 大不变量 (中央状态唯一真相源, append-only, fail-fast 等)
- 不修改现有 agents/designer.md, agents/analyst.md 等
- hook-test.sh 必须仍 7/7 通过

---

## 任务分解概览

### Phase 1: 基础设施 (Task 1-3)
1. 复制 MCP llm-chat server + 写安装指南
2. 定义 critic agent 契约
3. 定义 analyst-adversary agent 契约

### Phase 2: 主控流水线 — Critic 集成 (Task 4-6)
4. 在 commands/step.md 插入 critic 调用逻辑 (单轮)
5. 实现 critic 4 维度 verdict 机器化聚合
6. 实现 critic 多轮迭代 (Round 1 FAIL → Round 2) + Override 检测

### Phase 3: 主控流水线 — Adversary 集成 (Task 7-9)
7. 在 commands/step.md 插入 adversary analyst 调用逻辑
8. 实现 experiments/Exxx.md 截断 (去掉 ## 结果 章节)
9. 实现 primary 与 adversary verdict 合并逻辑

### Phase 4: Journal Resume (Task 10-12)
10. 定义 journal JSONL schema + 在 step.md 插入 journal 写入逻辑
11. 实现 journal resume 逻辑 (step 开头检测未完成 journal)
12. 更新 experiments/Exxx.md 模板 (新增 Critic Review 和 Adversary Analyst 段落)

### Phase 5: Brief 模板与文档 (Task 13-16)
13. 更新 skills/research-orchestration/SKILL.md (增加 critic/adversary brief 模板)
14. 更新 README.md (新增对抗审校与断点续跑章节)
15. 更新 CLAUDE.md (同步不变量描述)
16. 编写 tests/e2e-v0.3-upgrade.md 手动测试剧本

### Phase 6: 验证与交付 (Task 17-18)
17. 运行 smoke test (临时仓库完整流程验证)
18. 验证 hook-test.sh 仍 7/7 通过, 提交所有变更

---

## Task 1: 复制 MCP llm-chat Server

**Files:**
- Create: `mcp-servers/llm-chat/server.py`
- Create: `mcp-servers/llm-chat/requirements.txt`  
- Create: `mcp-servers/llm-chat/README.md`

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p mcp-servers/llm-chat
```

- [ ] **Step 2: 复制 server.py**

```bash
cp /tmp/auto-research-src/mcp-servers/llm-chat/server.py mcp-servers/llm-chat/
```

验证: `head -5 mcp-servers/llm-chat/server.py` 应包含 MIT license 注释

- [ ] **Step 3: 复制 requirements.txt**

```bash
cp /tmp/auto-research-src/mcp-servers/llm-chat/requirements.txt mcp-servers/llm-chat/
cat mcp-servers/llm-chat/requirements.txt
```

预期输出: `httpx>=0.27,<1.0`

- [ ] **Step 4: 编写 README.md**

创建 `mcp-servers/llm-chat/README.md` 内容见下方代码块。

- [ ] **Step 5: 提交**

```bash
git add mcp-servers/
git commit -m "feat: add MCP llm-chat server for adversary analyst

Copied from wanshuiyin/Auto-claude-code-research-in-sleep (MIT).
Provides OpenAI-compatible API bridge for cross-model verification.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 定义 Critic Agent 契约

**Files:**
- Create: `agents/critic.md`

- [ ] **Step 1: 创建 critic.md 基础结构**

创建 `agents/critic.md` 内容见下方。

- [ ] **Step 2: 验证 4 维度 schema 完整性**

检查 critic.md 包含:
- discriminability 维度
- variable_count 维度  
- judge_criteria 维度
- commands 维度

- [ ] **Step 3: 提交**

```bash
git add agents/critic.md
git commit -m "feat: define critic agent contract

4-dimension pre-flight experiment design review:
- discriminability, variable_count, judge_criteria, commands
- Round 1/2 iteration support with suggested_revisions

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---


## Task 3: 定义 Analyst-Adversary Agent 契约

**Files:**
- Create: `agents/analyst-adversary.md`

- [ ] **Step 1: 创建 analyst-adversary.md**

创建 `agents/analyst-adversary.md`, 关键要求:
- 明确说明通过 MCP llm-adversary 调用
- 输入是截断版 Exxx.md (不含 `## 结果` 章节)
- 输出 schema: `{verdict, confidence, adversarial_reasoning}`
- 强调 reviewer-independence 原则

- [ ] **Step 2: 提交**

```bash
git add agents/analyst-adversary.md
git commit -m "feat: define analyst-adversary agent contract

Cross-model adversarial verification via MCP llm-chat.
Receives truncated Exxx.md (no primary reasoning), returns independent verdict.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4-6: Critic 集成到主控流水线

**Files:**
- Modify: `commands/step.md` (核心修改, ~200 行新增逻辑)

由于 research-loop 是纯 markdown 插件, "修改 step.md" 实际是修改主控 PI 的流水线描述文档。这是最复杂的任务, 分 3 个子任务完成。

### Task 4: 插入 Critic 单轮调用

- [ ] **Step 1: 读取现有 step.md 理解当前流水线**

```bash
head -100 commands/step.md
```

找到 designer 返回后、implementer 调用前的插入点。

- [ ] **Step 2: 在 designer 后插入 critic 调用逻辑**

在 `commands/step.md` 的 designer 步骤后新增段落:

```markdown
### 3.5 Critic Pre-flight Review

designer 返回实验设计后, 主控立即调用 critic agent 进行 4 维度审查。

**Brief 构造** (主控 PI 执行):
- 假设 ID 和假设文本 (从当前 tree.md 选中的假设)
- IDEA.md 摘要 (前 300 字)
- Codebase 约束 (从 IDEA.md 提取)
- designer 返回的完整 JSON
- 若是 Round 2, 追加 Round 1 critic.reasoning

**Agent 调用**:
```
Agent(
  subagent_type='critic',
  prompt=<上述 brief>,
  isolation=None
)
```

**输出**: critic 返回 JSON 包含:
- dimensions: {discriminability, variable_count, judge_criteria, commands}
- verdict: PASS | WARN | FAIL (机器聚合, 见下一步)
- reasoning
- suggested_revisions
```

- [ ] **Step 3: 实现 4 维度机器化聚合**

在 critic 调用后新增逻辑段落:

```markdown
**Verdict 聚合规则** (主控 PI 执行, 不信任 critic 自己写的 verdict 字段):

```python
# 伪代码示例 (主控在 markdown 里描述此逻辑)
dimensions = critic_output['dimensions']
fail_count = sum(1 for d in dimensions.values() if d['verdict'] == 'FAIL')
warn_count = sum(1 for d in dimensions.values() if d['verdict'] == 'WARN')

if fail_count > 0:
    aggregated_verdict = 'FAIL'
elif warn_count > 0:
    aggregated_verdict = 'WARN'
else:
    aggregated_verdict = 'PASS'
```

若 aggregated_verdict == 'PASS' 或 'WARN', 继续 implementer.
若 aggregated_verdict == 'FAIL', 进入下一任务的多轮逻辑.
```

- [ ] **Step 4: 更新 experiments/Exxx.md 写入逻辑**

在 designer 写 `## 实验设计 (Round 1)` 后, 主控写 `## Critic Review (Round 1)`:

```markdown
## Critic Review (Round 1)
**Verdict**: {aggregated_verdict}
**Dimensions**:
- discriminability: {verdict} — {reason}
- variable_count: {verdict} — {reason}
- judge_criteria: {verdict} — {reason}
- commands: {verdict} — {reason}

**Reasoning**: {critic.reasoning}
**Suggested revisions**:
{逐条列出 critic.suggested_revisions}
```

- [ ] **Step 5: 提交 Task 4**

```bash
git add commands/step.md
git commit -m "feat(step): add critic single-round review logic

Insert critic agent call after designer, before implementer.
- 4-dimension verdict aggregation (machine rule, not LLM top-level)
- Write Critic Review section to Exxx.md

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```


### Task 5: 实现 Critic 多轮迭代 (Round 1 FAIL → Round 2)

- [ ] **Step 1: 在 Task 4 的 FAIL 分支插入 Round 2 逻辑**

当 aggregated_verdict == 'FAIL' 且当前 round < 2:
1. 保留 Round 1 的 `## 实验设计` 和 `## Critic Review` 到 Exxx.md
2. 构造 designer Round 2 brief: 包含 Round 1 critic.reasoning + suggested_revisions
3. 调用 `Agent(subagent_type='designer', prompt=<Round 2 brief>, ...)`
4. designer 返回后, 写 `## 实验设计 (Round 2)` 到 Exxx.md
5. 再次调用 critic (用 Round 2 的设计)
6. 写 `## Critic Review (Round 2)` 到 Exxx.md
7. 若 Round 2 仍 FAIL, 进入 Task 6 的终止逻辑

- [ ] **Step 2: 更新 journal 写入**

每次 designer 和 critic 调用后追加 journal 行:
```jsonl
{"timestamp":"...", "step":"designer", "round":1, "status":"done"}
{"timestamp":"...", "step":"critic", "round":1, "status":"done", "verdict":"FAIL"}
{"timestamp":"...", "step":"designer", "round":2, "status":"done"}
{"timestamp":"...", "step":"critic", "round":2, "status":"done", "verdict":"PASS"}
```

- [ ] **Step 3: 提交**

```bash
git add commands/step.md
git commit -m "feat(step): add critic 2-round iteration

FAIL in round 1 triggers designer round 2 with critic feedback.
Preserve both rounds in Exxx.md for traceability.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: 实现 Override 机制 + Round 2 FAIL 终止

- [ ] **Step 1: Round 2 FAIL 终止逻辑**

当 critic Round 2 aggregated_verdict == 'FAIL':
1. 写 `## Critic Final Verdict` 到 Exxx.md:
   ```markdown
   ## Critic Final Verdict
   实验设计被 critic 拒绝 (2 轮后仍 FAIL). 查看上方 Critic Review 或添加 Override 段落强制继续.
   ```
2. 写 journal: `{"step":"terminate", "reason":"critic-rejected-after-2-rounds"}`
3. 更新 Exxx.md Status: `Status: 执行失败:critic-rejected`
4. 终止本轮 step, 输出提示给用户

- [ ] **Step 2: Override 检测逻辑**

在 Round 2 FAIL 终止前, 主控检测 Exxx.md 是否有 `## Override` 段落:
- 若无 → 执行终止
- 若有 → 跳过终止, 在 Override 段落追加 `**Acknowledged**: <ISO date>`, 直接进入 implementer

Override 段落格式:
```markdown
## Override
用户判定 critic 误判, 强制继续.
理由: [用户填写]
```

- [ ] **Step 3: 提交**

```bash
git add commands/step.md
git commit -m "feat(step): add critic round 2 FAIL termination + Override escape hatch

Round 2 FAIL writes terminate journal, stops step.
User can add ## Override section to force continue.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7-9: Adversary Analyst 集成

### Task 7: 插入 Adversary Analyst 调用

- [ ] **Step 1: 在 analyst (primary) 后插入 adversary 调用**

当 analyst (primary) 返回 verdict 后, 主控:
1. 检测 MCP llm-adversary 是否可用 (通过尝试调用 mcp__llm_adversary__chat)
2. 若不可用 → 跳过 adversary, 在 Exxx.md 写 "(对抗审校未配置, 仅 primary 判定)", 输出警告
3. 若可用 → 继续下一步

- [ ] **Step 2: 截断 Exxx.md (去掉 ## 结果 章节)**

主控读取当前 Exxx.md, 用正则匹配 `## 结果` 章节开头, 截断之前的部分作为 adversary brief 输入。

伪代码:
```python
exxx_content = Read('experiments/E001.md')
# 找到 "## 结果" 的行号
result_section_start = exxx_content.find('\n## 结果\n')
if result_section_start != -1:
    truncated = exxx_content[:result_section_start]
else:
    truncated = exxx_content  # 若还没写结果段, 全文即截断版
```

- [ ] **Step 3: 调用 adversary via MCP**

```markdown
Agent(
  subagent_type='analyst-adversary',
  prompt=f"""
假设 {hypothesis_id}: {hypothesis_text}
判别标准: {judge_criteria}

实验记录 (截断版, 不含其他审查者分析):
---
{truncated_exxx_content}
---

独立判定假设是否被支持, 返回 JSON.
  """,
  isolation=None
)
```

- [ ] **Step 4: 提交**

```bash
git add commands/step.md
git commit -m "feat(step): add adversary analyst call with Exxx.md truncation

Call analyst-adversary via MCP after primary analyst.
Truncate Exxx.md at ## 结果 to ensure reviewer independence.
Skip if MCP unavailable (with warning).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: 实现 Verdict 合并逻辑

- [ ] **Step 1: 主控合并 primary 与 adversary verdict**

伪代码:
```python
if primary.verdict == adversary.verdict:
    final_verdict = primary.verdict
    final_reasoning = f"{primary.reasoning}\n\n(对抗审校一致: {adversary.adversarial_reasoning})"
elif adversary.confidence >= 0.7:
    final_verdict = 'uncertain'
    final_reasoning = f"Primary: {primary.verdict} (conf {primary.confidence})\n{primary.reasoning}\n\nAdversary: {adversary.verdict} (conf {adversary.confidence})\n{adversary.adversarial_reasoning}\n\n判定分歧且对抗审校高置信度, 降级为 uncertain."
else:
    final_verdict = primary.verdict
    final_reasoning = f"{primary.reasoning}\n\n(对抗审校质疑 [{adversary.verdict}] 但置信度低 {adversary.confidence}: {adversary.adversarial_reasoning})"
```

- [ ] **Step 2: 写 ## 结果 到 Exxx.md**

```markdown
## 结果

**Primary Analyst** (Claude):
- Verdict: {primary.verdict}
- Confidence: {primary.confidence}
- Reasoning: {primary.reasoning}

**Adversarial Analyst** ({model_name} via MCP):
- Verdict: {adversary.verdict}
- Confidence: {adversary.confidence}
- Reasoning: {adversary.adversarial_reasoning}

**Final Verdict**: {final_verdict} {一致/分歧说明}
```

- [ ] **Step 3: 提交**

```bash
git add commands/step.md
git commit -m "feat(step): implement primary/adversary verdict merging

Conflict + high adversary confidence (≥0.7) → final=uncertain.
Consistent → adopt primary (more complete reasoning).
Write both analysts' outputs to Exxx.md for traceability.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10-12: Journal Resume

### Task 10: 定义 Journal Schema + 写入逻辑

- [ ] **Step 1: 在 step.md 开头定义 journal 文件格式**

```markdown
## Journal 文件格式

每次 step 执行时, 主控在 `.research/experiments/Exxx.journal` 追加状态行 (JSONL 格式).

Schema:
- `{"step":"init", "hypothesis_id":"H1.1", "status":"started", "timestamp":"..."}`
- `{"step":"designer", "round":N, "status":"done", "timestamp":"..."}`
- `{"step":"critic", "round":N, "status":"done", "verdict":"PASS|WARN|FAIL", "timestamp":"..."}`
- `{"step":"implementer", "status":"done", "timestamp":"..."}`
- `{"step":"runner", "command_index":i, "status":"done|fail", "error":"...", "timestamp":"..."}`
- `{"step":"analyst-primary", "status":"done", "verdict":"...", "timestamp":"..."}`
- `{"step":"analyst-adversary", "status":"done", "verdict":"...", "timestamp":"..."}`
- `{"step":"finalize", "status":"done", "timestamp":"..."}`
- `{"step":"terminate", "reason":"...", "timestamp":"..."}`
```

- [ ] **Step 2: 在每个子 agent 返回后追加 journal 行**

在 step.md 的各步骤后插入 journal 写入逻辑:
```markdown
主控调用 Write(
  file_path=f'.research/experiments/{experiment_id}.journal',
  content=journal_line + '\n',
  mode='append'
)
```

- [ ] **Step 3: 提交**

```bash
git add commands/step.md
git commit -m "feat(step): define journal JSONL schema and write logic

Append state machine checkpoints to Exxx.journal after each sub-agent.
Supports resume by tracking done/fail status per step.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: 实现 Journal Resume 逻辑

- [ ] **Step 1: 在 step.md 开头插入 resume 检测**

```markdown
## Step 流程开始

1. 读 tree.md, 选取待验假设 (Status=待验)
2. 扫描 `.research/experiments/` 目录, 查找针对该假设的未完成 journal:
   - 列出所有 E*.journal 文件
   - 逐个读取, 检查 hypothesis_id 是否匹配
   - 若最后一行不是 `step=finalize,status=done` 也不是 `step=terminate` → 未完成
3. 若找到未完成 journal:
   - 解析所有行, 构建已完成步骤列表
   - 确定续跑点 (首个 non-done 步骤)
   - 输出提示: "检测到未完成实验 {experiment_id}, 从 {step} 续跑"
   - 跳到对应步骤继续执行
4. 若无未完成 journal:
   - 创建新实验 (experiment_id = 下一个编号, 如 E003)
   - 创建 Exxx.md 和 Exxx.journal
   - 从 designer round 1 开始
```

- [ ] **Step 2: 实现各步骤的 resume 跳过逻辑**

伪代码示例:
```python
if journal_has_step_done('designer', round=1):
    print("跳过 designer round 1 (已完成)")
    designer_output = load_from_journal_or_exxx_md()
else:
    designer_output = Agent(subagent_type='designer', ...)
    write_journal({"step":"designer", "round":1, "status":"done"})
```

对每个步骤 (designer/critic/implementer/runner/analyst) 应用此模式。

- [ ] **Step 3: 提交**

```bash
git add commands/step.md
git commit -m "feat(step): implement journal resume from breakpoint

Detect incomplete Exxx.journal at step start, skip completed sub-agents.
Resume from first non-done step (e.g., runner command 2 after timeout).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: 更新 experiments/Exxx.md 模板

- [ ] **Step 1: 在 step.md 中明确 Exxx.md 的完整结构**

```markdown
## experiments/Exxx.md 模板结构

```
# E001: {hypothesis_text}

**Hypothesis ID**: H1.1
**Created**: 2026-06-20T14:30:00Z
**Status**: 进行中 | 被支持 | 被推翻 | 执行失败:critic-rejected

## 实验设计 (Round 1)
{designer round 1 输出的 JSON, 格式化为 markdown}

## Critic Review (Round 1)
**Verdict**: FAIL
**Dimensions**: ...

{若有 Round 2}
## 实验设计 (Round 2)
{designer round 2 输出}

## Critic Review (Round 2)
**Verdict**: PASS

## 实现摘要
{implementer 输出}

## 执行记录
### Baseline
- 状态: success
- 指标: {...}

### Treatment
- 状态: success
- 指标: {...}

## 结果
**Primary Analyst**: ...
**Adversarial Analyst**: ...
**Final Verdict**: ...

{若 critic round 2 FAIL 且用户 override}
## Override
用户判定 critic 误判, 强制继续.
理由: ...
**Acknowledged**: 2026-06-20T15:00:00Z
```
```

- [ ] **Step 2: 提交**

```bash
git add commands/step.md
git commit -m "docs(step): define complete Exxx.md template structure

Clarify Round 1/2 sections, Critic Review format, Adversarial Analyst section.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---


## Task 13: 更新 research-orchestration SKILL.md

**Files:**
- Modify: `skills/research-orchestration/SKILL.md`

- [ ] **Step 1: 在 SKILL.md 新增 critic brief 模板段落**

```markdown
### Critic Brief 模板

主控在调用 critic agent 时构造 brief:

```
你是实验设计的对抗性审查员.

假设: {hypothesis_id} {hypothesis_text}
研究动机: {IDEA.md 前 300 字}
Codebase 约束: {从 IDEA.md 提取的 gpu/hours/baseline 等}

待审查的实验设计 (Round {N}):
{designer 返回的 JSON, 含 variables/metrics/judge_criteria/commands}

{若 round=2, 追加}
上一轮你的质疑:
{Round 1 critic.reasoning}
请检查 designer 的修订是否真正回应了质疑, 而非补丁式修饰.

按 4 维度审查并返回 JSON:
{schema见 agents/critic.md}
```
```

- [ ] **Step 2: 新增 adversary brief 模板段落**

```markdown
### Adversary Analyst Brief 模板

主控在调用 analyst-adversary 时:
1. 读取 experiments/Exxx.md, 截断到 `## 结果` 之前
2. 构造 brief:

```
你是对抗性结果验证员, 通过外部 API 独立审查实验结果.

假设 {hypothesis_id}: {hypothesis_text}
判别标准: {judge_criteria}

实验记录 (截断版, 不含其他审查者分析):
---
{truncated_exxx_content}
---

独立判定假设是否被支持, 返回 JSON: {schema见 agents/analyst-adversary.md}
```
```

- [ ] **Step 3: 提交**

```bash
git add skills/research-orchestration/SKILL.md
git commit -m "docs(orchestration): add critic and adversary brief templates

Define how main controller constructs briefs for new agents.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: 更新 README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 在 README 新增 "对抗审校" 章节**

在 "核心特性" 章节后插入:

```markdown
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
```

- [ ] **Step 2: 新增 "断点续跑" 章节**

```markdown
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
```

- [ ] **Step 3: 提交**

```bash
git add README.md
git commit -m "docs: add adversarial review and journal resume sections

Document critic agent, adversary analyst, and journal resume features.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: 更新 CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 在不变量章节同步 critic/adversary 的约束**

```markdown
## Critic 与 Adversary 的约束

1. **Critic 4 维度 verdict 机器化聚合**: 主控不信任 critic 自己写的 top-level verdict, 按 4 维度结果聚合 (任一 FAIL → 最终 FAIL)
2. **Adversary reviewer-independence**: 永不将 primary 的 reasoning 传给 adversary, 只传截断版 Exxx.md
3. **Journal append-only**: 每个步骤只追加一次, 不覆盖已有行
4. **Override 不能在 Round 1 用**: Round 1 FAIL 必须经过 Round 2, 用户至少看到两次 critic 反馈才能 override
```

- [ ] **Step 2: 提交**

```bash
git add CLAUDE.md
git commit -m "docs: sync CLAUDE.md invariants with v0.3 features

Add critic/adversary constraints and journal rules.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: 编写 E2E 测试剧本

**Files:**
- Create: `tests/e2e-v0.3-upgrade.md`

- [ ] **Step 1: 创建测试剧本文件**

创建 `tests/e2e-v0.3-upgrade.md`, 包含 5 个测试用例:

```markdown
# E2E Test: v0.3 Upgrade Features

## Prerequisite
- 临时 git 仓库 + toy IDEA
- MCP llm-adversary 已配置 (可用 DeepSeek 免费 API)

## Test 1: Critic Round 1 FAIL → Round 2 PASS
1. `/research-loop:init toy_idea.md` 创建假设 H1
2. `/research-loop:step`
3. 预期: designer(round 1) → critic FAIL → designer(round 2) → critic PASS → 继续
4. 检查: experiments/E001.md 有两个 "## 实验设计 (Round N)" 段落
5. 检查: E001.journal 有 designer(round 1), critic(round 1, FAIL), designer(round 2), critic(round 2, PASS)

## Test 2: Critic Round 2 FAIL + Override
1. 手动触发 critic 连续 2 轮 FAIL (修改 designer prompt 让它返回明显缺陷设计)
2. 预期: 流程终止, journal 写 terminate
3. 用户在 E001.md 末尾加 `## Override\n用户判定 critic 误判, 强制继续`
4. 再次 `/research-loop:step`
5. 预期: 检测到 Override, 从 implementer 继续

## Test 3: Adversary 分歧 → uncertain
1. 正常 step 流程, 让 primary 和 adversary 得出不同 verdict
2. 预期: final_verdict = uncertain
3. 检查: E001.md 的 "## 结果" 章节同时显示两者 reasoning
4. 检查: tree.md 假设状态为 "进行中"

## Test 4: Runner 失败 → Journal Resume
1. step 流程走到 runner, 第 2 条命令故意失败 (timeout 或 OOM)
2. 预期: journal 记录 runner[1]=fail, 流程终止
3. 用户修复问题 (增加资源配额)
4. 再次 `/research-loop:step`
5. 预期: 跳过 designer/critic/implementer, 从 runner[1] 续跑
6. 检查: E001.journal 追加了新的 runner[1]=done 行

## Test 5: MCP 不可用 → 跳过 Adversary
1. 临时 unregister MCP llm-adversary
2. `/research-loop:step`
3. 预期: 警告 "MCP llm-adversary 未配置", 只用 primary 判定
4. 检查: E001.md 的 "## 结果" 只有 Primary Analyst, 无 Adversarial
```

- [ ] **Step 2: 提交**

```bash
git add tests/e2e-v0.3-upgrade.md
git commit -m "test: add e2e manual test script for v0.3 features

5 test cases: critic iteration, override, adversary conflict, journal resume, MCP fallback.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: Smoke Test

**不创建文件, 手动操作验证**

- [ ] **Step 1: 创建临时测试仓库**

```bash
cd /tmp
mkdir research-loop-smoke-test
cd research-loop-smoke-test
git init
echo "# Toy Research" > README.md
git add README.md
git commit -m "init"
```

- [ ] **Step 2: 创建 toy IDEA**

创建 `toy_idea.md`:
```markdown
# IDEA: 测试 v0.3 功能

测试 critic 和 adversary 是否正常工作.

假设: H1 - 增加权重能提升性能
```

- [ ] **Step 3: 运行完整流程**

```
/research-loop:init toy_idea.md
/research-loop:step
```

观察:
- designer round 1 → critic (预期 PASS 或 WARN, 因为 toy 设计简单)
- implementer → runner → analyst-primary → analyst-adversary
- 检查 experiments/E001.md 有 Critic Review 和 Adversarial Analyst 段落
- 检查 E001.journal 有完整状态序列
- 检查 tree.md 假设状态更新

- [ ] **Step 4: 触发 critic FAIL 测试 (可选)**

修改 designer prompt 让它返回缺陷设计, 观察 Round 2 逻辑.

- [ ] **Step 5: 触发 runner 失败测试 journal resume (可选)**

在 runner 命令里故意写错路径, 观察 journal fail 记录, 然后修复后再 step 验证 resume.

- [ ] **Step 6: 清理**

```bash
cd /tmp
rm -rf research-loop-smoke-test
```

---

## Task 18: 验证 hook-test.sh + 最终提交

**Files:**
- 验证: `tests/hook-test.sh`

- [ ] **Step 1: 运行 hook 测试**

```bash
cd /public/home/chenglongyan/code/research-loop
bash tests/hook-test.sh
```

预期输出: `7/7 tests passed`

若失败, 检查 v0.3 升级是否意外修改了 hooks/session-start 或相关逻辑.

- [ ] **Step 2: 最终 commit (汇总所有变更)**

```bash
git status
```

确认已提交:
- mcp-servers/llm-chat/*
- agents/critic.md, agents/analyst-adversary.md
- commands/step.md (大改)
- skills/research-orchestration/SKILL.md
- README.md, CLAUDE.md
- tests/e2e-v0.3-upgrade.md

- [ ] **Step 3: 打 tag (可选)**

```bash
git tag v0.3.0 -m "research-loop v0.3: critic + adversary + journal"
```

---

## 验收清单 (来自设计文档第 9.4 节)

完成所有 Task 后, 逐条验证:

- [ ] Critic round 1 FAIL 触发 designer round 2, Exxx.md 保留两轮设计
- [ ] Critic round 2 FAIL 终止流程, 用户可 Override
- [ ] Critic 4 维度 verdict 机器化聚合 (任一 FAIL → 最终 FAIL)
- [ ] Adversary 收到截断版 Exxx.md (无 `## 结果` 章节)
- [ ] Primary 与 adversary 分歧 + adversary.confidence ≥ 0.7 → final = uncertain
- [ ] Runner 失败后 journal 记录断点, 下次 step 从断点续跑
- [ ] Journal resume 跳过已完成步骤, 不重跑 designer/implementer
- [ ] MCP 不可用时跳过 adversary + 警告, 不阻断
- [ ] 所有失败场景写 journal + Exxx.md, 无静默容错
- [ ] hook-test.sh 仍 7/7 通过

---

## Self-Review Checklist (plan author self-check)

**1. Spec coverage:**
- ✓ Critic agent 4 维度审查 + Round 1/2 + Override (Task 2, 4-6)
- ✓ Adversary analyst + 截断 + verdict 合并 (Task 3, 7-9)
- ✓ Journal JSONL + resume 逻辑 (Task 10-12)
- ✓ MCP llm-chat server (Task 1)
- ✓ Brief 模板更新 (Task 13)
- ✓ 文档更新 (Task 14-16)
- ✓ 测试与验收 (Task 17-18)

**2. Placeholder scan:**
- 无 TBD/TODO
- 所有 "伪代码" 段落都标注为 "伪代码示例 (主控在 markdown 里描述此逻辑)", 不是真的要写代码文件
- 对于 markdown 插件, "实现"即"修改 commands/step.md 的流程描述", 已在各 Task 明确

**3. Type consistency:**
- Journal schema (step/round/status/verdict) 在 Task 10 定义, Task 11-12 使用一致
- Exxx.md 段落名称 (## 实验设计 / ## Critic Review / ## 结果) 在 Task 4-12 使用一致
- verdict 值域 (supported/refuted/uncertain) 在设计文档和本计划中一致

**4. Gaps:**
- 无遗漏的设计功能点

---

