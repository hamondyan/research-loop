# research-loop 插件实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 research-loop 独立插件, 为科研 idea 全生命周期提供持久化状态管理与多 agent 协作脚手架

**Architecture:** 插件形态 — plugin.json 清单 + SessionStart hook 轻探测 + 4 个 `/research:*` 命令 + 2 个核心 skills(主控编排 + 假设树规范) + 5 个专家子 agent 定义. 状态存于仓库 `.research/` 目录, hook 探测后注入一行提示, 命令按需加载状态, skills 规范主控行为, agent 定义给子 agent 最小 brief 模板.

**Tech Stack:** Bash(hook 脚本) + Markdown(命令/skills/agent 文档) + JSON(plugin.json, hooks.json) + Git(状态持久化)

---

## 文件结构

插件根目录置于 `research-loop/`(独立插件, 不放仓库内):

**创建文件:**
- `research-loop/.claude-plugin/plugin.json` — 插件清单
- `research-loop/hooks/hooks.json` — SessionStart hook 注册
- `research-loop/hooks/session-start` — 轻探测脚本(bash, 无扩展名)
- `research-loop/commands/research/init.md` — `/research:init` 命令
- `research-loop/commands/research/resume.md` — `/research:resume` 命令
- `research-loop/commands/research/step.md` — `/research:step` 命令
- `research-loop/commands/research/status.md` — `/research:status` 命令
- `research-loop/skills/research-orchestration/SKILL.md` — 主控 PI 编排方法论
- `research-loop/skills/hypothesis-tree/SKILL.md` — 假设树读写规范
- `research-loop/agents/scout.md` — scout 子 agent 定义
- `research-loop/agents/designer.md` — designer 子 agent 定义
- `research-loop/agents/implementer.md` — implementer 子 agent 定义
- `research-loop/agents/runner.md` — runner 子 agent 定义
- `research-loop/agents/analyst.md` — analyst 子 agent 定义
- `research-loop/README.md` — 插件使用说明
- `research-loop/tests/hook-test.sh` — hook 脚本单测

**测试策略:** hook 脚本用 bash 单测覆盖 4 种场景(仓库有状态/仓库无状态/非仓库/DASHBOARD 不完整); 命令/skills 用 superpowers:writing-skills 方法(压力场景跑子 agent, 验证带/不带 skill 的行为差异); 端到端用玩具假设跑一轮 init→step→resume.

---

## Task 1: 插件清单与目录骨架

**Files:**
- Create: `research-loop/.claude-plugin/plugin.json`
- Create: `research-loop/README.md`
- Create: `research-loop/.gitignore`

- [ ] **Step 1: 创建插件根目录与清单**

在仓库根外(如 `~/research-loop/`)创建插件根目录, 写入 plugin.json:

```bash
mkdir -p ~/research-loop/.claude-plugin
cd ~/research-loop
```

`research-loop/.claude-plugin/plugin.json`:
```json
{
  "name": "research-loop",
  "description": "科研 idea 全生命周期管理: 假设树状态 + 多 agent 协作 + 跨 session 衔接",
  "version": "0.1.0",
  "author": {
    "name": "chenglongyan",
    "email": ""
  },
  "license": "MIT",
  "keywords": [
    "research",
    "hypothesis-tree",
    "multi-agent",
    "workflow"
  ]
}
```

- [ ] **Step 2: 写 README 说明安装与使用**

`research-loop/README.md`:
```markdown
# research-loop

科研 idea 全生命周期管理插件 for Claude Code.

## 功能

- **假设树状态模型**: `.research/` 目录存放 IDEA/假设树/实验/决策, 随研究分支 git 提交
- **跨 session 衔接**: SessionStart hook 轻探测, `/research:resume` 按需恢复上下文
- **多 agent 协作**: 主控 PI + 5 个无状态专家子 agent(scout/designer/implementer/runner/analyst)
- **自适应重规划**: 基于假设树状态变化, 决策日志可追溯

## 安装

```bash
# 方法 1: 从本地安装(开发时)
cp -r research-loop ~/.claude/plugins/

