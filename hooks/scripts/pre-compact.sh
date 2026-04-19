#!/usr/bin/env bash
# coco-workflow PreCompact hook
# Captures tracker state to .coco/state/session-memory.md before compaction.
# Silent exit if .coco/config.yaml is missing. Never blocks.
set -u

CONFIG_FILE=".coco/config.yaml"
STATE_DIR=".coco/state"
MEMORY_FILE="$STATE_DIR/session-memory.md"

[ -f "$CONFIG_FILE" ] || exit 0
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0
[ -f "$CLAUDE_PLUGIN_ROOT/lib/tracker.sh" ] || exit 0

mkdir -p "$STATE_DIR"

BRANCH="$(git branch --show-current 2>/dev/null || echo 'unknown')"
TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
ALL_JSON="$(bash "$CLAUDE_PLUGIN_ROOT/lib/tracker.sh" list --json 2>/dev/null || echo '[]')"
READY_JSON="$(bash "$CLAUDE_PLUGIN_ROOT/lib/tracker.sh" ready --json 2>/dev/null || echo 'null')"

{
    echo "# Coco Session Memory"
    echo ""
    echo "**Captured**: $TIMESTAMP"
    echo "**Branch**: $BRANCH"
    echo ""
    echo "## Active Epics"
    echo ""
    echo "| Epic ID | Title | Status |"
    echo "|---------|-------|--------|"
    echo "$ALL_JSON" | jq -r '.[] | select(.type == "epic" and .status != "completed") | "| \(.id) | \(.title) | \(.status) |"' 2>/dev/null || true
    echo ""
    echo "## In-Progress Tasks"
    echo ""
    echo "| Task ID | Epic | Title | Issue Key |"
    echo "|---------|------|-------|-----------|"
    echo "$ALL_JSON" | jq -r '.[] | select(.type == "task" and .status == "in_progress") | "| \(.id) | \(.epic_id // "-") | \(.title) | \(.metadata.issue_key // "-") |"' 2>/dev/null || true
    echo ""
    echo "## Next Ready Task"
    echo ""
    if [ "$READY_JSON" != "null" ] && [ -n "$READY_JSON" ]; then
        echo "$READY_JSON" | jq -r '"- **\(.id)**: \(.title)"' 2>/dev/null || echo "- (none)"
    else
        echo "- (none)"
    fi
} > "$MEMORY_FILE"

exit 0
