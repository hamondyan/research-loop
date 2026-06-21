---
description: 加载 .research/ 状态, 将研究上下文注入对话
---

# /research-loop:resume

加载 `.research/` 状态(IDEA + tree + experiments 摘要), 拼成结构化上下文字符串(中等详细度, ~1000-2000 字), 注入对话, 让 agent 带着记忆继续工作。

## 前置条件

- 当前目录是 git 仓库
- `.research/IDEA.md` 存在
- `.research/tree.md` 存在
- `.research/experiments/` 目录存在(可为空)

## 执行

1. **检查 `.research/` 存在**, 不存在则提示用 `/research-loop:init` 初始化

2. **读取并解析**:
   - `IDEA.md` → 提取动机(一句话 + 核心背景)
   - `tree.md` → 解析假设树(所有假设 + Status + Evidence)
   - `experiments/*.md` → 扫描所有实验文件, 提取摘要(Hypothesis / Date / 结论, 不读全文以控制 token)

3. **拼成结构化上下文字符串**(中等详细度, ~1000-2000 字):
   ```markdown
   # 研究上下文
   
   ## 研究动机
   [IDEA 一句话 + 核心背景段落]
   
   ## 假设树
   - H1: [描述] (被支持, 已验证: E001, E003)
     - H1.1: [描述] (进行中)
   - H2: [描述] (被推翻, E002)
   - H3: [描述] (待验)
   
   ## 实验历史(摘要)
   - E001 (2026-06-15): 验证 H1, 结论=支持, 因为 [一句话理由]
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

1. **摘要而非全文**: experiments 只读 Hypothesis/Date/结论一句话, 不读"## 执行记录"全文, 控制 token 消耗在合理范围(~1000-2000 字总上下文)

2. **中等详细度**: 符合用户选的"中量: +实验历史"档位, 不是轻量(只树)也不是全量(含所有细节)

3. **注入方式**: 如果 Claude Code 支持动态插入上下文, 用最优雅的方式; 否则退化为"打印一段然后说'以上是研究记忆, 记住它'"

4. **假设树格式约定**:
   - H1/H2/H3 标题识别层级
   - `Status:` 字段(不加粗): `待验` / `进行中` / `被支持` / `被推翻`
   - `Evidence:` 字段: 实验 ID, 空标记 `(empty)`

5. **容错处理**:
   - 若 `.research/DASHBOARD.md` 不存在, 不影响注入(只是缺"下一步建议"段)
   - 若 tree.md 格式异常, 尽力解析, 异常部分跳过并在上下文中注明