# 方法 2: 从 git 安装(发布后)
# (待插件发布到 marketplace)
```

安装后重启 Claude Code session, 插件自动激活.

## 使用

### 初始化研究

```bash
/research:init <idea文件路径>
```

主控与你对话提炼 IDEA.md + 初始假设树, 落盘 `.research/`(会建议新开研究分支).

### 恢复上下文

新 session 启动时, 若当前分支有研究状态, hook 会提示:

```
当前分支 xxx 有进行中的研究: "..."
活跃假设 N 个, 最近验证 YYYY-MM-DD. 用 /research:resume 加载完整状态.
```

运行 `/research:resume` 加载完整上下文.

### 跑一轮假设验证循环

```bash
/research:step
```

主控选一个待验假设 → designer 设计实验 → implementer 实现 → runner 在计算节点跑 → analyst 判定 → 更新假设树 + 重写 DASHBOARD.

### 查看仪表盘

```bash
/research:status
```

打印活跃假设、最近验证、下一步动作.

## 状态目录结构

```
.research/
├── IDEA.md                    # 北极星
├── tree.md                    # 假设树(单一真相源)
├── DASHBOARD.md               # 仪表盘(主控收工时重写)
├── experiments/E001-xxx.md    # 实验记录
├── decisions/D001-xxx.md      # 决策日志
└── artifacts/                 # gitignore: ckpt/日志/eval 原始输出
```

## License

MIT
```

- [ ] **Step 3: 写 .gitignore**

`research-loop/.gitignore`:
```
# 开发临时文件
*.pyc
__pycache__/
.DS_Store

# 测试产物
tests/fixtures/.research/
```

- [ ] **Step 4: 验证目录结构**

```bash
cd ~/research-loop
tree -L 2 -a
```

Expected:
```
.
├── .claude-plugin/
│   └── plugin.json
├── .gitignore
└── README.md
```

- [ ] **Step 5: 提交骨架**

```bash
cd /public/home/chenglongyan/workspace/starVLA
git add -A
git commit -m "feat(research-loop): add plugin manifest and README

- plugin.json with metadata
- README with installation and usage guide
- .gitignore for dev artifacts

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: SessionStart hook 脚本

**Files:**
- Create: `research-loop/hooks/hooks.json`
- Create: `research-loop/hooks/session-start`
- Create: `research-loop/tests/hook-test.sh`

- [ ] **Step 1: 写 hook 注册配置**

`research-loop/hooks/hooks.json`:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start\"",
            "async": false
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: 写轻探测脚本(失败版 — 预期不输出任何 JSON)**

`research-loop/hooks/session-start`:
```bash
#!/usr/bin/env bash
# SessionStart hook for research-loop plugin: 轻探测 .research/ 状态

set -euo pipefail

# Placeholder: 暂时什么都不做, 直接 exit 0
exit 0
```

```bash
chmod +x research-loop/hooks/session-start
```

- [ ] **Step 3: 写测试脚本 — 验证 4 种场景**

`research-loop/tests/hook-test.sh`:
```bash
#!/usr/bin/env bash
# 单测 session-start hook 的 4 种场景

set -euo pipefail

HOOK_SCRIPT="../hooks/session-start"

echo "=== Test 1: 非 git 仓库 → 静默退出(空输出) ==="
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
OUTPUT=$("$HOOK_SCRIPT" 2>&1 || true)
if [ -z "$OUTPUT" ]; then
  echo "✓ PASS: 非仓库静默退出"
else
  echo "✗ FAIL: 应该无输出, 实际: $OUTPUT"
  exit 1
fi
cd - >/dev/null
rm -rf "$TMPDIR"

echo "=== Test 2: git 仓库但无 .research/ → 静默退出 ==="
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init -q
OUTPUT=$("$HOOK_SCRIPT" 2>&1 || true)
if [ -z "$OUTPUT" ]; then
  echo "✓ PASS: 无状态静默退出"
else
  echo "✗ FAIL: 应该无输出, 实际: $OUTPUT"
  exit 1
fi
cd - >/dev/null
rm -rf "$TMPDIR"

echo "=== Test 3: 仓库有 .research/DASHBOARD.md → 注入提示(未实现, 预期失败) ==="
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init -q
mkdir -p .research
echo "# Dashboard" > .research/DASHBOARD.md
echo "**IDEA**: Test Hypothesis" >> .research/DASHBOARD.md
echo "**Active**: 2 | **Last**: 2026-06-16" >> .research/DASHBOARD.md
OUTPUT=$("$HOOK_SCRIPT" 2>&1 || true)
# 当前 placeholder 不会输出, 测试预期失败(下一 step 实现后再通过)
if echo "$OUTPUT" | grep -q "research-context"; then
  echo "✓ PASS: 检测到状态并注入"
