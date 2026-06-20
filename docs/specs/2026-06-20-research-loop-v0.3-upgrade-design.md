# research-loop v0.3 升级设计

- 日期: 2026-06-20
- 状态: 待批准
- 形态: research-loop 插件 v0.3 升级 (基于 v0.1.0)
- 范围: 3 件事 (critic agent + adversary analyst + journal resume), v0.2 与 v0.3 合并交付

## 1. 升级目标

在不破坏 research-loop 现有 "中央状态唯一真相源 + 无状态子 agent" 架构的前提下, 增加 3 个能力:

1. **Critic agent** — designer 后插入对抗性审查, 4 维度判定实验设计可判别性
2. **Adversary analyst** — 通过 MCP llm-chat 调外部 OpenAI 兼容 API (DeepSeek/GPT 等) 做对抗审校, 与 primary analyst 并列, 分歧时降级为 uncertain
3. **Journal resume** — `experiments/Exxx.journal` 状态机记录每个步骤完成情况, 失败后下次 step 从断点续跑, 不重跑已完成的子 agent

## 2. 借鉴策略说明

### 2.1 主要借鉴 auto-research

- **跨模型对抗审校协议** (auto-research 的 reviewer-independence 铁律): 永不将 primary 的 reasoning 传给 adversary, 只传截断版 experiments/Exxx.md
- **MCP llm-chat server**: 直接复制 `mcp-servers/llm-chat/server.py` (MIT 协议), 通用 OpenAI 兼容 API 桥接
- **多层 verdict 状态机** (简化版): 不做 6 态 verdict (PASS/WARN/FAIL/BLOCKED/ERROR/NOT_APPLICABLE), 只用 3 态 (PASS/WARN/FAIL)

### 2.2 不借鉴

- **pi-flow 的 JS workflow runtime**: 实验逐步推进, 不需要 parallel/pipeline 编排
- **pi-flow 的多后端 (codex/claude CLI)**: 插件仍为 Claude Code 制作, 只通过 MCP 引入外部 API 校验
- **auto-research 的 Research Wiki**: 现有 tree.md (append-only) + decisions/Dxxx.md 已覆盖跨 session 记忆需求

## 3. 架构总览

### 3.1 升级后的 step 流水线

```
1.  读 tree.md → 选待验假设 → 检测 .research/experiments/E???.journal 是否有未完成 → 续跑或新建
2.  designer (round=1) → 写 experiments/Exxx.md 的 ## 实验设计 (Round 1)
3.  critic → 判定 PASS/WARN/FAIL
    ├─ PASS / WARN  → 进入 4
    ├─ FAIL (round < 2) → designer 收到 critic.reasoning 重设计 (round=2) → 回到 critic
    └─ FAIL (round = 2) → 写 ## Critic Final Verdict 到 Exxx.md, 终止本轮 step
4.  implementer → 写 ## 实现摘要
5.  runner (逐条命令) → 写 ## 执行记录
6.  analyst-primary (Claude 内部)  ┐
                                   ├─ 主控合并两者 verdict, 写 ## 结果
    analyst-adversary (MCP 外部)  ┘   分歧 → uncertain
7.  翻译 verdict → 更新 tree.md → (supported/refuted) 写 decisions/Dxxx.md
8.  重写 DASHBOARD.md → 输出摘要
```

### 3.2 三个新角色定位

| 角色 | 文件 | 后端 | 输入 | 输出 |
|---|---|---|---|---|
| **critic** | `agents/critic.md` | Claude (Agent tool) | designer 的实验设计 JSON + 假设上下文 | `{verdict: PASS\|WARN\|FAIL, dimensions, reasoning, suggested_revisions}` |
| **analyst-primary** | `agents/analyst.md` (现有, 不改名) | Claude (Agent tool) | experiments/Exxx.md 完整内容 + 假设 + judge_criteria | `{verdict, confidence, reasoning}` |
| **analyst-adversary** | `agents/analyst-adversary.md` | OpenAI 兼容 API (MCP llm-chat) | **截断版** Exxx.md (去掉 `## 结果` 章节) + 假设 + judge_criteria | `{verdict, confidence, adversarial_reasoning}` |

### 3.3 必须保留的不变量

1. 中央状态唯一真相源, 只有主控 PI 读写 `.research/`
2. append-only 编号文件, experiments/Exxx.md 永不删改
3. verdict→status 三套词汇映射 (supported→被支持, refuted→被推翻, uncertain→进行中)
4. tree.md Status 行不加粗, Evidence 只增不删
5. Slurm 约束: runner 必检查 `$SLURM_JOB_ID`, 禁止管理节点跑训练
6. 严禁擅自建分支 (init 必须用户明确同意)
7. Fail-fast 严禁静默容错: 子 agent 失败立即记录并终止本轮

