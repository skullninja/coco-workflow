#!/usr/bin/env bash
# Test suite for the shared hook gating library (hooks/scripts/coco-lib.sh).
#
# Every coco hook begins by resolving the project root and exits silently when
# that fails. If this resolution breaks, the failure is invisible in both
# directions: hooks stop firing inside real projects, or start firing in
# unrelated ones. Neither produces an error anyone would notice.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/../hooks/scripts/coco-lib.sh"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# A coco-initialized project, plus a nested package dir with no .coco of its
# own -- the shape hooks actually see under a monorepo package or a
# parallel-execution worktree.
mkdir -p "$TEST_DIR/project/.coco"
touch "$TEST_DIR/project/.coco/config.yaml"
mkdir -p "$TEST_DIR/project/pkg/deep"
mkdir -p "$TEST_DIR/bare/nested"

P="$(cd "$TEST_DIR/project" && pwd -P)"

PASS=0
FAIL=0

# resolve <cwd> <hint> [CLAUDE_PROJECT_DIR]
# Runs coco_project_root the way a hook does: sourced, from a given cwd, with
# the environment a hook would see. Prints the resolved root, or empty.
resolve() {
    local cwd="$1" hint="$2" projdir="${3:-}"
    (
        cd "$cwd" 2>/dev/null || exit 1
        if [ -n "$projdir" ]; then
            export CLAUDE_PROJECT_DIR="$projdir"
        else
            unset CLAUDE_PROJECT_DIR
        fi
        # shellcheck source=../hooks/scripts/coco-lib.sh
        . "$LIB"
        coco_project_root "$hint" 2>/dev/null
    )
}

assert_root() {
    local label="$1" expected="$2" got="$3"
    if [[ "$got" == "$expected" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: $expected"
        echo "    got:      ${got:-<empty>}"
        FAIL=$((FAIL + 1))
    fi
}

assert_unresolved() {
    local label="$1" got="$2"
    if [[ -z "$got" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected no root, got: $got"
        FAIL=$((FAIL + 1))
    fi
}

echo "Upward walk from the cwd hint"
assert_root "project root resolves to itself" "$P" "$(resolve "$P" "$P")"
assert_root "nested package dir walks up" "$P" "$(resolve "$P/pkg" "$P/pkg")"
assert_root "deeply nested dir walks up" "$P" "$(resolve "$P/pkg/deep" "$P/pkg/deep")"

echo ""
echo "Gating: no .coco anywhere up the tree"
assert_unresolved "bare dir is not a coco project" "$(resolve "$TEST_DIR/bare" "$TEST_DIR/bare")"
assert_unresolved "nested bare dir is not either" "$(resolve "$TEST_DIR/bare/nested" "$TEST_DIR/bare/nested")"

echo ""
echo "Fallback chain: hint -> CLAUDE_PROJECT_DIR -> PWD"
assert_root "empty hint falls back to CLAUDE_PROJECT_DIR" "$P" "$(resolve "$TEST_DIR/bare" "" "$P")"
assert_root "empty hint and no env falls back to PWD" "$P" "$(resolve "$P/pkg" "")"
# A hook can be handed a cwd that no longer exists -- /coco:loop prunes the
# worktrees its agents ran in. The hint must be skipped, not fatal.
assert_root "vanished hint dir falls through to env" "$P" "$(resolve "$TEST_DIR/bare" "$TEST_DIR/gone" "$P")"
assert_unresolved "vanished hint with no fallback" "$(resolve "$TEST_DIR/bare" "$TEST_DIR/gone")"

echo ""
echo "----------------------------------------"
echo "PASS: $PASS  FAIL: $FAIL"
[[ $FAIL -eq 0 ]]
