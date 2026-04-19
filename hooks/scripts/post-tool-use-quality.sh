#!/usr/bin/env bash
# coco-workflow PostToolUse quality hook
# Runs lint/typecheck against the modified file per .coco/config.yaml.
# Silent exit if config missing, quality commands unset, or file excluded.
# Never blocks — always exits 0.
set -u

CONFIG_FILE=".coco/config.yaml"

[ -f "$CONFIG_FILE" ] || exit 0

INPUT="$(cat)"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$FILE_PATH" ] || exit 0

_yaml_value() {
    local key="$1"
    grep -E "^\s*${key}:" "$CONFIG_FILE" 2>/dev/null \
        | head -1 \
        | sed "s/.*${key}:[[:space:]]*//" \
        | sed 's/[[:space:]]*#.*//' \
        | tr -d '"' \
        | tr -d "'"
}

LINT_CMD="$(_yaml_value lint_command)"
TYPECHECK_CMD="$(_yaml_value typecheck_command)"
AUTO_FIX="$(_yaml_value auto_fix)"

[ -n "$LINT_CMD" ] || [ -n "$TYPECHECK_CMD" ] || exit 0

if [ -n "$LINT_CMD" ]; then
    CMD="${LINT_CMD//\{file\}/$FILE_PATH}"
    if ! eval "$CMD" 2>&1; then
        if [ "$AUTO_FIX" = "true" ]; then
            eval "$CMD --fix $FILE_PATH" 2>&1 || true
        fi
    fi
fi

if [ -n "$TYPECHECK_CMD" ]; then
    CMD="${TYPECHECK_CMD//\{file\}/$FILE_PATH}"
    eval "$CMD" 2>&1 || true
fi

exit 0