## 4. Critic Agent 详细设计

### 4.1 职责边界

critic 只做 **实验设计的可判别性审查**, 不做实现审查、不做结果审查。审 4 个维度:

1. **可判别性** (discriminability) — 实验能区分假设成立/不成立吗? 有 baseline 和对照吗?
2. **变量数** (variable_count) — 变量 ≤ 3 吗? 多变量是否有交互效应难以解释?
3. **judge_criteria 可操作性** — 是否含具体阈值、统计显著性检验、比较方式?
4. **commands 完整性** — 路径完整、参数齐全, 资源预算合理 (gpu/hours)?

不审: 假设本身合理性 (init 阶段的事)、代码实现细节 (implementer 自检)、结果对错 (analyst)。

### 4.2 输入契约 (主控构造的 brief)

```
你是实验设计的对抗性审查员.

假设: H1.1 增加 instruction token 的 loss 权重能提升否定词敏感度
研究动机: <300 字 IDEA.md 摘要>
Codebase 约束: gpu=4*8h, baseline_ckpt=...

待审查的实验设计 (Round {N}):
{designer 返回的 JSON, 含 variables/metrics/judge_criteria/commands}

{若 round=2, 追加}
上一轮你的质疑:
{Round 1 critic.reasoning}
请检查 designer 的修订是否真正回应了质疑, 而非补丁式修饰.

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

### 4.3 Verdict 机器化聚合规则 (主控执行)

主控收到 critic 输出后, 按 4 维度结果机器化聚合最终 verdict, **不信任 critic 自己写的 top-level verdict 字段**:

| 4 维度状态 | 最终 verdict |
|---|---|
| 任一维度 FAIL | FAIL |
| 无 FAIL, 任一维度 WARN | WARN |
| 全部 PASS | PASS |

防止 critic 在 reasoning 里说 "discriminability 严重缺陷", 却把 top-level verdict 写成 PASS 这种自相矛盾的输出。

### 4.4 多轮迭代逻辑 (方案 B)

```
Round 1: designer → critic
  ├─ PASS/WARN → implementer
  └─ FAIL → Round 2: designer (收到 Round 1 critic.reasoning) → critic
              ├─ PASS/WARN → implementer
              └─ FAIL → 终止本轮 step, 写 ## Critic Final Verdict
```

**保险措施** (防止 LLM 反馈循环退化为补丁式迭代):

1. **强制保留首版 designer 输出**: experiments/Exxx.md 写 `## 实验设计 (Round 1)` 段落, 不被 Round 2 覆盖
2. **轮次硬上限 = 2**: 首版 + 1 次修订, 第 3 轮 FAIL 立即终止
3. **每轮 critic 的 reasoning 都写入 experiments/Exxx.md**: `## Critic Review (Round N)` 段落, 不静默累积
4. **journal 区分轮次**: `{"step":"designer","round":1}` 和 `{"step":"designer","round":2}`, resume 时能识别处于哪一轮

### 4.5 experiments/Exxx.md 的写法

```markdown
## 实验设计 (Round 1)
[designer 首版输出]

## Critic Review (Round 1)
**Verdict**: FAIL
**Dimensions**:
- discriminability: FAIL — baseline 与 treatment 都用同一权重设置, 无法区分
- variable_count:   PASS
- judge_criteria:   WARN — 阈值 15% 缺乏统计检验
- commands:         PASS

**Reasoning**: ...
**Suggested revisions**:
1. ...
2. ...

## 实验设计 (Round 2)
[designer 修订版输出]

## Critic Review (Round 2)
**Verdict**: PASS  (或 FAIL → 终止)
...
```

### 4.6 Override 机制 (容错出口)

critic 可能误判, 强制阻断会卡死研究流程。提供逃生舱:

- 用户在 `experiments/Exxx.md` 末尾手动加 `## Override\n[理由]` 段落
- 主控在 Round 2 FAIL 终止前先扫一遍 Exxx.md 看有没有 `## Override`, 有则跳过 critic 直接进 implementer, 在 Override 段写 `**Acknowledged**: <ISO date>`
- Override **不能在 Round 1 用** — Round 1 失败必须经过 Round 2 重设计, 用户至少看到两次 critic 反馈才能 override

