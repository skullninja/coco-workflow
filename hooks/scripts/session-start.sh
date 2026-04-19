#!/usr/bin/env bash
# coco-workflow SessionStart hook
# Prints first-run message or restores session context from memory file.
# Never blocks. Exits 0.
set -u

CONFIG_FILE=".coco/config.yaml"
MEMORY_FILE=".coco/state/session-memory.md"

if [ ! -f "$CONFIG_FILE" ]; then
    if [ -d ".coco" ] || [ -d ".git" ]; then
        echo "Coco plugin detected but not initialized. Run /coco:setup to get started."
    fi
    exit 0
fi

[ -f "$MEMORY_FILE" ] || exit 0

echo "Resuming coco-workflow context from $MEMORY_FILE:"
echo ""
cat "$MEMORY_FILE"

exit 0
