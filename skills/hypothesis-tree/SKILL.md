---
name: hypothesis-tree
description: Use when the user asks to record hypotheses, create experiment records, update research results, or maintain .research tree/dashboard state
---

# Hypothesis Tree

`.research/tree.md` 是假设树的单一真相源。本 skill 规定其格式、如何读取、如何在对话中按需写入。

## File Format

```markdown
# Hypothesis Tree

## H1: <第一个一级假设内容>
Status: 待验
Evidence: (empty)
Children: H1.1, H1.2

### H1.1: <H1 的子假设>
Status: 进行中
Evidence: E001
Parent: H1

### H1.2: <H1 的另一子假设>
Status: 待验
Evidence: (empty)
Parent: H1

## H2: <第二个一级假设内容>
Status: 被推翻
Evidence: E002
```

## Status Values

| 状态 | 含义 |
|---|---|
| 待验 | 未开始验证 |
| 进行中 | 实验正在跑 |
| 被支持 | 至少一个实验支持, 无反对 |
| 被推翻 | 至少一个实验推翻 |

## ID Convention

- 一级假设: H1, H2, H3, ...
- 子假设: H1.1, H1.2, H2.1, ...
- 孙假设: H1.1.1, H1.1.2, ...
- ID 一旦分配, 永不重用(即使假设被推翻)

## Reading Active Hypotheses

从 tree.md 提取活跃假设(Status=待验 或 进行中):

```python
import re

def get_active_hypotheses(tree_content: str) -> list[dict]:
    active = []
    pattern = r'#{2,3} (H[\d.]+): (.+?)\nStatus: (待验|进行中)'
    for match in re.finditer(pattern, tree_content, re.MULTILINE):
        active.append({
            'id': match.group(1),
            'content': match.group(2),
            'status': match.group(3)
        })
    return active
```

## Updating Hypothesis Status

用 Edit tool 精确替换 Status 行, 不整文件重写:

```python
# 将 H1 从 待验 改为 被支持
Edit(
    file_path='.research/tree.md',
    old_string='## H1: ...\nStatus: 待验',
    new_string='## H1: ...\nStatus: 被支持'
)
```

## Adding Evidence

将实验 ID 追加到 Evidence 行:

```python
# 将 E003 追加到 H1 的 Evidence
Edit(
    file_path='.research/tree.md',
    old_string='## H1: ...\nStatus: 被支持\nEvidence: E001, E002',
    new_string='## H1: ...\nStatus: 被支持\nEvidence: E001, E002, E003'
)
```

## Adding New Hypothesis

新假设 append 到文件末尾:

```markdown
## H3: <新假设内容>
Status: 待验
Evidence: (empty)
```

