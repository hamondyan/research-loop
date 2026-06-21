# research-loop v1.0 实现计划: 记忆辅助系统

> **For agentic workers:** 本计划用 checkbox(`- [ ]`)跟踪。markdown 契约按本仓库 CLAUDE.md 约定不套 TDD, 靠语法校验+walkthrough 验证。

**Goal:** 将 research-loop 从自动研究循环转型为研究记忆辅助系统 — 砍掉 60-70% 自动化代码, 保留格式化记录+上下文加载, 用户手动做实验 agent 按需写入。

**Architecture:** 归档 v0.4/v0.5 分支, 从 main 新开分支重写。删 agents/workflows/backends, 改造 init/resume/status 三命令为纯读+按需写, 新增三个原子写入函数(不暴露为命令), 目录简化为 IDEA/tree/DASHBOARD+experiments。

**Tech Stack:** markdown prompt 契约, bash(可选 helpers), git 分支管理。

---

## 文件结构(决策锁定)

| 文件 | 动作 | 职责 |
|---|---|---|
| archive/auto-research-loop 分支 | 归档 | 保留 v0.4/v0.5 历史不删 |
| feat/research-memory-system 分支 | 新建 | v1.0 实现分支 |
| commands/step.md | 删 | 整个自动验证循环命令 |
| agents/*.md (7 个) | 删 | 子 agent 契约 |
| workflows/step.js | 删 | 编排脚本 |
| scripts/backends/local.sh | 删 | 执行后端 |
| tests/backend-local-test.sh | 删 | 后端测试 |
| tests/e2e-v0.5-resumable.md | 删 | v0.5 e2e |
| skills/research-orchestration/ | 删 | 自动编排方法论 |
| commands/init.md | 改 | 简化: 只建骨架, 删 scout/args |
| commands/resume.md | 改 | 重写: 读+注入, 删编排 |
| commands/status.md | 改 | 保持纯读(几乎不动) |
| skills/hypothesis-tree/SKILL.md | 改 | 加写入操作指南 |
| README.md | 改 | 重写定位 |
| CLAUDE.md | 改 | 删 Workflow/agents 架构 |
| .claude-plugin/plugin.json | 改 | 0.5.0 → 1.0.0 |
| docs/examples/usage-walkthrough.md | 新 | 使用示例 |

---

## Task 1: 归档旧分支并新开分支

**Files:**
- 分支操作(无文件修改)

- [ ] **Step 1: 归档 v0.4/v0.5 分支**

```bash
git branch -m feat/v0.4-workflow-runtime archive/auto-research-loop
```

保留历史不删, 如果未来想回顾自动化设计可以 checkout 这个分支。

- [ ] **Step 2: 切回 main, 新开分支**

```bash
git checkout main
git checkout -b feat/research-memory-system
```

从 main 全新开始, 不 cherry-pick 旧代码(偏离目标太远)。

- [ ] **Step 3: 确认分支状态**

```bash
git branch --list "archive/*" "feat/*"
git log --oneline -3
```

Expected: 看到 archive/auto-research-loop 和 feat/research-memory-system, 后者在 main 的 HEAD。

---

## Task 2: 删除旧自动化组件

**Files:**
- Delete: commands/step.md
- Delete: agents/*.md (7 个)
- Delete: workflows/step.js
- Delete: scripts/backends/local.sh
- Delete: tests/backend-local-test.sh
- Delete: tests/e2e-v0.5-resumable.md
- Delete: skills/research-orchestration/SKILL.md(整个目录)

- [ ] **Step 1: 删除命令和子 agent**

```bash
rm commands/step.md
rm -r agents/
```

- [ ] **Step 2: 删除编排和后端**

```bash
rm workflows/step.js
rm scripts/backends/local.sh
rm tests/backend-local-test.sh
```

- [ ] **Step 3: 删除旧测试和 skill**

```bash
rm tests/e2e-v0.5-resumable.md
rm -r skills/research-orchestration/
```

- [ ] **Step 4: 确认清理**

```bash
ls commands/ agents/ workflows/ scripts/backends/ skills/research-orchestration/ 2>&1
```

Expected: agents/workflows/backends/research-orchestration 报 "No such file", commands/ 只剩 init/resume/status。

- [ ] **Step 5: 提交删除**

```bash
git add -A
git commit -m "refactor(v1.0): 删除自动化组件

删 step 命令/7 个子 agent/workflows 编排/执行后端/旧测试/自动编排 skill。
为记忆辅助系统架构让路, 代码量减 60-70%。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 改造 commands/init.md(简化)

**Files:**
- Modify: commands/init.md

- [ ] **Step 1: 简化 frontmatter 和职责描述**

把 description 从"初始化+准备 args"改成"初始化 .research/ 骨架"。删 frontmatter 里关于 scout/codebase 的提示。

- [ ] **Step 2: 删除 scout 和 codebase_constraints 段落**

删 "Step 2: 准备 codebase_constraints"(调 scout 那段)和"Step X: 前置检查 adversary_available"。

- [ ] **Step 3: 简化 args 准备为骨架生成**

只保留:
1. 检查 `.research/` 不存在
2. 创建 `mkdir -p .research/experiments`
3. 生成 IDEA.md(从 idea_file 提取)
4. 生成 tree.md(空树或推导 1-2 初始假设, 用户确认)
5. 生成 DASHBOARD.md 初版
6. 输出提示

删 skip_critic / adversary_available / output_dir / backend_script 这些自动化参数。

- [ ] **Step 4: 更新输出提示**

改为:
```
✓ 研究记忆系统已初始化
📁 .research/IDEA.md | tree.md | DASHBOARD.md | experiments/

下一步: 用 /research-loop:resume 加载上下文, 或直接开始对话让我帮你记录假设/实验
```

- [ ] **Step 5: Walkthrough 校验**

人工核对: frontmatter description 简洁? 步骤只建骨架不准备自动化参数? 输出提示符合新定位?

- [ ] **Step 6: 提交**

```bash
git add commands/init.md
git commit -m "refactor(v1.0): init 简化为骨架初始化

删 scout 调用/codebase_constraints 准备/adversary 前置检查/自动化参数。
只建 .research/ 目录+生成 IDEA/tree/DASHBOARD 初版。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 重写 commands/resume.md(读+注入)

**Files:**
- Modify: commands/resume.md

- [ ] **Step 1: 改 frontmatter description**

从"恢复研究上下文+报告下一步"改成"加载 .research/ 状态, 将研究上下文注入对话"。

- [ ] **Step 2: 重写职责段**

职责改为: 读取 IDEA/tree/experiments 并解析, 拼成结构化上下文字符串(中等详细度, ~1000-2000 字), 注入对话让 agent 带着记忆继续工作。

- [ ] **Step 3: 重写执行流程**

1. 检查 `.research/`, 不存在提示 init
2. 读取并解析:
   - IDEA.md → 动机
   - tree.md → 假设树(所有假设+Status+Evidence)
   - experiments/*.md → 扫描, 提取摘要(Hypothesis/Date/结论, 不读全文)
3. 拼成结构化上下文:
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
4. 注入对话(system reminder 或对话开头插入, 根据 Claude Code 能力选最优雅方式)
5. 输出: "✓ 研究上下文已加载, [总假设数]个假设 | [实验数]个实验"

删掉 v0.4 的"报告下一步"/"选待验假设"等自动编排逻辑。

- [ ] **Step 4: 添加注入方式说明**

在"实现注意"段注明: 注入方式取决于 Claude Code 能力, 如果支持动态插入上下文用最优雅方式, 否则退化为"打印一段并说'以上是研究记忆, 记住它'"。

- [ ] **Step 5: Walkthrough 校验**

核对: 职责聚焦"读+注入"? 删掉自动编排残留? 中等详细度(摘要而非全文)?

- [ ] **Step 6: 提交**

```bash
git add commands/resume.md
git commit -m "refactor(v1.0): resume 重写为读取+注入上下文

读 IDEA/tree/experiments 拼结构化上下文(中量: 树+动机+实验历史摘要,
~1000-2000 字), 注入对话。删自动编排逻辑(选假设/报告下一步)。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 改造 skills/hypothesis-tree/SKILL.md(加写入指南)

**Files:**
- Modify: skills/hypothesis-tree/SKILL.md

- [ ] **Step 1: 扩展 Role 段**

从"理解 tree.md 格式规范"扩展到"理解并维护 tree.md + 在对话中按需写入 .research/"。

- [ ] **Step 2: 新增"写入触发机制"段**

**写入触发**: 只在用户明确指示时写, 不主动/不猜测/不自动后台写。

明确指示三种形式:
1. 直接命令: "记下这个假设 H3"
2. 确认式: agent 问"要不要记录?", 用户说"好"
3. 隐含但明确: "保存"/"记录"/"写下来"

不触发: 讨论/头脑风暴没说"记下来", 探索性"可能是 X", agent 自己推测。

- [ ] **Step 3: 新增"三个原子写入操作"段**

#### `appendHypothesis(tree.md, 描述, 父节点)`
触发: "记下假设: [描述]"
行为: 读 tree 解析 ID → 确定新 ID(父节点则 H1.N, 否则顶层 HM) → 追加行 `- HX: [描述] (Status: 待验, Evidence: (empty))` → 刷新 DASHBOARD → 输出确认

#### `createExperimentRecord(描述, 关联假设)`
触发: "记录这次实验"
行为: 扫 experiments/ 最大+1 → 生成 Exxx.md 骨架 → 关联假设 `待验`→`进行中` → 刷新 DASHBOARD → 输出确认

#### `updateExperimentResult(Exxx.md, 结果, 结论)`
触发: "E003 结果出来了, 结论支持 H1"
行为: 填 `## 结果` → Exxx Status `进行中`→`已完成` → 联动 tree(假设 Status 改+Evidence 追加) → 刷新 DASHBOARD → 输出确认

#### `updateDashboard()`(自动调用)
其他三个操作调用, 扫 tree 统计 Active 重写 DASHBOARD。

- [ ] **Step 4: 新增"格式守护"段**

所有写入: 遵循 Status 词汇/编号规则/不加粗, append-only, 原子性(全成功或全失败), 确认反馈。

- [ ] **Step 5: Walkthrough 校验**

核对: 触发规则清晰? 三个函数行为完整? 格式守护约定明确?

- [ ] **Step 6: 提交**

```bash
git add skills/hypothesis-tree/SKILL.md
git commit -m "feat(v1.0): SKILL 加对话中按需写入指南

新增写入触发机制(用户明确指示才写, 三种形式)+三个原子操作(append 假设
/create 实验/update 结果)+格式守护约定。扩展 Role 为"理解并维护"。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 更新 README.md + CLAUDE.md + plugin.json

**Files:**
- Modify: README.md
- Modify: CLAUDE.md
- Modify: .claude-plugin/plugin.json

- [ ] **Step 1: README 重写定位段**

改开头"research-loop 是什么"段: 从"全自动研究循环工具"改成"研究记忆辅助系统 — 用户手动做实验, agent 在对话中帮忙格式化记录到 `.research/`, 并能随时加载历史上下文继续工作"。

- [ ] **Step 2: README 更新使用方式**

旧: `/research-loop:step` 自动跑全流程
新: 
1. `/research-loop:init` 建骨架
2. 对话中说"记下这个假设"/"记录实验", agent 写入
3. `/research-loop:resume` 加载上下文
4. `/research-loop:status` 查看状态

- [ ] **Step 3: README 更新目录结构**

删 decisions/artifacts 说明, 强调 experiments 是实验详细记录层。

- [ ] **Step 4: CLAUDE.md 重写架构段**

删 Workflow/agents/backends 描述, 改成"三命令(init/resume/status)+三原子写入函数+格式规范守护"。

- [ ] **Step 5: CLAUDE.md 更新关键不变量**

保留 append-only/Status 词汇一致/不加粗, 新增"唯一写盘点: 只有主 PI(对话中)写 `.research/`, 格式化逻辑保证一致性"。

- [ ] **Step 6: plugin.json 改版本和描述**

```json
{
  "version": "1.0.0",
  "description": "研究记忆辅助系统 — 结构化记录假设/实验, 按需写入, 上下文加载"
}
```

- [ ] **Step 7: 语法校验**

```bash
python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); print('valid')"
```
Expected: `valid`

- [ ] **Step 8: 提交**

```bash
git add README.md CLAUDE.md .claude-plugin/plugin.json
git commit -m "docs(v1.0): 更新定位为记忆辅助系统

README 重写使用方式(对话记录取代自动 step)+目录结构。CLAUDE 删
Workflow/agents 架构改三命令+三原子函数。plugin.json 0.5.0→1.0.0。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 新增使用示例 + 全量验证

**Files:**
- Create: docs/examples/usage-walkthrough.md

- [ ] **Step 1: 写使用示例 walkthrough**

```markdown
# research-loop v1.0 使用示例

## 初始化

用户: `/research-loop:init idea.md`
系统: ✓ 研究记忆系统已初始化

## 对话中记录假设

用户: "我觉得模型在负样本上过拟合了, 记下这个假设"
Agent: ✓ 假设 H1 已记录到 tree.md (Status: 待验)

## 记录实验

用户: "帮我记录这次实验, 验证 H1"
Agent: ✓ 实验 E001 已创建 (experiments/E001.md)

(用户手动做实验...)

用户: "E001 结果出来了, accuracy 从 0.85 降到 0.72, 结论是支持 H1"
Agent: ✓ E001 结果已记录, H1→被支持 (Evidence: E001)

## 加载上下文

用户: `/research-loop:resume`
系统: ✓ 研究上下文已加载, 1 个假设 | 1 个实验
(注入后 agent 能在对话中引用 H1/E001)

## 查看状态

用户: `/research-loop:status`
系统: (打印 DASHBOARD.md + 统计)
```

- [ ] **Step 2: 全量验证清单**

人工 walkthrough(需实际对话测试, 无法自动):
- [ ] init 能建骨架?
- [ ] 对话中说"记下假设"能追加到 tree.md?
- [ ] 对话中说"记录实验"能生成 Exxx.md?
- [ ] 对话中说"E001 结果支持 H1"能联动更新 tree?
- [ ] resume 能正确拼接并注入上下文?
- [ ] status 能读取并打印?

格式检查(可自动):
```bash
# 检查 .research/ 格式是否符合规范
[ -f .research/IDEA.md ] && [ -f .research/tree.md ] && [ -f .research/DASHBOARD.md ] && [ -d .research/experiments ] && echo "结构 OK" || echo "结构缺失"
```

- [ ] **Step 3: 提交示例**

```bash
git add docs/examples/usage-walkthrough.md
git commit -m "docs(v1.0): 新增使用示例 walkthrough

演示 init→对话记录假设/实验→resume 加载→status 查看的完整流程。

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 4: 最终确认**

```bash
git log --oneline feat/research-memory-system ^main
```
Expected: 看到 7 个 commit(归档→删旧→改 init→改 resume→改 SKILL→更新文档→示例)

---

## 验证策略

按本仓库约定, markdown 契约不套 TDD, 验证方式:
1. **语法校验**: plugin.json JSON 格式
2. **Walkthrough**: 人工对话测试上述 7 个步骤能否工作
3. **格式检查**: 写入后 tree.md/experiments 是否符合 spec §3 规范

无自动测试套件(契约文件的"测试"是实际使用)。

---

## 关键不变量(实现时遵守)

- Status 词汇: `待验`/`进行中`/`被支持`/`被推翻` 4 个中文词, 不混用英文
- append-only: 假设/实验 ID 永不重用, Evidence 只增不删
- Status 不加粗: `Status: 待验`, 不写 `**Status: 待验**`
- 原子性: 写入全成功或全失败, 不留半截
- 确认反馈: 每次写入告知用户写了什么文件/改了什么字段