## 5. Adversary Analyst 详细设计

### 5.1 核心原则: Reviewer Independence

严格遵守 auto-research 的 reviewer-independence 铁律 — **永不将 primary analyst 的总结/诠释/建议传给 adversary**。只传 experiments/Exxx.md 的截断版本, 让 adversary 独立从原始数据推导结论。

### 5.2 输入差异

| Analyst | 输入 |
|---|---|
| **primary** | experiments/Exxx.md 完整内容 (含设计 + 执行记录 + metrics) |
| **adversary** | **截断版** Exxx.md (去掉 `## 结果` 章节, 即不含 primary 的 verdict 和 reasoning) |

主控在调用 adversary 前, 读取 Exxx.md, 用正则截断到 `## 结果` 之前的部分。

### 5.3 为什么截断

如果 adversary 看到 primary 的 reasoning, 即使 prompt 里说 "独立判定", 它也会被 primary 的论证方向引导。auto-research 实证发现 codex-reply 模式 (延续线程) 会让审校器从对手变成辩护者, 分数从 3/10 吹到 8/10。

截断后, adversary 只能读原始数据 (metrics / 执行记录), 自己推导。一致 → 结论稳固, 分歧 → 数据有多重解读可能 → 降级为 uncertain。

### 5.4 Adversary Brief

```
你是对抗性结果验证员, 通过外部 API 独立审查实验结果.

任务: 独立判定假设是否被实验支持, 不参考其他审查者的意见.

假设 H1.1: 增加 instruction token 的 loss 权重能提升否定词敏感度
判别标准: 若否定指令的 success_rate 比肯定指令低 ≥15%, 且 action_error 显著更高 (t-test p<0.05), 则假设成立

实验记录 (只含设计与数据, 不含其他审查者的分析):
--- experiments/E001_negation_weight.md (截断版) ---
## 实验变量
...

## 评估指标
...

## 执行记录
**baseline**: 状态 success, 指标 {"success_rate": 0.82, "action_error": 0.09}
**treatment**: 状态 success, 指标 {"success_rate": 0.61, "action_error": 0.23}
---

要求:
1. 根据 baseline 和 treatment 的指标数据, 判定假设是否成立
2. reasoning 必须引用具体数值, 说明与判别标准的对比逻辑
3. 若数据矛盾 / 不足判定, 返回 uncertain 并说明原因
4. 不要复述判别标准, 直接给出判定依据

返回 JSON:
{
  "verdict": "supported" | "refuted" | "uncertain",
  "confidence": 0.0-1.0,
  "adversarial_reasoning": "你的独立判定依据, 2-3 句, 引用数值"
}
```

### 5.5 Verdict 合并逻辑

```python
if primary.verdict == adversary.verdict:
    # 一致, 采信 primary (它的 reasoning 更完整)
    final_verdict = primary.verdict
    final_reasoning = primary.reasoning + f"\n\n(对抗审校一致: {adversary.adversarial_reasoning})"

elif adversary.confidence >= 0.7:
    # 分歧且 adversary 高置信度 → 降级为 uncertain
    final_verdict = "uncertain"
    final_reasoning = f"""Primary: {primary.verdict} (confidence {primary.confidence})
{primary.reasoning}

Adversary: {adversary.verdict} (confidence {adversary.confidence})
{adversary.adversarial_reasoning}

判定分歧且对抗审校高置信度, 降级为 uncertain. 建议重做实验或调整判别标准."""

else:
    # 分歧但 adversary 低置信度 → 采信 primary, 附 adversary 质疑作警告
    final_verdict = primary.verdict
    final_reasoning = primary.reasoning + f"\n\n(对抗审校质疑 [{adversary.verdict}] 但置信度低 {adversary.confidence}: {adversary.adversarial_reasoning})"
```

### 5.6 experiments/Exxx.md 的写法

一致情况:

```markdown
## 结果

**Primary Analyst** (Claude):
- Verdict: supported
- Confidence: 0.88
- Reasoning: ...

**Adversarial Analyst** (DeepSeek via MCP):
- Verdict: supported
- Confidence: 0.85
- Reasoning: ...

**Final Verdict**: supported (一致)
```

分歧情况:

```markdown
**Final Verdict**: uncertain (分歧, adversary 高置信度)

Primary 认为 supported, 但 Adversary 认为 refuted 且 confidence=0.82. 分歧原因: adversary 指出 t-test p=0.08 > 0.05 未达显著性阈值, 而 primary 只关注绝对值差异. 降级为 uncertain, 建议增加样本量重跑.
```

