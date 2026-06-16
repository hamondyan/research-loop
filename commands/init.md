---
description: 从 idea 文件初始化 .research/ 目录
---

# /research-loop:init <idea文件>

从 idea 文件读取初步想法, 通过对话提炼核心动机/假设/成功判据, 建立初始假设树, 创建 `.research/` 结构.

## 前置条件

- 当前目录是 git 仓库
- `<idea文件>` 存在且可读
- `.research/` 目录不存在(避免覆盖已有研究)

## 执行流程

### 1. 读取 idea 文件

读取 `<idea文件>` 全文, 提取核心内容.

### 2. 对话提炼核心要素

通过结构化对话, 与用户澄清:

- **研究动机**: 为什么要做这个研究? 要解决什么问题?
- **核心假设**: 你认为什么机制/因素导致了问题? 或什么改进能带来提升?
- **成功判据**: 如何判断假设成立? 需要什么数据/实验?

对话示例见下方 "对话示例" 章节.

### 3. 提议初始假设树

根据对话结果, 提议分层假设树结构:

- **H1/H2/H3**: 顶层假设(通常 2-4 个核心假设)
- **H1.1/H1.2**: 子假设(机制分解或实验条件细化)
- **Status 字段**: 全部初始化为 `待验`
- **Evidence 字段**: 标记 `(empty)`

向用户展示假设树草案, 确认或调整.

### 4. 检查分支状态并建议

- 检查当前 git 分支名
- 若当前分支是 main/master/develop 或其他非实验分支, 提示用户:
  ```
  当前在 [分支名] 分支. 建议为此研究创建新分支以隔离实验代码.
  是否创建新分支? (输入分支名 或 输入 'no' 留在当前分支)
  ```
- **严禁擅自创建分支**: 必须等待用户明确同意和提供分支名后, 才能执行 `git checkout -b <分支名>`

### 5. 创建 .research/ 目录结构

```
.research/
├── IDEA.md         # 研究动机和核心问题
├── tree.md         # 假设树(分层结构 + 状态追踪)
├── DASHBOARD.md    # 当前进展仪表盘
└── artifacts/      # 实验产出(日志/图表/模型 checkpoint)
    └── .gitkeep
```

### 6. 写入 IDEA.md

内容结构:

```markdown
# Research IDEA

## 动机

[从 idea 文件和对话中提炼的核心动机, 1-2 段]

## 核心问题

- [问题 1]
- [问题 2]
- [问题 3]

## 成功判据

[如何判断研究有效? 需要哪些数据/实验结果?]

## 初始假设

- H1: [假设 1 简述]
- H2: [假设 2 简述]
- H3: [假设 3 简述]

## 参考资料

[若 idea 文件中包含论文/代码链接, 保留在此]
```

### 7. 写入 tree.md

假设树结构, 使用 markdown 标题分层. 格式必须与 `hypothesis-tree` skill 一致(Status 不加粗, 空 Evidence 标记 `(empty)`):

```markdown
# Hypothesis Tree

## H1: [假设 1 完整描述]
Status: 待验
Evidence: (empty)
Children: H1.1, H1.2

### H1.1: [子假设 1.1]
Status: 待验
Evidence: (empty)
Parent: H1

### H1.2: [子假设 1.2]
Status: 待验
Evidence: (empty)
Parent: H1

## H2: [假设 2 完整描述]
Status: 待验
Evidence: (empty)
Children: H2.1

### H2.1: [子假设 2.1]
Status: 待验
Evidence: (empty)
Parent: H2
```

### 8. 写入 DASHBOARD.md

初始化进展仪表盘:

```markdown
# Research Dashboard

**IDEA**: [IDEA 一句话概括]
**Active**: [活跃假设数量] hypotheses | **Last**: [今天日期]

## Active Hypotheses

- H1: [假设 1] (待验)
- H2: [假设 2] (待验)
- H3: [假设 3] (待验)

## Next Steps

1. 设计 H1 的判别实验
2. 确定 H2 的数据收集方案
```

### 9. 创建 artifacts/.gitkeep

确保 `artifacts/` 目录被 git 追踪:

```bash
mkdir -p .research/artifacts
touch .research/artifacts/.gitkeep
```

### 10. 提示用户下一步

输出初始化成功信息:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Research initialized successfully
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Created:
  .research/IDEA.md        - 研究动机和核心问题
  .research/tree.md        - 假设树(X 个假设)
  .research/DASHBOARD.md   - 进展仪表盘
  .research/artifacts/     - 实验产出目录

