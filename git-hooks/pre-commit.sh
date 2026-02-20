#!/usr/bin/env bash
# coco-workflow pre-commit hook
# Reads .coco/config.yaml for build command and UI change patterns.
#
# 1. Runs build command as a fail-fast compile check (skippable via env var)
# 2. Detects UI file changes and sets a flag for pre-commit-tester
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_FILE="$PROJECT_ROOT/.coco/config.yaml"
FLAG_FILE="$PROJECT_ROOT/.coco/state/ui-changes-pending"

# If no config file, pass through
if [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi

# Parse skip env var name from config (default: COCO_QUICK_COMMIT)
SKIP_VAR="COCO_QUICK_COMMIT"
skip_line=$(grep -E '^\s*skip_env_var:' "$CONFIG_FILE" 2>/dev/null || true)
if [[ -n "$skip_line" ]]; then
    SKIP_VAR=$(echo "$skip_line" | sed 's/.*skip_env_var:[[:space:]]*//' | tr -d '"' | tr -d "'" | tr -d '[:space:]')
fi

# Parse build command from config
BUILD_CMD=""
build_line=$(grep -E '^\s*build_command:' "$CONFIG_FILE" 2>/dev/null || true)
if [[ -n "$build_line" ]]; then
    BUILD_CMD=$(echo "$build_line" | sed 's/.*build_command:[[:space:]]*//' | tr -d '"' | tr -d "'")
fi

# Run build check (unless skipped)
if [[ -n "$BUILD_CMD" ]]; then
    if [[ "${!SKIP_VAR:-0}" == "1" ]]; then
        echo "[pre-commit] Quick mode: skipping build check"
    else
        echo "[pre-commit] Running build check..."
        if ! eval "$BUILD_CMD" 2>&1 | tail -5; then
            echo ""
            echo "ERROR: Build failed. Fix compilation errors before committing."
            echo "Tip: Set ${SKIP_VAR}=1 to skip build check for non-code changes."
            exit 1
        fi
        echo "[pre-commit] Build check passed."
    fi
fi

# Parse UI patterns from config
ui_patterns=()
in_ui_patterns=false
while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*ui_patterns: ]]; then
        in_ui_patterns=true
        continue
    fi
    if [[ "$in_ui_patterns" == true ]]; then
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*\"(.+)\" ]]; then
            ui_patterns+=("${BASH_REMATCH[1]}")
        elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*\'(.+)\' ]]; then
            ui_patterns+=("${BASH_REMATCH[1]}")
        elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.+) ]]; then
            ui_patterns+=("${BASH_REMATCH[1]}")
        else
            in_ui_patterns=false
        fi
    fi
done < "$CONFIG_FILE"

# Detect UI file changes
if [[ ${#ui_patterns[@]} -gt 0 ]]; then
    STAGED_FILES=$(git diff --cached --name-only)
    UI_CHANGES=false

    for pattern in "${ui_patterns[@]}"; do
        # Convert glob patterns to regex
        regex=$(echo "$pattern" | sed 's/\*\*/.*/' | sed 's/\*/.*/g')
        if echo "$STAGED_FILES" | grep -qE "$regex"; then
            UI_CHANGES=true
            break
        fi
    done

    if [[ "$UI_CHANGES" == true ]]; then
        mkdir -p "$(dirname "$FLAG_FILE")"
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$FLAG_FILE"
        echo "[pre-commit] UI changes detected. Flag set for pre-commit-tester."
    else
        rm -f "$FLAG_FILE"
    fi
fi

exit 0
