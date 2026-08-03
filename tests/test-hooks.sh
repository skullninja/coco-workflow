#!/usr/bin/env bash
# Test suite for the PreToolUse Bash guardrail hook
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/scripts/pre-tool-use-bash.sh"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# A coco-initialized project, plus a nested package dir with no .coco of its own.
mkdir -p "$TEST_DIR/project/.coco"
touch "$TEST_DIR/project/.coco/config.yaml"
mkdir -p "$TEST_DIR/project/pkg/deep"
mkdir -p "$TEST_DIR/bare"

PASS=0
FAIL=0

# run_hook <cwd> <command> -> prints the deny reason, or empty when allowed
run_hook() {
    local cwd="$1" cmd="$2"
    env -u CLAUDE_PROJECT_DIR jq -n --arg c "$cmd" --arg d "$cwd" \
        '{tool_name:"Bash", cwd:$d, tool_input:{command:$c}}' \
        | (cd "$cwd" && env -u CLAUDE_PROJECT_DIR bash "$HOOK") \
        | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null
}

assert_denied() {
    local label="$1" cwd="$2" cmd="$3" needle="${4:-}"
    local reason
    reason="$(run_hook "$cwd" "$cmd")"
    if [[ -z "$reason" ]]; then
        echo "  FAIL: $label"
        echo "    expected deny, got allow"
        FAIL=$((FAIL + 1))
        return
    fi
    if [[ -n "$needle" ]] && ! grep -qi -- "$needle" <<<"$reason"; then
        echo "  FAIL: $label"
        echo "    reason missing '$needle': $reason"
        FAIL=$((FAIL + 1))
        return
    fi
    echo "  PASS: $label"
    PASS=$((PASS + 1))
}

assert_allowed() {
    local label="$1" cwd="$2" cmd="$3"
    local reason
    reason="$(run_hook "$cwd" "$cmd")"
    if [[ -n "$reason" ]]; then
        echo "  FAIL: $label"
        echo "    expected allow, got deny: $reason"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    fi
}

P="$TEST_DIR/project"

echo "Gating"
assert_allowed "no .coco anywhere -> allow" "$TEST_DIR/bare" 'cd /tmp && ls'
assert_denied  "project root -> active" "$P" 'cd /tmp && ls' "cd"
assert_denied  "nested pkg dir -> active (walks up)" "$P/pkg" 'cd /tmp && ls' "cd"
assert_denied  "deeply nested dir -> active" "$P/pkg/deep" 'cd /tmp && ls' "cd"

echo ""
echo "Tracker invocation form"
assert_denied "tracker.sh by path" "$P" 'bash ${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh list' "coco-tracker"
assert_denied "tracker.sh absolute path" "$P" 'bash /Users/dave/x/lib/tracker.sh ready' "coco-tracker"
assert_denied "sourced tracker.sh" "$P" 'source lib/tracker.sh' "coco-tracker"
assert_denied "TRACKER var assignment" "$P" 'TRACKER=coco-tracker; $TRACKER list' "variable"

echo ""
echo "Space-separated subcommands"
assert_denied "epic create" "$P" 'coco-tracker epic create "Title"' "hyphenated"
assert_denied "dep add" "$P" 'coco-tracker dep add task-1 --blocks task-2' "hyphenated"
assert_denied "session start" "$P" 'coco-tracker session start "work"' "hyphenated"
assert_allowed "epic-create is fine" "$P" 'coco-tracker epic-create "Title"'
assert_allowed "dep-add is fine" "$P" 'coco-tracker dep-add task-1 --blocks task-2'

echo ""
echo "Tracker call shape"
assert_denied "two tracker calls, semicolon" "$P" 'coco-tracker ready; coco-tracker list' "own Bash tool call"
assert_denied "two tracker calls, &&" "$P" 'coco-tracker ready && coco-tracker list' "own Bash tool call"
assert_denied "multiline tracker command" "$P" 'coco-tracker create --epic e1 --title "Sub-Phase 1
(Cloud)"' "one line"
assert_denied "tracker piped to python" "$P" 'coco-tracker list --json | python3 -c "import sys"' "jq"
assert_allowed "tracker piped to jq" "$P" 'coco-tracker list --json | jq ".[].id"'
assert_allowed "single tracker call" "$P" 'coco-tracker create --epic e1 --title "Setup (Cloud)"'

echo ""
echo "cd compounds"
assert_denied "leading cd &&" "$P" 'cd /Users/dave/Projects/Other/Cadence && cp a b' "cd"
assert_denied "mid-command cd &&" "$P" 'ls; cd /tmp && ls' "cd"
assert_allowed "cd alone" "$P" 'cd /tmp'
assert_allowed "cd with semicolon" "$P" 'cd /tmp; ls'

echo ""
echo "Dropped cosmetic rules (must now be allowed)"
assert_allowed "plain && chaining" "$P" 'uv run pytest -q && echo done'
assert_allowed "|| chaining" "$P" 'make build || make clean'
assert_allowed "command substitution in echo" "$P" 'echo "Branch: $(git branch --show-current)"'
assert_allowed "for loop" "$P" 'for f in *.py; do ruff check "$f"; done'
assert_allowed "multiline heredoc, no tracker" "$P" 'python - <<EOF
print(1)
EOF'
assert_allowed "mutation-test style chain" "$P" 'cp a.py a.py.bak && uv run pytest -q; mv a.py.bak a.py'

echo ""
echo "----------------------------------------"
echo "PASS: $PASS  FAIL: $FAIL"
[[ $FAIL -eq 0 ]]
