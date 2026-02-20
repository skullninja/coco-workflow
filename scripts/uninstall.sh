#!/usr/bin/env bash
# coco-workflow uninstall script
# Removes git hooks installed by setup.sh.
# Does NOT remove .coco/ directory (preserves task state and config).
set -euo pipefail

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "Not a git repository. Nothing to uninstall."
    exit 0
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "coco-workflow uninstall"

for hook in commit-msg pre-commit; do
    HOOK_FILE="$HOOKS_DIR/$hook"
    if [[ ! -f "$HOOK_FILE" ]]; then
        continue
    fi

    if grep -q "coco-workflow" "$HOOK_FILE" 2>/dev/null; then
        # Check if the entire file is ours or if we appended to an existing hook
        if head -1 "$HOOK_FILE" | grep -q "coco-workflow" 2>/dev/null; then
            rm "$HOOK_FILE"
            echo "  Removed git hook: $hook"
        else
            # Remove our appended section
            sed -i.bak '/# --- coco-workflow hook ---/,$d' "$HOOK_FILE"
            rm -f "${HOOK_FILE}.bak"
            echo "  Removed coco-workflow section from git hook: $hook"
        fi
    fi
done

echo ""
echo "Uninstall complete."
echo "Note: .coco/ directory was preserved. Remove it manually if desired."