### 5.7 MCP llm-chat 配置 (用户安装步骤)

`mcp-servers/llm-chat/README.md` 写清楚:

```markdown
## 安装 adversary analyst 后端

1. 确保 httpx 已安装: pip install httpx

2. 在 ~/.claude/settings.json 添加:
   {
     "mcpServers": {
       "llm-adversary": {
         "command": "python3",
         "args": ["/path/to/research-loop/mcp-servers/llm-chat/server.py"],
         "env": {
           "LLM_API_KEY": "sk-your-key",
           "LLM_BASE_URL": "https://api.deepseek.com/v1",
           "LLM_MODEL": "deepseek-chat",
           "LLM_SERVER_NAME": "llm-adversary"
         }
       }
     }
   }

3. 重启 Claude Code, 验证 mcp__llm_adversary__ 可用
```

### 5.8 永远开启 (不 opt-in)

对抗审校的价值是 **发现误判**, 这是静默风险 (用户不知道 primary 判错), 所以默认保护。成本可控 (~¥0.01/次 DeepSeek), 与 primary 并发不增加时长。

若 MCP 不可用, 主控检测后 **跳过 adversary + 警告**, 不阻断流程 (避免 MCP 故障卡死研究)。

## 6. Journal Resume 详细设计

### 6.1 核心思路

不做 fingerprint 哈希匹配 (pi-flow 风格), 只记录每个步骤是否完成。主控在 step 开头读取 journal, 从首个 non-done 步骤继续跑。

### 6.2 文件位置与格式

**位置**: `.research/experiments/Exxx.journal` (与 Exxx.md 同目录, 一一对应)

**格式**: 单文件, 多行追加, 每行一个 JSON 对象 (JSONL)

```jsonl
{"timestamp":"2026-06-20T14:32:10Z","step":"init","hypothesis_id":"H1.1","status":"started"}
{"timestamp":"2026-06-20T14:35:22Z","step":"designer","round":1,"status":"done"}
{"timestamp":"2026-06-20T14:37:45Z","step":"critic","round":1,"status":"done","verdict":"FAIL"}
{"timestamp":"2026-06-20T14:40:18Z","step":"designer","round":2,"status":"done"}
{"timestamp":"2026-06-20T14:42:30Z","step":"critic","round":2,"status":"done","verdict":"PASS"}
{"timestamp":"2026-06-20T14:50:12Z","step":"implementer","status":"done"}
{"timestamp":"2026-06-20T15:05:33Z","step":"runner","command_index":0,"status":"done"}
{"timestamp":"2026-06-20T15:20:45Z","step":"runner","command_index":1,"status":"fail","error":"timeout"}
```

### 6.3 状态机规则

| Step | 触发条件 | journal 写入 | 下一步 |
|---|---|---|---|
| designer (round N) | Agent(designer) 返回 | `{"step":"designer","round":N,"status":"done"}` | critic (round N) |
| critic (round N) | Agent(critic) 返回 | `{"step":"critic","round":N,"status":"done","verdict":"..."}` | FAIL & round<2 → designer(round+1); PASS/WARN → implementer; FAIL & round=2 → terminate |
| implementer | Agent(implementer) 返回 | `{"step":"implementer","status":"done"}` | runner |
| runner (cmd i) | Agent(runner) 第 i 条命令返回 | `{"step":"runner","command_index":i,"status":"done\|fail","error":"..."}` | done → runner(i+1); fail → terminate |
| analyst-primary | Agent(analyst) 返回 | `{"step":"analyst-primary","status":"done","verdict":"..."}` | analyst-adversary |
| analyst-adversary | MCP 调用返回 | `{"step":"analyst-adversary","status":"done","verdict":"..."}` | 合并 verdict |
| finalize | 主控写 tree.md + decisions/ + DASHBOARD | `{"step":"finalize","status":"done"}` | 流程结束 |
| terminate | 任一失败终止 | `{"step":"terminate","reason":"..."}` | 等待用户介入 |

### 6.4 Resume 逻辑 (step 开头执行)

主控在 `/research-loop:step` 开头:

1. 检查当前 tree.md 的待验假设, 比如 H1.1
2. 扫描 `.research/experiments/`, 找针对 H1.1 的未完成 journal (最后一行不是 `step=finalize,status=done` 也不是 `step=terminate`)
3. 若找到未完成 journal, 读取全部行解析状态机:
   - 回溯找已完成步骤
   - 确定续跑点 (首个 non-done 步骤)