else
  echo "⚠ EXPECTED FAIL(placeholder): 还未实现注入逻辑"
fi
cd - >/dev/null
rm -rf "$TMPDIR"

echo "=== Test 4: DASHBOARD.md 不完整 → 静默退出 ==="
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init -q
mkdir -p .research
echo "incomplete" > .research/DASHBOARD.md
OUTPUT=$("$HOOK_SCRIPT" 2>&1 || true)
if [ -z "$OUTPUT" ]; then
  echo "✓ PASS: 不完整 DASHBOARD 静默退出"
else
  echo "✗ FAIL: 应该无输出, 实际: $OUTPUT"
  exit 1
fi
cd - >/dev/null
rm -rf "$TMPDIR"

echo
echo "所有测试完成(Test 3 预期失败待下一 step)"
```

```bash
chmod +x research-loop/tests/hook-test.sh
```

- [ ] **Step 4: 运行测试 — 验证 placeholder 行为**

```bash
cd ~/research-loop/tests
./hook-test.sh
```

Expected:
```
✓ PASS: 非仓库静默退出
✓ PASS: 无状态静默退出
⚠ EXPECTED FAIL(placeholder): 还未实现注入逻辑
✓ PASS: 不完整 DASHBOARD 静默退出
```

- [ ] **Step 5: 实现真实探测逻辑 — 读 DASHBOARD 注入 JSON**

`research-loop/hooks/session-start`:
```bash
#!/usr/bin/env bash
# SessionStart hook for research-loop plugin: 轻探测 .research/ 状态

set -euo pipefail

# 判断是否 git 仓库
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# 取当前分支名
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ -z "$BRANCH" ]; then
  exit 0
fi

# 检测 .research/DASHBOARD.md
DASHBOARD_PATH=".research/DASHBOARD.md"
if [ ! -f "$DASHBOARD_PATH" ]; then
  exit 0
fi

# 读取 DASHBOARD 前 3 行提取摘要(格式约定: **IDEA**: xxx / **Active**: N | **Last**: YYYY-MM-DD)
IDEA_LINE=$(grep "^\*\*IDEA\*\*:" "$DASHBOARD_PATH" 2>/dev/null | head -1 | sed 's/^\*\*IDEA\*\*: //' || echo "")
ACTIVE_LINE=$(grep "^\*\*Active\*\*:" "$DASHBOARD_PATH" 2>/dev/null | head -1 | sed 's/^\*\*Active\*\*: //' || echo "")

if [ -z "$IDEA_LINE" ] || [ -z "$ACTIVE_LINE" ]; then
  # DASHBOARD 格式不完整, 静默退出
  exit 0
fi

# 构造注入内容
CONTEXT="<research-context>
当前分支 $BRANCH 有进行中的研究: \"$IDEA_LINE\"
$ACTIVE_LINE. 用 /research:resume 加载完整状态.
</research-context>"

