#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -f .claude-plugin/plugin.json ]] || fail "missing Claude plugin manifest"
[[ -f .codex-plugin/plugin.json ]] || fail "missing Codex plugin manifest"

python3 - <<'PY' || exit 1
import json
from pathlib import Path

manifest = json.loads(Path(".codex-plugin/plugin.json").read_text())
assert manifest["name"] == "research-loop"
assert manifest["skills"] == "./skills/"
assert "interface" in manifest
PY

for skill in research-loop-init research-loop-resume research-loop-status hypothesis-tree; do
  path="skills/${skill}/SKILL.md"
  [[ -f "$path" ]] || fail "missing $path"
  rg -q "^---$" "$path" || fail "$path missing frontmatter"
  rg -q "^name: ${skill}$" "$path" || fail "$path has wrong skill name"
  rg -q "^description: Use when" "$path" || fail "$path description is not trigger-focused"
done

if [[ -d commands ]] && find commands -type f | grep -q .; then
  fail "commands/ still contains command entry files"
fi

if rg -n "/research-loop:(init|resume|status)|SessionStart hook" README.md CLAUDE.md docs/examples; then
  fail "docs still advertise slash commands or hooks"
fi

printf 'structure-test passed\n'
