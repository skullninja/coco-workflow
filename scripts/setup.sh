#!/usr/bin/env bash
# coco-workflow setup script
# Creates .coco/ directory structure and installs git hooks.
# Idempotent -- safe to run multiple times.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COCO_WORKFLOW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Find project root (git root or current directory)
if git rev-parse --show-toplevel >/dev/null 2>&1; then
    PROJECT_ROOT="$(git rev-parse --show-toplevel)"
else
    PROJECT_ROOT="$PWD"
fi

COCO_DIR="$PROJECT_ROOT/.coco"

echo "coco-workflow setup"
echo "  Project root: $PROJECT_ROOT"
echo "  Plugin root:  $COCO_WORKFLOW_ROOT"
echo ""

# --- Create .coco/ directory structure ---

mkdir -p "$COCO_DIR/tasks"
mkdir -p "$COCO_DIR/memory"
mkdir -p "$COCO_DIR/templates"
mkdir -p "$COCO_DIR/state"

# Create discovery phase directories
mkdir -p "$PROJECT_ROOT/docs/analysis"
mkdir -p "$PROJECT_ROOT/docs/roadmap"

# Copy default config if none exists
if [[ ! -f "$COCO_DIR/config.yaml" ]]; then
    cp "$COCO_WORKFLOW_ROOT/config/coco.default.yaml" "$COCO_DIR/config.yaml"
    echo "  Created .coco/config.yaml (edit to configure your project)"
else
    echo "  .coco/config.yaml already exists (skipping)"
fi

# Create empty JSONL files if they don't exist
touch "$COCO_DIR/tasks/tasks.jsonl"
touch "$COCO_DIR/tasks/sessions.jsonl"

# --- Install git hooks ---

if git rev-parse --show-toplevel >/dev/null 2>&1; then
    HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
    mkdir -p "$HOOKS_DIR"

    for hook in commit-msg pre-commit; do
        HOOK_SRC="$COCO_WORKFLOW_ROOT/hooks/${hook}.sh"
        HOOK_DST="$HOOKS_DIR/$hook"

        if [[ ! -f "$HOOK_SRC" ]]; then
            continue
        fi

        if [[ -f "$HOOK_DST" ]]; then
            # Check if it's already our hook
            if grep -q "coco-workflow" "$HOOK_DST" 2>/dev/null; then
                echo "  Git hook $hook already installed (skipping)"
                continue
            fi
            # Existing hook from another source -- append ours
            echo "" >> "$HOOK_DST"
            echo "# --- coco-workflow hook ---" >> "$HOOK_DST"
            cat "$HOOK_SRC" >> "$HOOK_DST"
            echo "  Git hook $hook appended to existing hook"
        else
            cp "$HOOK_SRC" "$HOOK_DST"
            chmod +x "$HOOK_DST"
            echo "  Git hook $hook installed"
        fi
    done
else
    echo "  Not a git repository -- skipping hook installation"
fi

# --- Create .gitignore for .coco/ ---

GITIGNORE="$COCO_DIR/.gitignore"
if [[ ! -f "$GITIGNORE" ]]; then
    cat > "$GITIGNORE" <<'EOF'
# Ignore runtime state
state/
# Track task data and config
!tasks/
!config.yaml
!memory/
!templates/
EOF
    echo "  Created .coco/.gitignore"
fi

echo ""
echo "Setup complete. Next steps:"
echo "  1. Edit .coco/config.yaml to configure your project"
echo "  2. Run /coco.constitution to set up project principles"
echo "  3. Start with /interview or /coco.spec to create your first feature spec"
