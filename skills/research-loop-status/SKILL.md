---
name: research-loop-status
description: Use when the user asks for current research-loop status, dashboard, active hypotheses, or a read-only progress check
---

# Research Loop Status

Print current research status without side effects.

## Preconditions

- Current directory is a git repository.
- `.research/DASHBOARD.md` exists.

## Workflow

1. Check whether `.research/DASHBOARD.md` exists.
2. If it does not exist, say: `当前分支无进行中的研究. 先初始化 research loop.`
3. If it exists, read and print the complete file content.

## Rules

- Read-only operation.
- Do not update `DASHBOARD.md`.
- Do not infer missing fields.
- Do not start experiments.
