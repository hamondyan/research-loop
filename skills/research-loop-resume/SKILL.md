---
name: research-loop-resume
description: Use when the user asks to resume, load, restore, or continue a research loop from existing .research state
---

# Research Loop Resume

Load `.research/` state and inject a compact research context into the conversation.

## Preconditions

- Current directory is a git repository.
- `.research/IDEA.md` exists.
- `.research/tree.md` exists.
- `.research/experiments/` exists, possibly empty.

If state is missing, stop and tell the user to initialize a research loop first.

## Workflow

1. Read `.research/IDEA.md`.
2. Read `.research/tree.md` and extract all hypotheses, status values, and evidence IDs.
3. Scan `.research/experiments/*.md`. For each experiment, extract only:
   - experiment ID
   - linked hypothesis
   - date
   - status
   - conclusion summary
4. Read `.research/DASHBOARD.md` if present.
5. Produce a structured context summary of about 1000-2000 Chinese characters.

## Output Shape

```markdown
# 研究上下文

## 研究动机
[IDEA one-liner plus short background]

## 假设树
- H1: [description] (被支持, Evidence: E001)
  - H1.1: [description] (进行中)
- H2: [description] (待验)

## 实验历史
- E001 ([date]): 验证 H1, 结论=[support/refute/uncertain summary]

## Recent Validations
- [date] H1 [被支持]: [summary]

## Next Steps
1. [next step from DASHBOARD or analysis]

## State Files
IDEA:      [absolute path]/.research/IDEA.md
Tree:      [absolute path]/.research/tree.md
Dashboard: [absolute path]/.research/DASHBOARD.md
```

## Rules

- Summarize experiments; do not dump long execution logs.
- Do not modify files.
- If `DASHBOARD.md` is absent, continue without it and say so.
- If `tree.md` has invalid status vocabulary, surface the format error instead of guessing.