子假设 append 在父假设段落内末尾(父假设 ## 块的末行之后, 下一个 ## 块之前).

## Invariants

- tree.md 只有主控 PI 读写, 子 agent 不直接操作
- 编号文件永不删改 — 被推翻的假设保留历史, 标记 Status: 被推翻
- Evidence 只增不删

---

## 对话中的按需写入(v1.0 新增)

### 写入触发机制

**原则**: agent 不主动/不猜测/不自动后台写, 只在用户**明确指示**时写。

**明确指示三种形式**:
1. **直接命令**: "记下这个假设 H3", "把实验写进 E004", "更新 DASHBOARD"
2. **确认式**: agent 识别到可记录内容后, 先问 "要不要我帮你记录到 tree.md?", 用户说"好"才写
3. **隐含但明确**: 结构化讨论假设/实验后说"保存"/"记录"/"写下来"等动作词

**不触发写入**(避免误判):
- 用户只是讨论/头脑风暴假设, 没说"记下来" → 不写
- 用户说"我觉得可能是 X 原因"(探索性) → 不写, 除非明确说"把 X 加到假设树"
- agent 自己推测"这个可能成立" → 不写, 必须用户确认

---

## 三个原子写入操作

### 1. `appendHypothesis(tree.md, 假设描述, 父节点)`

**触发**: 用户说 "记下这个假设: [描述]" 或 "把 X 加到假设树"

**行为**:
1. 读 `tree.md`, 解析现有假设 ID 结构
2. 确定新假设 ID:
   - 如果指定了父节点(如 "作为 H1 的子假设"), 编号为 H1.N(N=已有子假设数+1)
   - 否则作为顶层, 编号为 HM(M=现有顶层最大+1)
3. 追加到 tree.md(顶层追加到文件末, 子假设追加到父假设段末):
   ```markdown
   ## HX: [用户提供的描述]
   Status: 待验
   Evidence: (empty)
   ```
4. 刷新 DASHBOARD.md(调用 `updateDashboard`)
5. 输出确认:
   ```
   ✓ 假设 HX 已记录到 tree.md
   📝 Status: 待验
   ```

**边界**: 如果用户描述太模糊, agent 先帮忙提炼成一句话(50 字内), 征得用户确认后再写。

---

### 2. `createExperimentRecord(实验描述, 关联假设)`

**触发**: 用户说 "帮我记录这次实验" 或 "创建实验记录 Exxx"

**行为**:
1. 扫 `experiments/` 现有文件, 取最大编号 +1 → `Exxx`
2. 生成 `experiments/Exxx.md` 骨架:
   ```markdown
   # Exxx: [关联假设 ID] - [简短动作描述]
   
   **Hypothesis**: [假设 ID] [假设文本, 从 tree.md 读取]
   **Date**: [YYYY-MM-DD, 当天日期]
   **Status**: 进行中
   
   ## 实验设计
   
   **目标**: [用户描述或待补充]
   **方法**: [待补充]
   **预期**: [待补充]
   
   ## 执行记录
   
   [待补充, 用户后续对话中逐步添加]
   
   ## 结果
   
   [待实验完成后填写]
   
   ## 影响
   
   [待结果出来后分析]
   ```
3. 如果关联假设的 Status 是 `待验`, 更新为 `进行中`(在 tree.md 里)
4. 刷新 DASHBOARD.md
5. 输出确认:
   ```
   ✓ 实验记录 Exxx 已创建
   📁 experiments/Exxx.md
   💡 你可以随时对话让我更新其中的段落
   ```

**边界**: 骨架生成后, 用户可以手动编辑文件补充细节, 或在对话中说 "更新 E003 的执行记录, 加上 [内容]", agent 追加内容到对应段落。

---

### 3. `updateExperimentResult(Exxx.md, 结果内容, 结论)`

**触发**: 用户说 "E003 的结果出来了, [数据], 结论是支持 H1"

**行为**:
1. 读 `experiments/Exxx.md`, 定位 `## 结果` 段
2. 填写或追加内容:
   ```markdown
   ## 结果
   
   **数据**: [用户提供的 metrics / 观察]
   **结论**: [支持/推翻/不确定] + [理由]
   ```
3. 更新文件的 `**Status**` 字段: `进行中` → `已完成`
4. 如果结论是 `支持` 或 `推翻`, 更新 tree.md 对应假设:
   - Status: `进行中` → `被支持` 或 `被推翻`
   - Evidence: 追加 `Exxx`
5. 刷新 DASHBOARD.md
6. 输出确认:
   ```
   ✓ E003 结果已记录
   📊 结论: 支持 H1
   🔄 假设树已更新: H1 → 被支持 (Evidence: E001, E003)
   ```

**边界**: 如果结论是 `不确定`, 假设 Status 保持 `进行中`(等更多实验)。

---

### 4. `updateDashboard()`(自动调用)

**触发**: 其他三个操作调用, 或用户说 "刷新 DASHBOARD"

**行为**:
1. 扫描 tree.md, 统计:
   - Active 假设数(待验 + 进行中)
   - 已结案假设数(被支持 + 被推翻)
2. 提取 Active 假设清单(ID + 描述 + Status)
3. 重写 DASHBOARD.md:
   - 更新 `**Active**` 行的数量和 `**Last**` 日期
   - 重写 `## Active Hypotheses` 清单
   - 保留或更新 `## Next Steps`(如果用户对话中提到, 否则保持原样)

**边界**: 这是"维护一致性"操作, 确保 DASHBOARD 始终反映 tree.md 真实状态。不需要用户单独触发, 其他写入操作自动调用。

---

## 格式守护

所有写入操作必须:
1. **遵循上述格式规范**(Status 词汇/编号规则/不加粗)
2. **Append-only**: 假设 ID/实验 ID 一旦分配永不重用, Evidence 只增不删
3. **原子性**: 一次写入要么全成功, 要么全失败(出错时报告用户, 不留半截)
4. **确认反馈**: 每次写入后明确告诉用户写了什么文件、改了什么字段

---

## 实现方式

**位置**: 把这三个函数实现在主 PI 的对话流程里, 或作为可复用的辅助脚本(`scripts/helpers/*.sh`), **不拆成独立子 agent**。

**语言**: 
- 如果用 bash 实现(简单文本追加), 写成 `scripts/helpers/append-hypothesis.sh` 之类的脚本, SKILL 调用它
- 如果用 prompt 实现(agent 自己读文件→判断→写文件), 把逻辑写在 SKILL 的"写入流程"段

**校验**: 
- 写入前读一遍目标文件, 检查格式是否已损坏(比如有人手动改坏了)
- 写入后可选地做一次"自检": 重新读文件, 确认新内容在正确位置
