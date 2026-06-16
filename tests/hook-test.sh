#!/usr/bin/env bash
# Test suite for SessionStart hook

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="${SCRIPT_DIR}/../hooks/session-start"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass_count=0
fail_count=0

# Helper: run hook and capture output
run_hook() {
    local cwd="$1"
    (cd "$cwd" && "$HOOK_SCRIPT") 2>&1 || true
}

# Helper: assert empty output
assert_empty() {
    local test_name="$1"
    local output="$2"

    if [[ -z "$output" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Expected: empty output"
        echo "  Got: $output"
        fail_count=$((fail_count + 1))
    fi
}

# Helper: assert contains text
assert_contains() {
    local test_name="$1"
    local output="$2"
    local expected="$3"

    if [[ "$output" == *"$expected"* ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Expected output to contain: $expected"
        echo "  Got: $output"
        fail_count=$((fail_count + 1))
    fi
}

# Test 1: 非 git 仓库 → 静默退出
test_non_repo() {
    local tmpdir=$(mktemp -d)

    local output=$(run_hook "$tmpdir")
    assert_empty "非仓库静默退出" "$output"

    rm -rf "$tmpdir"
}

# Test 2: git 仓库但无 .research/ → 静默退出
test_no_research() {
    local tmpdir=$(mktemp -d)

    (cd "$tmpdir" && git init -q && git config user.email "test@test.com" && git config user.name "Test") 2>/dev/null
    local output=$(run_hook "$tmpdir")
    assert_empty "无状态静默退出" "$output"

    rm -rf "$tmpdir"
}

# Test 3: 仓库有 .research/DASHBOARD.md → 注入提示
test_with_dashboard() {
    local tmpdir=$(mktemp -d)

    (cd "$tmpdir" && \
     git init -q && \
     git config user.email "test@test.com" && \
     git config user.name "Test" && \
     git commit --allow-empty -m "init" -q) 2>/dev/null
    mkdir -p "$tmpdir/.research"
    cat > "$tmpdir/.research/DASHBOARD.md" <<'EOF'
# Research Dashboard

**IDEA**: Test position embedding scaling
**Active**: 2 hypotheses | **Last**: 2026-06-15

## Active Hypotheses
- H1: 位置编码缩放提升长序列泛化 (待验)
- H1.1: scale=2.0 优于 baseline (进行中)

## Next Steps
1. 设计 H1.1 的判别实验
EOF

    local output=$(run_hook "$tmpdir")

    # 1. 输出必须是合法 JSON(否则 Claude Code 会报 hook error)
    if ! echo "$output" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then
        echo -e "${RED}✗ FAIL${NC}: 仓库有状态注入: 输出不是合法 JSON"
        echo "Got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        rm -rf "$tmpdir"
        return
    fi

    # 2. 必须包含 hookEventName=SessionStart(Claude Code schema 要求)
    assert_contains "仓库有状态注入: hookEventName" "$output" '"hookEventName": "SessionStart"'

    # 3. 必须用 additionalContext 字段(不是 systemPromptSection)
    assert_contains "仓库有状态注入: additionalContext" "$output" '"additionalContext"'

    # 4. 注入内容应包含 IDEA
    assert_contains "仓库有状态注入: IDEA 文本" "$output" "Test position embedding scaling"

    rm -rf "$tmpdir"
}

# Test 4: DASHBOARD.md 不完整 → 静默退出
test_incomplete_dashboard() {
    local tmpdir=$(mktemp -d)

    (cd "$tmpdir" && git init -q && git config user.email "test@test.com" && git config user.name "Test") 2>/dev/null
    mkdir -p "$tmpdir/.research"
    echo "incomplete content" > "$tmpdir/.research/DASHBOARD.md"

    local output=$(run_hook "$tmpdir")
    assert_empty "不完整 DASHBOARD 静默退出" "$output"

    rm -rf "$tmpdir"
}

# Test 5: detached HEAD → 静默退出
test_detached_head() {
    local tmpdir=$(mktemp -d)

    (cd "$tmpdir" && \
     git init -q && \
     git config user.email "test@test.com" && \
     git config user.name "Test" && \
     git commit --allow-empty -m "init" -q && \
     git checkout --detach -q) 2>/dev/null
    mkdir -p "$tmpdir/.research"
    cat > "$tmpdir/.research/DASHBOARD.md" <<'EOF'
# Research Dashboard

**IDEA**: Test detached HEAD
**Active**: 1 hypotheses | **Last**: 2026-06-16

## Active Hypotheses
- H1: detached HEAD 场景 (待验)
EOF

    local output=$(run_hook "$tmpdir")
    assert_empty "detached HEAD 静默退出" "$output"

    rm -rf "$tmpdir"
}

# Run all tests
echo "Running SessionStart hook tests..."
echo

test_non_repo
test_no_research
test_with_dashboard
test_incomplete_dashboard
test_detached_head

echo
echo "========================================"
echo "Total: $((pass_count + fail_count)) tests"
echo -e "${GREEN}Passed: $pass_count${NC}"
if [[ $fail_count -gt 0 ]]; then
    echo -e "${RED}Failed: $fail_count${NC}"
    exit 1
else
    echo "All tests passed!"
    exit 0
fi
