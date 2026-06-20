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
