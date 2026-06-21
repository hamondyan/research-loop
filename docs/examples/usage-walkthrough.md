# research-loop 使用示例

本示例演示完整工作流: init -> 对话记录假设/实验 -> resume 加载 -> status 查看。

## 初始化

用户:

```text
使用 research-loop-init, 从 idea.md 初始化研究记忆。
```

Agent:

```text
✓ 研究记忆系统已初始化
Created:
  .research/IDEA.md
  .research/tree.md
  .research/DASHBOARD.md
  .research/experiments/
```

## 对话中记录假设

用户:

```text
我觉得模型在负样本上过拟合了, 记下这个假设。
```

Agent:

```text
✓ 假设 H1 已记录到 tree.md
Status: 待验
```

此时 `.research/tree.md`:

```markdown
# Hypothesis Tree

## H1: 模型在负样本上过拟合
Status: 待验
Evidence: (empty)
```

## 记录实验

用户:

```text
帮我记录这次实验, 验证 H1。
```

Agent:

```text
✓ 实验 E001 已创建
experiments/E001.md
```

用户手动做实验后:

```text
E001 结果出来了, accuracy 从 0.85 降到 0.72, 结论是支持 H1。
```

Agent:

```text
✓ E001 结果已记录
H1 -> 被支持 (Evidence: E001)
```

此时:

- `experiments/E001.md` 的 `## 结果` 段被填写。
- `tree.md` 里 H1 Status 变 `被支持`, Evidence 变 `E001`。
- `DASHBOARD.md` 刷新。

## 加载上下文继续工作

用户:

```text
使用 research-loop-resume 恢复当前研究上下文。
```

Agent 输出研究动机、假设树、实验摘要、Next Steps 和状态文件路径。

## 查看状态

用户:

```text
使用 research-loop-status 查看当前研究状态。
```

Agent 打印 `.research/DASHBOARD.md` 全文。

## 继续添加新假设

用户:

```text
记下一个新假设: 负样本分布不均匀是导致过拟合的原因, 作为 H1 的子假设。
```

Agent:

```text
✓ 假设 H1.1 已记录到 tree.md
Status: 待验
```

## 验证要点

- 用户说"记下"/"记录"/"保存"等明确指示才写。
- `tree.md` / `experiments/Exxx.md` 格式符合 `hypothesis-tree` skill。
- resume 后 agent 能引用历史假设和实验。
- 实验结果出来时, tree Status、Evidence 和 DASHBOARD 联动更新。