4. 若无未完成 journal, 正常执行新实验 (创建 Exxx.md + Exxx.journal)

### 6.5 Resume 示例场景

**场景 1: runner 第 2 条命令超时**

journal:
```jsonl
{"step":"designer","round":1,"status":"done"}
{"step":"critic","round":1,"status":"done","verdict":"PASS"}
{"step":"implementer","status":"done"}
{"step":"runner","command_index":0,"status":"done"}
{"step":"runner","command_index":1,"status":"fail","error":"timeout after 4h"}
```

用户修复 slurm 配置后再次 step:
- 跳过 designer / critic / implementer (已完成)
- 从 runner[1] 重跑

**场景 2: critic round 1 FAIL, designer round 2 尚未跑**

journal:
```jsonl
{"step":"designer","round":1,"status":"done"}
{"step":"critic","round":1,"status":"done","verdict":"FAIL"}
```

Resume:
- 调用 designer(round 2), 把 critic(round 1).reasoning 作为输入
- 继续 critic(round 2)

**场景 3: critic round 2 FAIL, 流程已终止**

journal 含 `{"step":"terminate","reason":"critic-rejected-after-2-rounds"}`

Resume 时:
- 不续跑, 提示用户检查 Exxx.md Critic Review 或添加 Override
- 用户添加 Override → 下次 step 检测到 → 从 implementer 继续
- 用户标实验为废弃 → step 选下一个待验假设

### 6.6 Journal 与 experiments/Exxx.md 的协作

| 文件 | 角色 | 内容 |
|---|---|---|
| **Exxx.md** | 人类可读的完整实验记录 | 实验设计 / Critic Review / 执行记录 / 结果, markdown 格式, 进 git |
| **Exxx.journal** | 机器可读的状态机检查点 | 每个步骤的完成状态 + 时间戳, JSONL 格式, 进 git |

两者都进 git: Exxx.md 是最终交付物 (给人看), Exxx.journal 是可复现保证 (resume 依赖, 审计时能看到精确执行序列)。

### 6.7 不做 output_hash (初版)

不在 journal 记录 designer/implementer 输出的哈希, 不检测输入变化。理由: 过度设计, 信任状态机就够。后期若发现 resume 时输入漂移问题再加。

## 7. 错误处理策略

遵守 fail-fast 原则, 所有失败都立即记录并终止, 不降级、不兜底。

| 失败场景 | 处理 | 用户提示 |
|---|---|---|
| Designer JSON 格式错误 | 重试 1 次 → 仍失败 → 写 journal `step=designer,status=error` → 终止 | "designer 返回格式错误, 已终止" |
| Critic round 2 FAIL | 写 journal `step=terminate,reason=critic-rejected` → 终止 | "实验设计被 critic 拒绝 (2 轮), 查看 Exxx.md 或添加 Override" |
| Implementer self_check=fail | 写 journal `step=implementer,status=fail` → 终止 | "implementer 自检失败" |
| Runner 命令超时/失败 | 写 journal `step=runner,command_index=i,status=fail` → 终止 | "runner 命令 {i} 失败: {error}, 下次 step 从断点续跑" |
| MCP llm-adversary 不可用 | 跳过 adversary, 在 Exxx.md 写 "(对抗审校未配置)" | 警告: "MCP llm-adversary 未配置, 跳过对抗审校" |
| Analyst 返回 uncertain | tree.md 保持 `Status: 进行中`, 不写 decisions/ | "判定 uncertain, 建议重做或调整判别标准" |
| Journal 文件损坏 | 提示 "journal 损坏, 是否重新开始? (y/n)" | y → 备份为 .bak 创建新 journal; n → 终止 |

## 8. 测试策略

### 8.1 单元测试

不做。research-loop 是纯 prompt 插件, 无语言运行时, 没有可单元测试的函数。

### 8.2 集成测试 (手动剧本)

`tests/e2e-v0.3-upgrade.md` 包含 5 个测试用例:

1. **Critic Round 1 FAIL → Round 2 PASS**: 验证多轮迭代逻辑
2. **Critic Round 2 FAIL + Override**: 验证终止与 Override 逃生舱
3. **Adversary 分歧 → uncertain**: 验证 verdict 合并逻辑
4. **Runner 失败 → Journal Resume**: 验证断点续跑
5. **MCP 不可用 → 跳过 Adversary**: 验证 MCP 故障容错

### 8.3 Smoke Test (必做)

