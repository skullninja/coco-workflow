#!/usr/bin/env bash
# coco-workflow commit-msg hook
# Validates commit message format based on .coco/config.yaml settings.
#
# Reads config for:
#   commit.exempt_patterns - regex patterns that bypass issue key check
#   commit.title_format    - expected format (used for error messages)
set -euo pipefail

COMMIT_MSG_FILE="$1"
FIRST_LINE=$(head -n 1 "$COMMIT_MSG_FILE")
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_FILE="$PROJECT_ROOT/.coco/config.yaml"

# If no config file, pass through (coco-workflow not set up)
if [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi

# Parse exempt patterns from config (simple grep-based YAML parsing)
# Looks for lines under commit.exempt_patterns that start with "- "
exempt_patterns=()
in_exempt=false
while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*exempt_patterns: ]]; then
        in_exempt=true
        continue
    fi
    if [[ "$in_exempt" == true ]]; then
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*\"(.+)\" ]]; then
            exempt_patterns+=("${BASH_REMATCH[1]}")
        elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*\'(.+)\' ]]; then
            exempt_patterns+=("${BASH_REMATCH[1]}")
        elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.+) ]]; then
            exempt_patterns+=("${BASH_REMATCH[1]}")
        else
            in_exempt=false
        fi
    fi
done < "$CONFIG_FILE"

# Check if commit message matches any exempt pattern
for pattern in "${exempt_patterns[@]}"; do
    if echo "$FIRST_LINE" | grep -qiE "$pattern"; then
        exit 0
    fi
done

# Allow Co-Authored-By only commits
if echo "$FIRST_LINE" | grep -qiE '^co-authored-by:'; then
    exit 0
fi

# If an issue key pattern is present, validate the format
# Detect issue key patterns: SKU-N, PROJ-N, #N, GH-N, etc.
if echo "$FIRST_LINE" | grep -qE '[A-Z]+-[0-9]+'; then
    # Allow "Completes KEY" (implementation commits) and "Ref KEY" (review-fix commits)
    if ! echo "$FIRST_LINE" | grep -qE '(Completes|Ref) [A-Z]+-[0-9]+$'; then
        echo "ERROR: Issue key found but not in correct format."
        echo ""
        echo "  The first line must END with 'Completes ISSUE-KEY' or 'Ref ISSUE-KEY'"
        echo "  Current: $FIRST_LINE"
        echo ""
        echo "  Examples:"
        echo "    Brief description of changes. Completes PROJ-5"
        echo "    Address review feedback (iteration 1). Ref PROJ-5"
        exit 1
    fi
fi

# Reject old bracket format [ISSUE-KEY]
if echo "$FIRST_LINE" | grep -qE '^\[[A-Z]+-[0-9]+\]'; then
    echo "ERROR: Wrong commit format. Bracket format [KEY] is deprecated."
    echo ""
    echo "  Wrong:   [PROJ-5] Setup infrastructure"
    echo "  Correct: Setup infrastructure. Completes PROJ-5"
    exit 1
fi

exit 0
