#!/usr/bin/env bash
# coco-workflow setup script
# Creates .coco/ directory structure, registers the plugin with Claude Code,
# walks through key configuration, and installs git hooks.
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

# --- Register plugin with Claude Code ---

PLUGIN_REL_PATH="${COCO_WORKFLOW_ROOT#"$PROJECT_ROOT/"}"
CLAUDE_SETTINGS_DIR="$PROJECT_ROOT/.claude"
CLAUDE_SETTINGS="$CLAUDE_SETTINGS_DIR/settings.json"

mkdir -p "$CLAUDE_SETTINGS_DIR"

# Migrate from old plugin name (coco-workflow -> coco)
if [[ -f "$CLAUDE_SETTINGS" ]]; then
    if jq -e '.enabledPlugins["coco-workflow@coco-local"] // false' "$CLAUDE_SETTINGS" >/dev/null 2>&1; then
        jq 'del(.enabledPlugins["coco-workflow@coco-local"])' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp" && mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"
        echo "  Migrated plugin registration: coco-workflow@coco-local -> coco@coco-local"
    fi
fi

# Check if plugin is already registered
ALREADY_REGISTERED=false
if [[ -f "$CLAUDE_SETTINGS" ]]; then
    if jq -e '.enabledPlugins["coco@coco-local"] // false' "$CLAUDE_SETTINGS" >/dev/null 2>&1; then
        ALREADY_REGISTERED=true
    fi
fi

if [[ "$ALREADY_REGISTERED" == "true" ]]; then
    echo "  Plugin already registered in .claude/settings.json (skipping)"