提交前自己跑一遍完整流程: init → step (正常) → step (触发 critic FAIL) → resume → 检查 journal / Exxx.md / tree.md / decisions/ / DASHBOARD 全部正确。

### 8.4 hook-test.sh 不变

`tests/hook-test.sh` 7/7 仍通过 — 升级不影响 SessionStart hook。

## 9. 交付清单

### 9.1 新增文件

```
research-loop/
├── mcp-servers/
│   └── llm-chat/
│       ├── server.py          # 从 auto-research 复制 (MIT), 保留 attribution
│       ├── requirements.txt   # httpx>=0.27,<1.0
│       └── README.md          # 安装指南
├── agents/
│   ├── critic.md              # 4 维度审查契约
│   └── analyst-adversary.md   # 对抗审校契约
├── tests/
│   └── e2e-v0.3-upgrade.md    # 手动测试剧本
└── docs/
    └── specs/
        └── 2026-06-20-research-loop-v0.3-upgrade-design.md  # 本文档
```

### 9.2 修改文件

```
commands/step.md                          # 主控流水线大改: critic 多轮 + adversary + journal
skills/research-orchestration/SKILL.md    # 更新 brief 模板, 增加 critic/adversary 章节
README.md                                 # 新增 "对抗审校" 和 "断点续跑" 章节
CLAUDE.md                                 # 同步更新关键不变量描述
```

### 9.3 不变文件 (不许动)

```
agents/designer.md
agents/implementer.md
agents/runner.md
agents/analyst.md          # primary 就是它, 不改名不改契约
agents/scout.md
skills/hypothesis-tree/SKILL.md
hooks/session-start
```

### 9.4 功能验收点

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

## 10. 工时预估

| 工作项 | 预估 | 关键文件 |
|---|---|---|
| 复制 llm-chat MCP + README | 0.5 天 | mcp-servers/llm-chat/* |
| 定义 critic.md 契约 | 1 天 | agents/critic.md |
| 定义 analyst-adversary.md 契约 | 0.5 天 | agents/analyst-adversary.md |
| 修改 step.md (critic 多轮逻辑) | 3 天 | commands/step.md |
| 修改 step.md (adversary + verdict 合并) | 2 天 | commands/step.md |
| 实现 journal 读写 + resume 逻辑 | 3 天 | commands/step.md |
| 更新 research-orchestration SKILL.md | 1 天 | skills/research-orchestration/SKILL.md |
| 写 e2e-v0.3-upgrade.md 测试剧本 | 0.5 天 | tests/e2e-v0.3-upgrade.md |
| Smoke test | 2 天 | - |
| Bug fix + 边界 case | 3 天 | - |
| 写设计文档 | 1 天 | 本文档 |
| 更新 README.md + CLAUDE.md | 0.5 天 | - |
| **总计** | **18.5 天 ≈ 4 周** (单人 full-time) | - |

考虑迭代调优 + critic/adversary prompt 反复调试, 保守估计 **5-6 周**。

## 11. 已知风险

| 风险 | 缓解 |
|---|---|
| Critic prompt 调优困难, 误判率高 | Override 逃生舱 + 用户在 e2e 测试中调整 4 维度判定标准 |
| Adversary API 故障导致 step 阻断 | MCP 不可用时跳过 adversary + 警告, 不阻断 |
| Journal 状态机粒度不够 (无法处理嵌套失败) | 初版只支持线性状态机, 复杂场景手动 reset journal |
| Round 2 designer 退化为补丁式修订 | 强制保留 Round 1 输出 + critic Round 2 prompt 显式提醒 "检查是否真正回应质疑" |
| MCP llm-chat 跨平台兼容性 (Windows/macOS) | server.py 用纯 Python + httpx, 无 OS 特定依赖; 测试在 Linux 验证 |

## 12. 后续可能演化方向 (不在本次范围)

- v0.4: Assurance gate 三层验证链 (若 critic + adversary 仍不够)
- v0.5: Workflow runtime (若复杂科研场景需要并发/条件编排)
- v0.6: Research Wiki (若跨项目记忆累积成为需求)

这些都是后续判断, 不在本次升级范围。

## 附录 A: 参考资料

- pi-flow: https://github.com/kky42/pi-flow (TypeScript, ~5800 行)
- auto-research: https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep (368 markdown 文件, 83 skills, 9 MCP servers)
- research-loop v0.1.0 设计文档: docs/specs/2026-06-16-research-loop-design.md
- research-loop v0.1.0 实现规划: docs/plans/2026-06-16-research-loop-plugin.md
