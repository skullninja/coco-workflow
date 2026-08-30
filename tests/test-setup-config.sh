#!/usr/bin/env bash
# Guards the two ways config/coco.default.yaml silently breaks its consumers.
#
# Both failure modes are invisible: the setup wizard accepts your answer and
# writes nothing, or a hook reads a value from the wrong section. Neither
# produces an error, and both have happened.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
CONFIG="$ROOT/config/coco.default.yaml"
SETUP="$ROOT/scripts/setup.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; echo "    $2"; FAIL=$((FAIL + 1)); }

# Each wizard rewrite is: sed -i '' "s<D>LHS<D>RHS<D>". The delimiter varies by
# line (both / and | are in use), so read it off each line rather than assuming.
extract_patterns() {
    local line body d rest
    grep -oE 'sed -i .. "s.*"' "$SETUP" | while IFS= read -r line; do
        body=${line#*\"s}
        d=${body:0:1}
        rest=${body:1}
        printf '%s\n' "${rest%%"$d"*}" | sed -E 's/\\"/"/g'
    done
}

extract_patterns > "$TMP/patterns"
FOUND=$(grep -c . "$TMP/patterns")

echo "Wizard sed patterns must match the shipped config"

# Without this, an extraction bug empties the list and every assertion below
# vanishes -- the suite would pass while testing nothing.
if [ "$FOUND" -ge 8 ]; then
    ok "extracted $FOUND sed patterns from setup.sh"
else
    bad "only extracted $FOUND sed patterns (expected >= 8)" \
        "The extractor is broken, so the assertions below are not running."
fi

# A pattern keyed to a value rather than a stable anchor stops matching the
# moment that default changes; the wizard then accepts the user's answer and
# writes nothing. That is what "s|enabled: false.*# Enable worktree|" did when
# the parallel default flipped to true.
while IFS= read -r lhs; do
    [ -n "$lhs" ] || continue
    if grep -qE -- "$lhs" "$CONFIG"; then
        ok "matches: $lhs"
    else
        bad "matches nothing: $lhs" \
            "scripts/setup.sh would silently write nothing. Anchor on a stable part of the line."
    fi
done < "$TMP/patterns"

echo ""
echo "Keys read by hooks must be leaf-unique"
# The hook config reader is grep -E "^\s*<key>:" | head -1. It matches a leaf key
# anywhere in the file and takes the first hit, ignoring nesting -- so a second
# occurrence under a different parent wins or loses purely by file order.
for key in lint_command typecheck_command auto_fix skip_env_var build_command; do
    n=$(grep -cE "^[[:space:]]*${key}:" "$CONFIG")
    if [ "$n" -eq 1 ]; then
        ok "$key appears once"
    else
        bad "$key appears $n times" \
            "The hook reader takes the first match and ignores nesting. Rename one."
    fi
done

echo ""
echo "----------------------------------------"
echo "PASS: $PASS  FAIL: $FAIL"
[[ $FAIL -eq 0 ]]
