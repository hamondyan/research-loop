# research-loop v1.0 使用示例

本示例演示完整工作流: init→对话记录假设/实验→resume 加载→status 查看。

## 初始化

用户: `/research-loop:init idea.md`

系统:
```
✓ 研究记忆系统已初始化
📁 .research/IDEA.md | tree.md | DASHBOARD.md | experiments/

下一步:
  - 用 /research-loop:resume 加载上下文
  - 或直接开始对话让我帮你记录假设/实验
```

## 对话中记录假设

**用户**: "我觉得模型在负样本上过拟合了, 记下这个假设"

**Agent**: 
```
✓ 假设 H1 已记录到 tree.md
📝 Status: 待验
```

此时 `.research/tree.md` 内容:
```markdown
# Hypothesis Tree

## H1: 模型在负样本上过拟合
Status: 待验
Evidence: (empty)
```

## 记录实验

**用户**: "帮我记录这次实验, 验证 H1"

**Agent**: 
```
✓ 实验 E001 已创建
📁 experiments/E001.md
💡 你可以随时对话让我更新其中的段落
```

此时生成 `experiments/E001.md` 骨架, H1 Status 从 `待验` 变 `进行中`。

### 用户手动做实验

(用户在自己的环境跑训练/eval, 得到结果...)

**用户**: "E001 结果出来了, accuracy 从 0.85 降到 0.72, 结论是支持 H1"

**Agent**:
```
✓ E001 结果已记录
📊 结论: 支持 H1
🔄 假设树已更新: H1 → 被支持 (Evidence: E001)
```

此时:
- `experiments/E001.md` 的 `## 结果` 段被填写
- `tree.md` 里 H1 Status 变 `被支持`, Evidence 变 `E001`
- `DASHBOARD.md` 刷新(Active 假设清单更新)

## 加载上下文继续工作

(第二天打开新 session)

**用户**: `/research-loop:resume`

**系统**:
```
✓ 研究上下文已加载
📚 1 个假设 | 1 个实验记录
现在你可以继续对话, 我会带着这些记忆帮你分析和记录
```

(agent 内部注入了结构化上下文, 包含 IDEA 动机 + H1 假设树 + E001 实验摘要)

**用户**: "H1 被支持了, 那下一步应该干什么?"

**Agent**: (能引用 H1/E001 回答, 因为 resume 已经把历史注入进来了)

## 查看状态

**用户**: `/research-loop:status`

**系统**: (打印 DASHBOARD.md 全文 + 统计)
```
# Research Dashboard

**IDEA**: 测试模型对负样本的泛化能力
**Active**: 0 hypotheses | **Last**: 2026-06-20

## Active Hypotheses
(空, 所有假设已结案)

## Next Steps
1. 分析 H1 的子机制(是训练数据分布问题还是模型容量问题)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 统计
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
总假设: 1 个 (待验: 0 / 进行中: 0 / 被支持: 1 / 被推翻: 0)
实验记录: 1 个 (experiments/E001.md)
上次更新: 2026-06-20
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 继续添加新假设

**用户**: "记下一个新假设: 负样本分布不均匀是导致过拟合的原因, 作为 H1 的子假设"

**Agent**:
```
✓ 假设 H1.1 已记录到 tree.md
📝 Status: 待验
```

此时 tree.md:
```markdown
# Hypothesis Tree

## H1: 模型在负样本上过拟合
Status: 被支持
Evidence: E001

### H1.1: 负样本分布不均匀是导致过拟合的原因
Status: 待验
Evidence: (empty)
```

---

## 验证要点

**对话中写入触发**: 用户说"记下"/"记录"/"保存"等明确指示才写, 不主动/不猜测。

**格式一致性**: agent 写入的 tree.md / experiments/Exxx.md 符合格式规范(Status 4 词汇/不加粗/append-only)。

**上下文注入**: resume 后 agent 能引用历史假设/实验, 证明注入成功。

**联动更新**: 实验结果出来时, tree.md Status + Evidence 自动更新, DASHBOARD 同步刷新。
