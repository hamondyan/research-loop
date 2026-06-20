# End-to-End Test: Research Loop

## Overview

This test validates the complete research loop lifecycle: `init → status → resume → step` with state persistence and recovery across sessions.

## Test Objective

Verify that:
- `/research-loop:init` creates correct `.research/` structure
- `/research-loop:step` generates experiments and updates the hypothesis tree
- State files are git-trackable
- `/research-loop:resume` restores context correctly
- The SessionStart hook detects active research and injects context

## Setup

Create a temporary git repository with a toy idea file:

```bash
# Create temp test environment
TEST_DIR=$(mktemp -d /tmp/research-e2e-test.XXXXXX)
cd "$TEST_DIR"
git init
git config user.name "Test User"
git config user.email "test@example.com"
git commit --allow-empty -m "init"

# Create toy idea file
cat > toy_idea.md << 'EOF'
# Idea: Reduce Training Time by 20%

## Motivation
Current training on Robocasa takes 48 hours. We suspect data loading is the bottleneck.

## Proposed Approach
1. Profile data loading pipeline
2. Implement prefetch buffer
3. Benchmark end-to-end training time

## Expected Outcome
Training completes in ~38 hours (20% reduction).
EOF

echo "Test environment created at: $TEST_DIR"
```

## Test Flow

### Step 1: Initialize Research Loop

```bash
# Trigger /research-loop:init
/research-loop:init toy_idea.md
```

**Expected Output:**
- Creates `.research/` directory with structure:
  - `IDEA.md` (motivation + core questions + success criteria)
  - `tree.md` (with H1 as root hypothesis)
  - `DASHBOARD.md` (initialized, canonical format)
  - `artifacts/.gitkeep`

**Verify:**
```bash
find .research/ -type f | sort
cat .research/tree.md
cat .research/DASHBOARD.md
```

Expected `tree.md` (Status not bold, IDs H1/H1.1):
```
# Hypothesis Tree

## H1: 数据加载是训练时间瓶颈
Status: 待验
Evidence: (empty)
Children: H1.1

### H1.1: prefetch buffer 能减少 I/O 等待
Status: 待验
Evidence: (empty)
Parent: H1
```

Expected `DASHBOARD.md` (canonical Chinese format):
```
# Research Dashboard

**IDEA**: 缩短 Robocasa 训练时间 20%
**Active**: 2 hypotheses | **Last**: 2026-06-16

## Active Hypotheses
- H1: 数据加载是训练时间瓶颈 (待验)
- H1.1: prefetch buffer 能减少 I/O 等待 (待验)

## Next Steps
1. 设计 H1 的判别实验(profile 数据加载占比)
```

### Step 2: Commit Research State

```bash
git add .research/ toy_idea.md
git commit -m "research: initialize H1 - reduce training time"
git log --oneline
git ls-tree -r HEAD .research/
```

### Step 3: Check Research Status

```bash
/research-loop:status
```

**Expected Output:**
- Prints `DASHBOARD.md` content verbatim
- Shows H1 and H1.1 as 待验
- No side effects (read-only)

### Step 4: Resume Research Context

```bash
# Simulate a fresh Claude session
/research-loop:resume
```

**Expected Output:**
- Prints "Research Context Restored"
- IDEA one-liner + core questions
- Active Hypotheses list with Status (待验/进行中)
- Absolute paths to IDEA.md / tree.md / DASHBOARD.md

### Step 5: Execute Research Step

**Note:** This step requires real codebase access and compute node allocation. On the management node, `/research-loop:step` orchestrates sub-agents; the `runner` agent must detect it is not in a slurm job and refuse to run training directly (returns `status=fail`). To exercise the full loop, run on an allocated compute node.

```bash
# On a compute node ($SLURM_JOB_ID set):
/research-loop:step
```