else
    # Register the coco-workflow submodule as a local marketplace plugin
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        # Merge into existing settings
        jq --arg path "$PLUGIN_REL_PATH" '
            .extraKnownMarketplaces = (.extraKnownMarketplaces // {}) * {
                "coco-local": { "source": { "source": "directory", "path": $path } }
            }
            | .enabledPlugins = (.enabledPlugins // {}) * { "coco@coco-local": true }
        ' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp" && mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"
        echo "  Registered plugin in .claude/settings.json"
    else
        cat > "$CLAUDE_SETTINGS" <<EOF
{
  "extraKnownMarketplaces": {
    "coco-local": {
      "source": { "source": "directory", "path": "$PLUGIN_REL_PATH" }
    }
  },
  "enabledPlugins": {
    "coco@coco-local": true
  }
}
EOF
        echo "  Created .claude/settings.json with plugin registration"
    fi
fi

# --- Create .coco/ directory structure ---

mkdir -p "$COCO_DIR/tasks"
mkdir -p "$COCO_DIR/memory"
mkdir -p "$COCO_DIR/templates"
mkdir -p "$COCO_DIR/state"

# Create discovery phase directories
mkdir -p "$PROJECT_ROOT/docs/analysis"
mkdir -p "$PROJECT_ROOT/docs/roadmap"

# Create empty JSONL files if they don't exist
touch "$COCO_DIR/tasks/tasks.jsonl"
touch "$COCO_DIR/tasks/sessions.jsonl"

# --- Configuration wizard (only for new configs) ---

CONFIG_FILE="$COCO_DIR/config.yaml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    cp "$COCO_WORKFLOW_ROOT/config/coco.default.yaml" "$CONFIG_FILE"
    echo ""
    echo "--- Configuration ---"
    echo ""

    # Helper: prompt with default value
    prompt() {
        local message="$1"
        local default="$2"
        local result
        read -r -p "  $message [$default]: " result
        echo "${result:-$default}"
    }

    # --- Project name ---
    PROJECT_NAME=$(prompt "Project name" "My Project")
    sed -i '' "s/name: \"My Project\"/name: \"$PROJECT_NAME\"/" "$CONFIG_FILE"

    # --- Issue tracker ---
    echo ""
    PROVIDER=$(prompt "Issue tracker (none/github/linear)" "none")
    sed -i '' "s/provider: \"none\"/provider: \"$PROVIDER\"/" "$CONFIG_FILE"

    if [[ "$PROVIDER" == "github" ]]; then
        echo ""
        REPO=$(prompt "GitHub repo (owner/repo, e.g., skullninja/my-app)" "")
        if [[ -n "$REPO" ]]; then
            # Auto-derive owner from repo
            OWNER_DEFAULT="${REPO%%/*}"
            OWNER=$(prompt "GitHub owner for project boards" "$OWNER_DEFAULT")
            USE_PROJECTS=$(prompt "Use GitHub Projects V2? (true/false)" "true")

            sed -i '' "s|repo: \"\"|repo: \"$REPO\"|" "$CONFIG_FILE"
            sed -i '' "s|owner: \"\"|owner: \"$OWNER\"|" "$CONFIG_FILE"
            sed -i '' "s|use_projects: true|use_projects: $USE_PROJECTS|" "$CONFIG_FILE"
        fi
    elif [[ "$PROVIDER" == "linear" ]]; then
        echo ""
        TEAM=$(prompt "Linear team name" "")
        INITIATIVE=$(prompt "Linear initiative (optional, press Enter to skip)" "")

        if [[ -n "$TEAM" ]]; then
            sed -i '' "s|team: \"\"|team: \"$TEAM\"|" "$CONFIG_FILE"
        fi
        if [[ -n "$INITIATIVE" ]]; then
            sed -i '' "s|initiative: \"\"|initiative: \"$INITIATIVE\"|" "$CONFIG_FILE"
        fi
    fi

    # --- Parallel execution ---
    echo ""
    PARALLEL=$(prompt "Enable parallel execution with git worktrees? (true/false)" "false")
    sed -i '' "s|enabled: false.*# Enable worktree|enabled: $PARALLEL                     # Enable worktree|" "$CONFIG_FILE"

    if [[ "$PARALLEL" == "true" ]]; then
        MAX_AGENTS=$(prompt "Max parallel agents" "3")
        sed -i '' "s|max_agents: 3|max_agents: $MAX_AGENTS|" "$CONFIG_FILE"
    fi

    # --- Summary ---
    echo ""
    echo "  Wrote .coco/config.yaml:"
    echo "    project.name: $PROJECT_NAME"
    echo "    issue_tracker.provider: $PROVIDER"
    if [[ "$PROVIDER" == "github" && -n "${REPO:-}" ]]; then
        echo "    github.repo: $REPO"
        echo "    github.owner: ${OWNER:-}"
        echo "    github.use_projects: ${USE_PROJECTS:-true}"
    elif [[ "$PROVIDER" == "linear" && -n "${TEAM:-}" ]]; then
        echo "    linear.team: $TEAM"
        [[ -n "${INITIATIVE:-}" ]] && echo "    linear.initiative: $INITIATIVE"
    fi
    echo "    loop.parallel.enabled: $PARALLEL"
    [[ "$PARALLEL" == "true" ]] && echo "    loop.parallel.max_agents: ${MAX_AGENTS:-3}"
else
    echo "  .coco/config.yaml already exists (skipping configuration)"
fi

# --- Install git hooks ---

if git rev-parse --show-toplevel >/dev/null 2>&1; then
    HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
    mkdir -p "$HOOKS_DIR"

    for hook in commit-msg pre-commit; do
        HOOK_SRC="$COCO_WORKFLOW_ROOT/git-hooks/${hook}.sh"
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

# --- Ensure .claude/worktrees/ is gitignored ---

ROOT_GITIGNORE="$PROJECT_ROOT/.gitignore"
if [[ -f "$ROOT_GITIGNORE" ]]; then
    if ! grep -q '.claude/worktrees/' "$ROOT_GITIGNORE" 2>/dev/null; then
        echo "" >> "$ROOT_GITIGNORE"
        echo "# Claude Code runtime state" >> "$ROOT_GITIGNORE"
        echo ".claude/worktrees/" >> "$ROOT_GITIGNORE"
        echo "  Added .claude/worktrees/ to .gitignore"
    fi
else
    cat > "$ROOT_GITIGNORE" <<'EOF'
# Claude Code runtime state
.claude/worktrees/
EOF
    echo "  Created .gitignore with .claude/worktrees/"
fi

# --- Configure permissions ---

echo "  Configuring permissions in .claude/settings.json..."
PERMS='["Bash(bash:*)", "Bash(mkdir:*)", "Bash(touch:*)", "Bash(cp:*)", "Bash(chmod:*)", "Bash(cat:*)", "Bash(git:*)", "Bash(gh:*)", "Read(~/.claude/plugins/cache/**)"]'

if [[ -f "$CLAUDE_SETTINGS" ]]; then
    jq --argjson perms "$PERMS" '.permissions.allow = ((.permissions.allow // []) + $perms | unique)' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp" && mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"
else
    echo "{\"permissions\":{\"allow\":$PERMS}}" | jq '.' > "$CLAUDE_SETTINGS"
fi
echo "  Permissions configured"

echo ""
echo "Setup complete. Next steps:"
echo "  1. Restart Claude Code to load the Coco plugin"
echo "  2. Run /coco:constitution to set up project principles"
echo "  3. For new projects: /coco:prd to create a Product Requirements Document"
echo "  4. For existing projects: /coco:prd audit to generate a PRD from your codebase"
echo ""
echo "Note: If you installed Coco from the marketplace, you can use /coco:setup instead"
echo "of this script. Both produce the same result."
