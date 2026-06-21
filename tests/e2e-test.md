# E2E Test: Research Loop Skills

这个手动测试验证 skill 入口的完整生命周期: init -> status -> resume -> 记录实验结果。

## Setup

```bash
TEST_DIR=$(mktemp -d /tmp/research-e2e-test.XXXXXX)
cd "$TEST_DIR"
git init
git config user.name "Test User"
git config user.email "test@example.com"
git commit --allow-empty -m "init"

cat > toy_idea.md << 'EOF'
# Idea: Reduce Training Time by 20%

## Motivation
Current training on Robocasa takes 48 hours. We suspect data loading is the bottleneck.

## Proposed Approach
1. Profile data loading pipeline
2. Implement prefetch buffer
3. Benchmark end-to-end training time

## Expected Outcome
Training completes in about 38 hours.
EOF
```

## Test 1: Init

对 agent 说:

```text
使用 research-loop-init, 从 toy_idea.md 初始化研究记忆。
```

Expected:

- `.research/IDEA.md` exists.
- `.research/tree.md` exists.
- `.research/DASHBOARD.md` exists.
- `.research/experiments/` exists.
- `tree.md` uses plain `Status:` lines and Chinese status vocabulary.

Verify:

```bash
find .research -type f | sort
cat .research/tree.md
cat .research/DASHBOARD.md
```

## Test 2: Status

对 agent 说:

```text
使用 research-loop-status 查看当前研究状态。
```

Expected:

- Prints `.research/DASHBOARD.md` verbatim.
- Does not modify any file.

Verify:

```bash
git diff -- .research
```

## Test 3: Resume

对 agent 说:

```text
使用 research-loop-resume 恢复当前研究上下文。
```

Expected:

- Prints a compact research context.
- Includes IDEA, hypothesis tree, experiment summaries, next steps, and absolute state file paths.
- Does not modify any file.

## Test 4: Record Experiment

对 agent 说:

```text
帮我记录这次实验, 验证 H1: profile 数据加载耗时占比。
```

Expected:

- Creates `.research/experiments/E001.md`.
- Updates H1 from `待验` to `进行中` if appropriate.
- Refreshes `DASHBOARD.md`.

Then say:

```text
E001 结果出来了: 数据加载占总训练时间 37%, 结论是支持 H1。
```

Expected:

- Updates `E001.md` result section.
- Marks `E001.md` status as `已完成`.
- Appends `E001` to H1 Evidence.
- Updates H1 status to `被支持`.
- Refreshes `DASHBOARD.md`.

## Cleanup

```bash
cd /
rm -rf "$TEST_DIR"
```
