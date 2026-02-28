---
argument-hint: ["reset"]
description: Initialize Coco in the current project. Creates .coco/ directory, config, git hooks, and permissions. Use "reset" to force reconfiguration.
allowed-tools: AskUserQuestion, Read, Write, Edit, Bash, Glob, Grep
---

## User Input

```text
$ARGUMENTS
```

## Step 0: Idempotency Check

Check if `.coco/config.yaml` already exists.

- If it exists AND `$ARGUMENTS` does NOT contain "reset":
  - Output: "Coco is already initialized in this project."
  - Use `AskUserQuestion`:
    - **Question**: "What would you like to do?"
    - **Options**:
      - "Reconfigure" -- Re-run the config wizard (overwrites `.coco/config.yaml`)
      - "Reinstall hooks" -- Reinstall git hooks only
      - "Skip" -- Do nothing
  - If "Skip": output "No changes made." and stop.
  - If "Reinstall hooks": jump to Step 4 (Git Hooks).
  - If "Reconfigure": continue from Step 2.
- If `$ARGUMENTS` contains "reset": continue from Step 1 (recreates everything).
- If `.coco/config.yaml` does NOT exist: continue from Step 1.

## Step 1: Create Directory Structure

Run these as separate Bash commands:

```bash
mkdir -p .coco/tasks .coco/memory .coco/templates .coco/state
```

```bash
mkdir -p docs/analysis docs/roadmap
```

Create empty JSONL files if they don't exist:

```bash
touch .coco/tasks/tasks.jsonl .coco/tasks/sessions.jsonl
```

## Step 2: Config Template

Copy the default config:

```bash
cp "${CLAUDE_PLUGIN_ROOT}/config/coco.default.yaml" .coco/config.yaml
```

## Step 3: Config Wizard

Use `AskUserQuestion` for each setting. After each answer, use the `Edit` tool to update `.coco/config.yaml`.

### 3a. Project Name

Use `AskUserQuestion`:
- **Question**: "What is the project name?"
- **Options**:
  - The basename of the current working directory (auto-detected)
  - "My Project" (default)

Edit `.coco/config.yaml`: change `name: "My Project"` to the chosen name.

### 3b. Issue Tracker

Use `AskUserQuestion`:
- **Question**: "Which issue tracker do you use?"
- **Options**:
  - "None" -- Tracker-only, no external sync
  - "GitHub Issues" -- Sync with GitHub Issues (requires `gh` CLI)
  - "Linear" -- Sync with Linear (requires Linear MCP plugin)

Edit `.coco/config.yaml`: change `provider: "none"` to the chosen provider (`none`, `github`, or `linear`).

**If GitHub**:
- Use `AskUserQuestion`: "What is the GitHub repo? (owner/repo format, e.g., skullninja/my-app)"
- Edit config: set `github.repo` and auto-derive `github.owner` from the repo string.
- Use `AskUserQuestion`: "Use GitHub Projects V2 for board-based status tracking?"
  - "Yes (Recommended)" -- Creates project boards per feature with status columns
  - "No" -- Use label-based tracking instead
- Edit config: set `github.use_projects`.

**If Linear**:
- Use `AskUserQuestion`: "What is your Linear team name?"
- Edit config: set `linear.team`.
- Use `AskUserQuestion`: "Link to a Linear initiative? (optional, enter name or skip)"
  - "Skip" -- No initiative
- Edit config: set `linear.initiative` if provided.

### 3c. Parallel Execution

Use `AskUserQuestion`:
- **Question**: "Enable parallel execution with git worktrees?"
- **Options**:
  - "No (Recommended)" -- Sequential task execution
  - "Yes" -- Parallel execution with isolated git worktrees

If "Yes":
- Use `AskUserQuestion`: "Max parallel agents?"
  - "3 (Recommended)"
  - "2"
  - "4"
- Edit config: set `loop.parallel.enabled: true` and `loop.parallel.max_agents`.

## Step 4: Git Hooks

Check if this is a git repository:

```bash
git rev-parse --show-toplevel
```

If it is a git repo, install hooks. For each hook (`commit-msg`, `pre-commit`):

1. Check if `.git/hooks/{hook}` exists and already contains "coco-workflow":
   - If yes: skip (already installed).
2. If the hook file exists but does NOT contain "coco-workflow":
   - Append to the existing hook:
   ```bash
   echo "" >> .git/hooks/{hook}
   echo "# --- coco-workflow hook ---" >> .git/hooks/{hook}
   cat "${CLAUDE_PLUGIN_ROOT}/git-hooks/{hook}.sh" >> .git/hooks/{hook}
   ```
3. If the hook file does not exist:
   ```bash
   cp "${CLAUDE_PLUGIN_ROOT}/git-hooks/{hook}.sh" .git/hooks/{hook}
   chmod +x .git/hooks/{hook}
   ```

## Step 5: Gitignore

### .coco/.gitignore

If `.coco/.gitignore` does not exist, create it:

```
# Ignore runtime state
state/
# Track task data and config
!tasks/
!config.yaml
!memory/
!templates/
```

### Root .gitignore

Check if `.gitignore` exists and contains `.claude/worktrees/`. If not, append:

```
# Claude Code runtime state
.claude/worktrees/
```

## Step 6: Permissions

Merge Coco's required permissions into `.claude/settings.json` so commands run without repeated prompts.

Read `.claude/settings.json` (create if it doesn't exist). Use jq to merge these permissions into the `permissions.allow` array (avoid duplicates):

```bash
jq '. + {"permissions": {"allow": ((.permissions.allow // []) + ["Bash(source:*)", "Bash(mkdir:*)", "Bash(touch:*)", "Bash(cp:*)", "Bash(chmod:*)", "Bash(cat:*)", "Bash(git:*)", "Bash(gh:*)", "Read(~/.claude/plugins/cache/**)"] | unique)}}' .claude/settings.json > .claude/settings.json.tmp && mv .claude/settings.json.tmp .claude/settings.json
```

If `.claude/settings.json` does not exist yet, create it with just the permissions block.

## Step 7: Report

Output a summary:

```
Coco setup complete!

  Created:    .coco/ directory structure
  Config:     .coco/config.yaml
  Git hooks:  commit-msg, pre-commit
  Gitignore:  .coco/.gitignore, .claude/worktrees/
  Permissions: .claude/settings.json

Next steps:
  1. Run /coco:constitution to set up project principles
  2. For new projects: /coco:prd to create a Product Requirements Document
  3. For existing projects: /coco:prd audit to generate a PRD from your codebase
```

## Notes

- This command replaces `scripts/setup.sh` for marketplace users. Both produce the same result.
- The config wizard uses `AskUserQuestion` instead of shell `read -p` for better UX.
- The command is idempotent -- safe to run multiple times.
- Use `/coco:setup reset` to force full reconfiguration.
