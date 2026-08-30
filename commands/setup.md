---
argument-hint: ["reset" | "migrate"]
description: Initialize Coco in the current project. Creates .coco/ directory, config, git hooks, and permissions. Use "reset" to force reconfiguration, or "migrate" to reconcile an existing config against the current defaults.
allowed-tools: AskUserQuestion, Read, Write, Edit, Bash, Glob, Grep
---

## User Input

```text
$ARGUMENTS
```

## Migrate Mode

If `$ARGUMENTS` contains "migrate", run **only** this section and stop. Do not
touch git hooks, gitignore, or permissions.

`.coco/config.yaml` is copied from `config/coco.default.yaml` once, at setup, and
never consulted again. A project set up months ago keeps whatever the defaults
were that day -- including defaults that have since been reversed because they
were wrong. Migrate is how that gets reconciled without discarding deliberate
choices.

**1. Read both files.**

```bash
cat .coco/config.yaml
```
```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/coco.default.yaml"
```

**2. Add keys the project is missing.** For every key present in the default and
absent from the project config, insert it with the default value and its comment,
in the same section and position. This is safe and needs no confirmation -- an
absent key already behaves as its default, so writing it changes nothing except
making it visible and editable.

**3. Report keys whose values differ. Do not change them.** A differing value is
usually a deliberate choice, and silently reverting it would be worse than the
drift. Present them as a table:

| Key | Yours | Current default | Why the default changed |
|-----|-------|-----------------|-------------------------|
| `loop.pause_on_error` | `true` | `false` | Pausing on the first failure turns a flaky test into a full stop needing a human |
| `loop.parallel.enabled` | `false` | `true` | Worktree isolation is proven; serial execution is the slow path |

Only include a `Why` for keys whose default actually changed in a release. For a
key that merely differs because the user set it, leave that cell `--`.

**4. Offer to apply.** Use `AskUserQuestion` listing each differing key that has a
changed default, and apply only what the user selects. Never apply in bulk without
asking, and never touch a key the user set to a non-default value that was not
itself a changed default.

**5. Report** what was added, what was changed, and what was left alone.

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
- If `$ARGUMENTS` contains "migrate": Migrate Mode above already handled it; stop.
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
  - "Yes (Recommended)" -- Parallel execution with isolated git worktrees
  - "No" -- Sequential task execution, one task at a time

If "Yes":
- Use `AskUserQuestion`: "Max parallel agents?"
  - "3 (Recommended)"
  - "2"
  - "4"
- Edit config: set `loop.parallel.enabled: true` and `loop.parallel.max_agents`.

If "No": set `loop.parallel.enabled: false`.

Parallel needs `owns_files` metadata on tasks to find non-overlapping work; when
it is missing, `/coco:loop` falls back to serial and says so. Enabling it costs
nothing when it cannot apply.

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
   ```
   ```bash
   echo "# --- coco-workflow hook ---" >> .git/hooks/{hook}
   ```
   ```bash
   cat "${CLAUDE_PLUGIN_ROOT}/git-hooks/{hook}.sh" >> .git/hooks/{hook}
   ```
3. If the hook file does not exist:
   ```bash
   cp "${CLAUDE_PLUGIN_ROOT}/git-hooks/{hook}.sh" .git/hooks/{hook}
   ```
   ```bash
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

Use the Read tool to read `.claude/settings.json` (if it exists). Merge these permissions into the `permissions.allow` array (dedup with existing entries), then use the Write tool to save:

```json
["Bash(bash:*)", "Bash(mkdir:*)", "Bash(touch:*)", "Bash(cp:*)", "Bash(chmod:*)", "Bash(cat:*)", "Bash(git:*)", "Bash(gh:*)", "Read(~/.claude/plugins/cache/**)"]
```

If `.claude/settings.json` does not exist yet, create it with just the permissions block. Use the Read/Write tools (not bash) to avoid permission prompts on this step.

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