**Expected Behavior:**
- Selects first 待验 hypothesis (H1) from tree.md
- designer returns experiment design JSON (variables/metrics/judge_criteria/commands)
- Creates `experiments/E001_*.md` (Status: 待执行)
- implementer applies code changes + self-check
- runner executes commands on compute node, returns metrics
- analyst returns verdict (supported/refuted/uncertain)
- Main PI maps verdict → tree Status (supported→被支持, refuted→被推翻, uncertain→进行中)
- Updates `tree.md` H1 Status + Evidence: E001
- Creates `decisions/D001_*.md` if verdict is supported/refuted
- Rewrites `DASHBOARD.md`

### Step 6: Verify State Updates

```bash
cat .research/experiments/E001_*.md
cat .research/tree.md
cat .research/DASHBOARD.md
[ -d .research/decisions ] && cat .research/decisions/D001_*.md

git add .research/
git commit -m "research: E001 - profiled data loading bottleneck"
```

**Expected `tree.md` after a supported verdict:**
```
## H1: 数据加载是训练时间瓶颈
Status: 被支持
Evidence: E001
Children: H1.1
```

**Expected `DASHBOARD.md` update:**
- `**Last**` bumped to today
- H1 removed from Active Hypotheses (已结案), H1.1 remains 待验/进行中
- Next Steps reflects analyst recommendation

### Step 7: Cross-Session Recovery Test (Hook)

```bash
# Simulate a new Claude Code session in the same repo.
# The SessionStart hook (hooks/session-start) should detect
# .research/DASHBOARD.md and inject research context.

# Manually invoke the hook to verify its output:
"${CLAUDE_PLUGIN_ROOT}/hooks/session-start"
```

**Expected Output:**
- Emits JSON with `hookSpecificOutput.hookEventName = "SessionStart"` and a non-empty `hookSpecificOutput.additionalContext` field
- `additionalContext` includes the current branch and the IDEA one-liner
- If not on a branch (detached HEAD) or no DASHBOARD, exits silently with no output

**Verify Hook Wiring:**
```bash
cat "${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json"   # SessionStart → hooks/session-start
```

## Expected Results Summary

| Test Point | Expected Outcome |
|------------|------------------|
| Init | `.research/` structure created, H1 registered (待验) |
| Git Tracking | State files committed, history clean |
| Status | DASHBOARD prints correctly (canonical format) |
| Resume | Context restored with hypotheses + tree |
| Step | E001 created, tree Status updated via verdict mapping, DASHBOARD rewritten |
| State Persistence | All updates in git, no orphaned files |
| Hook Detection | New session emits additionalContext with research info |
| Cross-Session | Resume works without prior context |

## Failure Modes to Check

1. **Missing State Files**: If `tree.md` or `DASHBOARD.md` not found → init failed
2. **Stale Vocabulary**: tree.md shows `已验证`/`已否决` or bold `**Status**` → format drift
3. **Hook Silent Failure**: New session emits nothing despite valid DASHBOARD → hook parse bug
4. **Stale Dashboard**: DASHBOARD `**Last**` not bumped after step → rewrite failed
5. **Runner On Management Node**: runner does not refuse when `$SLURM_JOB_ID` is unset → slurm guard broken

## Cleanup

```bash
cd /
rm -rf "$TEST_DIR"
echo "Cleanup complete. Test environment deleted."
```

## Notes for Manual Execution

- **Step 5** requires a real codebase with a training script, compute node allocation (not the management node), and profiling tools.
- `/research-loop:step` takes no arguments; it auto-selects the next 待验 hypothesis from tree.md.
- Time budget: ~15 minutes for the non-compute portion of the cycle.

## Post-Implementation Checklist

- [ ] Run `tests/hook-test.sh` and confirm all pass
- [ ] Run this e2e flow through init → status → resume
- [ ] Check git history shows clean state transitions
- [ ] Confirm hook emits additionalContext with research info in a new session
- [ ] Validate DASHBOARD accuracy after a step (verdict → status mapping correct)