Next Steps:
  1. 用 /research-loop:status 查看当前状态
  2. 设计 H1 的验证实验
  3. 用 /research-loop:step 跑一轮假设验证循环
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 对话示例

### AI 首次读取 idea 文件后

```
我读取了你的 idea 文件. 内容概要:

"测试 VLA 模型对复杂指令的理解能力, 尤其是包含否定词(如 '不要', '避免')的指令.
当前观察: 模型在 RoboSuite 任务中经常忽略否定指令, 直接执行正向动作."

为了建立清晰的研究框架, 我需要和你确认几个关键点:

1. **研究动机**: 你为什么关注否定词理解? 是因为:
   - 安全场景需要模型严格遵守禁止指令?
   - 发现否定词导致成功率显著下降?
   - 其他原因?

2. **核心假设**: 你认为模型忽略否定词的原因是什么? 比如:
   - 训练数据中否定指令太少?
   - instruction encoder 对否定词不敏感?
   - 动作解码器直接预测正向动作, 忽略了约束?

3. **成功判据**: 如何判断改进有效?
   - 对比 baseline 和新方法在 "否定指令任务" 上的成功率?
   - 需要设计新的评估任务吗?
   - 阈值是多少? (比如成功率提升 >10% 才算有效)
```

### 用户回复后

```
用户: 主要是安全原因. 我怀疑是训练数据问题, 因为 instruction token 的 loss 权重很低.
     判据就是对比 baseline 和增加 instruction loss 权重后的成功率, 提升 >15% 算有效.

AI: 明白了. 根据你的回答, 我提议以下假设树:

H1: VLA 对否定词不敏感的根本原因是训练中 instruction token 权重过低
  H1.1: 增加 instruction token 的 loss 权重能提升否定词敏感度
    - 验证方法: 对比 baseline vs 2x/5x/10x instruction loss 权重
  H1.2: 增加权重后模型能否泛化到未见过的否定词组合?
    - 验证方法: 在 held-out 否定指令任务上测试

H2: 否定指令在训练数据中分布不均(可能 <5%)
  H2.1: 统计训练集中否定词出现频率
  H2.2: 若频率 <5%, 考虑数据增强(paraphrase 或生成否定指令)

H3: 动作解码器的结构限制导致无法表达 "不做某动作"
  H3.1: 分析 action space 是否支持 "null action" 或 "禁止区域"
  H3.2: 若不支持, 设计新的 action representation

这个假设树合理吗? 需要调整或补充吗?
```

### 用户确认后

```
用户: 合理. H3 可以先不考虑, 太复杂了. 先验证 H1 和 H2.

AI: 收到. 我会移除 H3, 保留 H1 和 H2.

当前你在 'starVLA_dev' 分支. 建议为此研究创建新分支以隔离实验代码.
是否创建新分支? (输入分支名 或 输入 'no' 留在当前分支)
```

### 用户回复分支决策后

```
用户: exp/negation-instruction-weight

AI: 好的, 创建并切换到新分支 'exp/negation-instruction-weight'.

[执行 git checkout -b exp/negation-instruction-weight]

正在初始化 .research/ 结构...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Research initialized successfully
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Created:
  .research/IDEA.md        - 研究动机和核心问题
  .research/tree.md        - 假设树(2 个顶层假设, 5 个子假设)
  .research/DASHBOARD.md   - 进展仪表盘
  .research/artifacts/     - 实验产出目录

Next Steps:
  1. 用 /research-loop:status 查看当前状态
  2. 设计 H1.1 的验证实验(对比 baseline vs 不同 instruction loss 权重)
  3. 用 /research-loop:step 跑一轮假设验证循环
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 实现注意

1. **对话必须具体**: 不使用 placeholder, 根据 idea 文件内容生成针对性问题
2. **分支创建约束**: 严禁擅自创建分支, 必须用户明确同意
3. **假设树层级**: 顶层假设 2-4 个, 每个假设下 1-3 个子假设
4. **容错处理**:
   - 若 idea 文件格式混乱, 提示用户补充核心信息
   - 若用户拒绝对话直接要求初始化, 用 idea 文件原文生成基础 IDEA.md, 但警告缺少假设树
5. **日期标准**: 使用 ISO 8601 格式 `YYYY-MM-DD`
