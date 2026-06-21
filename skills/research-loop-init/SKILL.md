---
name: research-loop-init
description: Use when the user asks to initialize a research loop, create .research state, or start tracking a research idea from an idea file
---

# Research Loop Init

Initialize a `.research/` directory from an idea file. Run this only once at the start of a research thread.

## Preconditions

- Current directory is a git repository.
- The idea file exists and is readable.
- `.research/` does not already exist. If it exists, stop and ask whether to resume instead.

## Workflow

1. Read the idea file.
2. Clarify the research frame with the user:
   - motivation: why this research matters
   - core hypotheses: what mechanism or intervention may explain the outcome
   - success criteria: what result would support the decision
3. Propose an initial hypothesis tree with 2-4 top-level hypotheses and optional children.
4. Show the draft tree and wait for user confirmation.
5. Check the current git branch. If it is `main`, `master`, `develop`, or another non-experiment branch, suggest creating a branch but do not create one unless the user explicitly provides a branch name.
6. Create:
   ```text
   .research/
   ├── IDEA.md
   ├── tree.md
   ├── DASHBOARD.md
   └── experiments/
   ```
7. Write `IDEA.md`:
   ```markdown
   # Research IDEA

   ## 动机

   [1-2 paragraphs]

   ## 核心问题

   - [question]

   ## 成功判据

   [criteria]

   ## 初始假设

   - H1: [summary]

   ## 参考资料

   [links or notes from idea file]
   ```
8. Write `tree.md` using the `hypothesis-tree` format:
   ```markdown
   # Hypothesis Tree

   ## H1: [full hypothesis]
   Status: 待验
   Evidence: (empty)
   Children: H1.1

   ### H1.1: [child hypothesis]
   Status: 待验
   Evidence: (empty)
   Parent: H1
   ```
9. Write `DASHBOARD.md`:
   ```markdown
   # Research Dashboard

   **IDEA**: [one-line idea]
   **Active**: [count] hypotheses | **Last**: [YYYY-MM-DD]

   ## Active Hypotheses

   - H1: [description] (待验)

   ## Next Steps

   1. [next discriminating experiment or analysis]
   ```
10. Report the created files and suggest resuming or recording the first experiment.

## Invariants

- Use only `待验`, `进行中`, `被支持`, `被推翻` for hypothesis status.
- `Status:` in `tree.md` is plain text, never bold.
- Evidence is append-only and starts as `(empty)`.
- Hypothesis IDs are never reused.
- Do not invent weak ablations or low-value experiments just to fill a table.