# Escape for JSON(简化版, 只转义双引号和换行)
CONTEXT_ESCAPED=$(echo "$CONTEXT" | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

# 输出 Claude Code hookSpecificOutput 格式
printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$CONTEXT_ESCAPED"

exit 0
```

- [ ] **Step 6: 重跑测试 — 验证 Test 3 通过**

```bash
cd ~/research-loop/tests
./hook-test.sh
```

Expected:
```
✓ PASS: 非仓库静默退出
✓ PASS: 无状态静默退出
✓ PASS: 检测到状态并注入
✓ PASS: 不完整 DASHBOARD 静默退出
```

- [ ] **Step 7: 提交 hook**

```bash
cd /public/home/chenglongyan/workspace/starVLA
git add research-loop/hooks/ research-loop/tests/
git commit -m "feat(research-loop): implement SessionStart hook with lightweight detection

- hooks.json registers SessionStart on startup/clear/compact
- session-start script: detect .research/DASHBOARD.md, inject one-line prompt
- hook-test.sh covers 4 scenarios: non-repo / no-state / with-state / incomplete-dashboard
- All tests pass

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `/research:status` 命令(最简单, 只读)

**Files:**
- Create: `research-loop/commands/research/status.md`

- [ ] **Step 1: 写命令文档**

`research-loop/commands/research/status.md`:
```markdown
---
name: research:status
description: 打印当前分支研究状态仪表盘(只读, 零副作用)
---

# /research:status

打印 `.research/DASHBOARD.md` 的完整内容, 无任何副作用.

## 前置条件

- 当前目录是 git 仓库
- `.research/DASHBOARD.md` 存在

## 执行

1. 检测 `.research/DASHBOARD.md`
2. 若不存在, 输出: "当前分支无进行中的研究. 用 /research:init <idea文件> 初始化."
3. 若存在, 读取并打印全文

## 示例

```
$ /research:status

# Research Dashboard

**IDEA**: 测试 VLA 是否能读懂指令细节
**Active**: 2 hypotheses | **Last**: 2026-06-15

## Active Hypotheses
- H1: VLA 对指令中的否定词不敏感 (待验)
- H1.1: 增加 instruction token 权重能提升敏感度 (待验)

## Next Steps
1. 设计 H1 的判别实验(对比 baseline vs 加否定指令的 success rate)
```
```

- [ ] **Step 2: 测试命令(手动 — 命令测试依赖 Claude Code 运行时)**

测试策略: 在 starVLA 仓库的一个测试分支手动创建 `.research/DASHBOARD.md`, 调用 `/research:status` 验证输出.

```bash
# 准备测试环境
cd /public/home/chenglongyan/workspace/starVLA
git checkout -b test-research-status
mkdir -p .research
cat > .research/DASHBOARD.md << 'EOF'
# Research Dashboard

**IDEA**: Test Hypothesis
**Active**: 1 | **Last**: 2026-06-16

## Active Hypotheses
- H1: Placeholder hypothesis (待验)

## Next Steps
1. Design experiment for H1
EOF

# 在 Claude Code session 中运行:
# /research:status
# 预期: 打印上述 DASHBOARD 全文

# 清理
git checkout feature/research-loop-plugin
git branch -D test-research-status
rm -rf .research
```

命令本身无复杂逻辑, 文档写完即可, 端到端测试在 Task 9 覆盖.

- [ ] **Step 3: 提交命令**

```bash
cd /public/home/chenglongyan/workspace/starVLA
git add research-loop/commands/research/status.md
git commit -m "feat(research-loop): add /research:status command

- Read-only command to print DASHBOARD.md
- Zero side effects, simple file read

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `/research:resume` 命令

**Files:**
- Create: `research-loop/commands/research/resume.md`

- [ ] **Step 1: 写命令文档**

`research-loop/commands/research/resume.md`:
```markdown
---
name: research:resume
description: 加载 .research/ 状态, 恢复研究上下文
---

# /research:resume

从 `.research/` 加载完整研究上下文, 报告当前进展与下一步动作.

## 前置条件

- 当前目录是 git 仓库
- `.research/IDEA.md` 与 `.research/tree.md` 存在

## 执行

1. 检测 `.research/IDEA.md` 和 `.research/tree.md`
2. 若不存在, 输出: "当前分支无研究状态. 用 /research:init <idea文件> 初始化."
3. 读取 `IDEA.md`(北极星) + `tree.md`(假设树) + `DASHBOARD.md`(仪表盘)
4. 解析假设树, 提取活跃假设(状态=待验或进行中)
5. 输出摘要:
   - IDEA 一句话
   - 假设树根问题
   - 活跃假设列表(ID + 内容 + 状态)
   - 最近一次验证日期(从 DASHBOARD 提取)
   - 下一步建议(从 DASHBOARD 提取)

## 输出格式

```
已加载研究: "<IDEA 一句话>"

核心问题: <tree.md 根节点>

活跃假设(N 个):
- H1: <内容> (待验)
- H1.1: <内容> (进行中)

最近验证: YYYY-MM-DD

下一步: <DASHBOARD 中的 Next Steps 第一条>

完整仪表盘: .research/DASHBOARD.md
假设树: .research/tree.md
```

## 实现注意

- 命令只负责加载与打印, 不修改任何文件
- 假设树格式约定(见 hypothesis-tree skill):
  ```
  # H1: <假设内容>
  Status: 待验 | 进行中 | 被支持 | 被推翻
  Evidence: E001, E003
  ```
```

- [ ] **Step 2: 提交命令**

```bash
cd /public/home/chenglongyan/workspace/starVLA
git add research-loop/commands/research/resume.md
git commit -m "feat(research-loop): add /research:resume command

- Load IDEA + tree + DASHBOARD
- Parse active hypotheses and report progress
- Read-only, no state modification

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `/research:init` 命令

**Files:**
- Create: `research-loop/commands/research/init.md`

- [ ] **Step 1: 写命令文档**

`research-loop/commands/research/init.md`:
```markdown
---
name: research:init
description: 从 idea 文件初始化 .research/ 目录
---

# /research:init <idea文件>

读取 idea 文件, 与用户对话提炼 IDEA.md + 初始假设树, 落盘 `.research/`.

## 前置条件

- 当前目录是 git 仓库
- idea 文件存在且可读

## 执行流程

1. 读取 idea 文件全文
2. 与用户对话提炼:
   - **动机**: 为什么做这个研究?
   - **核心假设**: 要验证什么?(可证伪的陈述)
   - **成功判据**: 怎样算成功? 量化指标是什么?
3. 提议初始假设树分解(1-3 个一级假设), 请用户确认
4. **检查分支**: 若当前在 main/starVLA_dev 等主分支, 建议用户新开研究分支(遵守"禁止擅自开分支", 必须用户同意后才 `git checkout -b research/<slug>`)
5. 创建 `.research/` 目录结构:
   ```
   .research/
   ├── IDEA.md
   ├── tree.md
   ├── DASHBOARD.md
   ├── experiments/
   ├── decisions/
   └── artifacts/.gitkeep
   ```
6. 写入 `IDEA.md`:
   ```markdown
   # <研究标题>

   ## 动机
   <...>

   ## 核心假设
   <...>

   ## 成功判据
   <...>
   ```
7. 写入 `tree.md`(初始假设树):
   ```markdown
   # Hypothesis Tree

   ## H1: <第一个一级假设>
   Status: 待验
   Evidence: (empty)

   ## H2: <第二个一级假设>
   Status: 待验
   Evidence: (empty)
   ```
8. 写入 `DASHBOARD.md`(初始仪表盘):
   ```markdown
   # Research Dashboard

   **IDEA**: <一句话>
   **Active**: <N> hypotheses | **Last**: <今天日期>

   ## Active Hypotheses
   <从 tree.md 提取待验假设列表>

   ## Next Steps
   1. 设计 H1 的判别实验
   ```
9. 创建 `.research/artifacts/.gitkeep` + 在仓库根 `.gitignore` 追加 `.research/artifacts/*` (若尚未存在)
10. 提示用户: "已初始化 .research/. 建议 git commit 后运行 /research:step 开始第一轮验证."

## 对话示例

```
User: /research:init did-it-read-the-instruction.md

Assistant: Claude ran into some issues but Claude wants to finish writing the plan, so Claude will directly continue appending to the main plan file.

```

AI: (读取 did-it-read-the-instruction.md)

AI: 我提炼了以下要点:
- **动机**: 验证 VLA 是否能准确理解指令中的细节(如否定词)
- **核心假设**: VLA 对指令中的否定/细节要求不敏感
- **成功判据**: 在加否定指令的任务上, success rate 比 baseline 提升 > 10%

建议分解为 2 个一级假设:
- H1: VLA 对指令中的否定词不敏感
- H2: Instruction token 权重不足是根因

是否同意? (用户确认后继续)

AI: 当前在 feature/research-loop-plugin 分支. 建议新开研究分支 research/instruction-detail 专门验证这个 idea. 是否同意? (用户确认后 git checkout -b research/instruction-detail)

AI: 已创建 .research/ 并写入 IDEA.md + tree.md + DASHBOARD.md. 建议提交后运行 /research:step.
```
```

- [ ] **Step 2: 提交命令**

```bash
cd /public/home/chenglongyan/workspace/starVLA
git add research-loop/commands/research/init.md
git commit -m "feat(research-loop): add /research:init command

- Interactive dialogue to refine IDEA/hypotheses/success criteria
- Create .research/ structure with IDEA.md + tree.md + DASHBOARD.md
- Respect branch creation constraint (ask user before branching)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `/research:step` 命令(编排 5 个子 agent)

**Files:**
- Create: `research-loop/commands/research/step.md`

- [ ] **Step 1: 写命令文档(骨架 + 编排流程)**

`research-loop/commands/research/step.md`:
```markdown
---
name: research:step
description: 跑一轮假设验证循环(designer → implementer → runner → analyst → 更新状态)
---

# /research:step

编排 5 个无状态子 agent 完成一轮假设验证.

## 前置条件

- `.research/tree.md` 存在且有待验假设

## 执行流程

1. 读取 `tree.md`, 选择一个待验假设(优先级: 用户指定 > 第一个待验)
2. 调用 **designer** 子 agent 设计实验:
   - Input: 假设 ID + 内容 + 当前 codebase 约束
   - Output: 实验设计(变量/指标/judge 判据), 结构化 JSON
3. 主控写 `experiments/Exxx-<slug>.md`(待跑状态)
4. 调用 **implementer** 子 agent 实现:
   - Input: 实验设计 + 相关文件路径
   - Output: diff 摘要 + 自检结果
5. 调用 **runner** 子 agent 跑实验:
   - Input: 命令 + 资源要求(遵守 slurm 规则, 需计算节点)
   - Output: 关键指标 + artifact 路径
6. 主控回填指标到 `experiments/Exxx.md`
7. 调用 **analyst** 子 agent 判定:
   - Input: 实验结果 + 关联假设
   - Output: 判定(被支持/被推翻/不确定) + 置信度 + 是否触发重规划
8. 主控更新 `tree.md`(假设状态) + 写 `decisions/Dxxx-<slug>.md`(若判定为支持/推翻)
9. 主控重写 `DASHBOARD.md`
10. 输出摘要: 本轮验证了什么、结论、下一步

## 子 agent 调用模式

使用 Agent tool, 隔离上下文, 传最小 brief:

```python
# 示例(伪代码)
designer_brief = f"""
你是实验设计专家. 当前假设:
{hypothesis_content}

当前 codebase 约束:
- starVLA 仓库
- 训练脚本: scripts/train.py
- eval: scripts/eval.py

设计一个判别实验验证这个假设. 返回 JSON:
{{
  "variables": [...],
  "metrics": [...],
  "judge_criteria": "..."
}}
"""
designer_result = Agent(designer_brief, schema=EXPERIMENT_DESIGN_SCHEMA)
```

## 关键约束

- runner 必须遵守 slurm 规则: 先检查 $SLURM_JOB_ID, 无则提示用户申请交互式计算节点
- 每个子 agent 返回后, 主控立即写盘, 不等全部完成
- 若任一子 agent 失败, 主控记录到 `experiments/Exxx.md` 并终止本轮
```

- [ ] **Step 2: 提交命令**

```bash
cd /public/home/chenglongyan/workspace/starVLA
git add research-loop/commands/research/step.md
git commit -m "feat(research-loop): add /research:step command with 5-agent orchestration

- designer → implementer → runner → analyst pipeline
- Write experiments/decisions incrementally
- Respect slurm constraint for runner

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: `research-orchestration` skill

**Files:**
- Create: `research-loop/skills/research-orchestration/SKILL.md`

- [ ] **Step 1: 写 skill 文档**

`research-loop/skills/research-orchestration/SKILL.md`:
```markdown
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

## When to Use

在 `/research:step` 命令中, 你是主控. 其他命令(init/resume/status)你只负责读写文件, 不编排子 agent.

## Orchestration Pattern

```
读 tree → 选假设
  → Agent(designer, brief=最小切片)
  → 写 experiments/Exxx.md(待跑)
  → Agent(implementer, brief=实验设计)
  → Agent(runner, brief=命令+资源)
  → 回填指标
  → Agent(analyst, brief=结果+假设)
  → 更新 tree + 写 decisions/Dxxx.md
  → 重写 DASHBOARD
```

## Sub-Agent Brief Template

Designer:
```
你是实验设计专家. 假设: {content}
Codebase: {paths}
设计判别实验, 返回 JSON: {schema}
```

Implementer:
```
你是代码实现者. 实验设计: {design_json}
相关文件: {paths}
实现并自检, 返回 diff 摘要.
```

Runner:
```
你在计算节点跑实验. 命令: {cmd}
资源: {gpu/mem}
返回关键指标 JSON: {schema}
```

Analyst:
```
你是结果分析师. 实验结果: {metrics}
假设: {hypothesis}
判定是否支持/推翻, 返回 JSON: {verdict_schema}
```

## Error Handling

子 agent 失败 → 记录到 experiments/Exxx.md + 终止本轮, 不继续后续 agent.

## No Silent Failures

子 agent 返回的任何异常/警告都记录到状态文件, 不吞.
```

- [ ] **Step 2: 提交 skill**

```bash
cd /public/home/chenglongyan/workspace/starVLA
git add research-loop/skills/research-orchestration/
git commit -m "feat(research-loop): add research-orchestration skill

- Main orchestrator principles and patterns
- Sub-agent brief templates
- Incremental state writing and error handling

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: `hypothesis-tree` skill

**Files:**
- Create: `research-loop/skills/hypothesis-tree/SKILL.md`

- [ ] **Step 1: 写 skill 文档**

`research-loop/skills/hypothesis-tree/SKILL.md`:
```markdown
---
name: hypothesis-tree
description: 假设树读写规范
---

# Hypothesis Tree

假设树是 `.research/tree.md` 的格式规范.

## Structure

```markdown
# Hypothesis Tree

## H1: <第一个一级假设>
Status: 待验 | 进行中 | 被支持 | 被推翻
Evidence: E001, E003
Children: H1.1, H1.2

### H1.1: <H1 的子假设>
Status: 待验
Evidence: (empty)
Parent: H1

## H2: <第二个一级假设>
Status: 被推翻
Evidence: E002
```

## Status Values

- **待验**: 未开始验证
- **进行中**: 实验正在跑
- **被支持**: 至少一个实验支持, 无反对
- **被推翻**: 至少一个实验推翻

## ID Convention

- 一级假设: H1, H2, H3, ...
- 子假设: H1.1, H1.2, H2.1, ...
- 孙假设: H1.1.1, ...

## Evidence

实验 ID 列表(E001, E002), 逗号分隔.

## Reading

从 tree.md 提取活跃假设(Status=待验或进行中):

```python
import re
active = []
for match in re.finditer(r'## (H[\d.]+): (.+?)\nStatus: (待验|进行中)', tree_content):
    active.append({'id': match[1], 'content': match[2], 'status': match[3]})
```

## Writing

更新假设状态时, 用 Edit tool 精确替换 Status 行:

```python
Edit(
    'tree.md',
    old_string='## H1: ...\nStatus: 待验',
    new_string='## H1: ...\nStatus: 被支持'
)
```

追加新假设时, append 到文件末尾.
```

- [ ] **Step 2: 提交 skill**

```bash
cd /public/home/chenglongyan/workspace/starVLA
git add research-loop/skills/hypothesis-tree/
git commit -m "feat(research-loop): add hypothesis-tree skill

- tree.md format specification
- Status values and ID convention
- Reading/writing patterns

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: 5 个 agent 定义

**Files:**
- Create: `research-loop/agents/scout.md`
- Create: `research-loop/agents/designer.md`
- Create: `research-loop/agents/implementer.md`
- Create: `research-loop/agents/runner.md`
- Create: `research-loop/agents/analyst.md`

- [ ] **Step 1: 写 5 个 agent 定义(每个 ~30 行, 骨架+职责+输入输出schema)**

每个 agent 定义格式:

```markdown
---
name: <agent-name>
role: <one-line role>
---

# <Agent Name>

## Role

<详细职责, 2-3 句>

## Input

<brief 切片结构, 列举字段>

## Output

<结构化返回 schema, JSON>

## Constraints

<关键约束, 如 runner 必须遵守 slurm 规则>

## Example Brief

```
<实际 brief 示例>
```

## Example Output

```json
<实际输出 JSON 示例>
```
```

5 个 agent:

**scout.md**:
- Role: 调研文献/codebase, 定位相关实现
- Input: 问题 + 范围
- Output: `{"conclusion": "...", "key_paths": [...], "references": [...]}`

**designer.md**:
- Role: 设计实验方案
- Input: 假设 + codebase 约束
- Output: `{"variables": [...], "metrics": [...], "judge_criteria": "..."}`

**implementer.md**:
- Role: 实现实验代码
- Input: 实验设计 + 文件路径
- Output: `{"diff_summary": "...", "self_check": "pass/fail"}`

**runner.md**:
- Role: 在计算节点跑实验
- Input: 命令 + 资源要求
- Output: `{"metrics": {...}, "artifact_path": "...", "status": "success/fail"}`
- Constraint: 检查 `$SLURM_JOB_ID`, 无则提示用户申请节点

**analyst.md**:
- Role: 解读结果, 判定假设
- Input: 实验结果 + 假设
- Output: `{"verdict": "supported/refuted/uncertain", "confidence": 0.8, "trigger_replan": false, "reasoning": "..."}`

- [ ] **Step 2: 提交 agents**

```bash
cd /public/home/chenglongyan/workspace/starVLA
git add research-loop/agents/
git commit -m "feat(research-loop): add 5 expert agent definitions

- scout: research and locate implementations
- designer: design experiments
- implementer: implement experiment code
- runner: execute on compute nodes (respects slurm)
- analyst: interpret results and judge hypotheses

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: 端到端测试

**Files:**
- Create: `research-loop/tests/e2e-test.md`

- [ ] **Step 1: 写端到端测试文档**

`research-loop/tests/e2e-test.md`:
```markdown
# End-to-End Test

用玩具假设跑完整 init → step → resume 循环, 验证状态落盘与恢复.

## Setup

```bash
cd /tmp
mkdir test-research-repo
cd test-research-repo
git init
git config user.name "Test"
git config user.email "test@example.com"
echo "# Test Repo" > README.md
git add README.md
git commit -m "init"

# 创建玩具 idea 文件
cat > idea.md << 'EOF'
# Test Hypothesis

验证一个简单的玩具假设: "增加训练 epoch 能提升准确率"
EOF
```

## Test Flow

1. `/research:init idea.md`
   - 验证创建了 `.research/` 结构
   - 检查 IDEA.md / tree.md / DASHBOARD.md 存在且格式正确

2. `git status` → 确认 `.research/` 文件在 unstaged
3. `git add .research/ && git commit -m "init research"`

4. `/research:status`
   - 验证打印 DASHBOARD 内容

5. `/research:resume`
   - 验证恢复上下文, 报告活跃假设

6. `/research:step`(手动模拟, 因为需要真实 codebase + 计算节点)
   - 验证主控选择待验假设
   - 验证创建 experiments/E001-*.md
   - (实际 runner 步骤跳过, 手动写结果到 E001.md)
   - 验证更新 tree.md Status
   - 验证写 decisions/D001-*.md
   - 验证重写 DASHBOARD.md

7. 新 session: 清除上下文, 重新启动
   - 验证 hook 注入提示
   - `/research:resume` 恢复

## Expected Results

- 所有状态文件 git 可追溯
- hook 在新 session 正确探测
- 假设树状态更新正确
- DASHBOARD 反映最新进展

## Cleanup

```bash
cd /tmp
rm -rf test-research-repo
```
```

- [ ] **Step 2: 手动执行测试(需 Claude Code 运行时)**

端到端测试依赖插件安装与 Claude Code session, 无法在实现阶段自动化. 在插件开发完成后, 按 e2e-test.md 流程手动验证.

- [ ] **Step 3: 提交测试文档**

```bash
cd /public/home/chenglongyan/workspace/starVLA
git add research-loop/tests/e2e-test.md
git commit -m "feat(research-loop): add end-to-end test documentation

- init → step → resume cycle with toy hypothesis
- Validate state persistence and hook detection
- Manual execution guide for post-implementation verification

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review Checklist

**Spec coverage:**
- ✓ Task 1: plugin.json + README (§6.1 插件结构)
- ✓ Task 2: SessionStart hook (§5.1 hook 逻辑)
- ✓ Task 3-6: 4 个命令 (§6.2 命令职责)
- ✓ Task 7-8: 2 个 skills (§4 orchestration + §3 假设树规范)
- ✓ Task 9: 5 个 agent 定义 (§4.1 角色划分)
- ✓ Task 10: 端到端测试 (§7 验证策略)

**Placeholder scan:** 无 TBD/TODO, 每个 task 有具体内容或骨架+约束.

**Type consistency:** 
- `.research/` 目录结构在 Task 1,5,6 中一致
- 假设 ID 格式(H1, H1.1)在 Task 5,6,8 中一致
- 命令名(`/research:*`)在 Task 3-6 中一致

---

## Execution Handoff

计划完成并保存到 `docs/superpowers/plans/2026-06-16-research-loop-plugin.md`. 

两个执行选项:

**1. Subagent-Driven (推荐)** — 我派发一个 fresh subagent per task, 每个 task 完成后两阶段 review(spec compliance → code quality), 快速迭代.

**2. Inline Execution** — 在本 session 用 executing-plans batch 执行所有 tasks, checkpoints review.

你选哪种?
