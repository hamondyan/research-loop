---
name: hypothesis-tree
description: 假设树读写规范 — .research/tree.md 的格式、读取和写入方式
---

# Hypothesis Tree

`.research/tree.md` 是假设树的单一真相源, 规定格式如下.

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
