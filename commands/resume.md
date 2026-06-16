---
description: 加载 .research/ 状态, 恢复研究上下文, 报告当前进展与下一步
---

# /research-loop:resume

加载 `.research/` 状态文件(IDEA + tree + DASHBOARD), 解析活跃假设, 输出完整研究摘要和下一步建议, 恢复研究上下文.

## 前置条件

- 当前目录是 git 仓库
- `.research/IDEA.md` 存在
- `.research/tree.md` 存在

## 执行

1. **读取核心文件**
   - 读取 `.research/IDEA.md` → 提取核心问题和研究动机
   - 读取 `.research/tree.md` → 解析假设树结构
   - 读取 `.research/DASHBOARD.md`(若存在) → 获取最新进展

2. **解析假设树**
   - 扫描所有 H1/H2/H3 标题
   - 提取 Status 字段(待验/进行中/被支持/被推翻)
   - 提取 Evidence 字段(实验 ID/数据路径)
   - 识别活跃假设(待验/进行中)

3. **生成摘要**
   - IDEA 一句话概括
   - 核心问题列表
   - 活跃假设清单(含状态)
   - 最近验证记录(最多 3 条)
   - 建议的下一步操作

4. **输出完整路径指针**
   - `.research/IDEA.md` 完整路径
   - `.research/tree.md` 完整路径
   - `.research/DASHBOARD.md` 完整路径(若存在)

## 输出格式

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔬 Research Context Restored
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## IDEA
[IDEA.md 第一句话或核心主张]

## Core Questions
- [核心问题 1]
- [核心问题 2]

## Active Hypotheses (X total)
- [H1] [假设描述] → Status: [待验/进行中]
- [H1.1] [子假设描述] → Status: [待验]
- [H2] [假设描述] → Status: [进行中]
  └─ Evidence: [实验路径/数据]

## Recent Validations
- [日期] H1.2 [被支持]: [结论摘要]
- [日期] H3 [被推翻]: [否定证据]

## Next Steps
1. [建议操作 1] (如: 完成 H1 的判别实验)
2. [建议操作 2] (如: 设计 H2 的验证方案)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 State Files
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
IDEA:      /absolute/path/to/.research/IDEA.md
Tree:      /absolute/path/to/.research/tree.md
Dashboard: /absolute/path/to/.research/DASHBOARD.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 实现注意

1. **只读命令**: 不修改任何文件, 纯粹的状态报告

2. **假设树格式约定**:
   - H1/H2/H3 标题识别层级
   - `Status:` 字段(不加粗): `待验` / `进行中` / `被支持` / `被推翻`
   - `Evidence:` 字段: 实验 ID 或数据摘要, 空标记 `(empty)`

3. **容错处理**:
   - 若 `.research/DASHBOARD.md` 不存在, 仅从 IDEA 和 tree 生成摘要
   - 若 tree.md 格式异常, 输出警告但不中断

4. **日期推断**:
   - 从 git log 或文件修改时间推断最近验证日期
   - 若无法获取, 标记为 "日期未知"

5. **下一步建议逻辑**:
   - 优先推荐 `待验` 假设的验证实验
   - 若无待验假设, 建议添加新假设或总结已被支持的结论
