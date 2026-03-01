---
name: import
description: Import a tasks.md into the coco tracker as an epic with dependencies, and create matching issues in the configured issue tracker.
---

# Coco Import Skill

Import a tasks.md into the coco tracker and optionally create matching issues in the configured issue tracker.

## When to Use

- Importing tasks as part of the coco pipeline
- Called by `/coco:phase` (Step D) or `/coco:planning-session tactical`
- When tasks.md exists in `specs/{feature}/` and needs to be loaded into the tracker

Prerequisites: `tasks.md` must exist. If missing, use the `tasks` skill first.

## Prerequisites

- Completed `specs/{feature}/tasks.md` with sub-phases and dependency info
- `.coco/config.yaml` exists with project configuration

## Setup

1. Read `.coco/config.yaml` for `project.specs_dir` and `issue_tracker` config.
2. Determine the current feature by:
   - Checking the current git branch name
   - Strip the `feature/` prefix (or whatever `pr.branch.feature_prefix` is) from the branch name
   - Looking for the matching directory in `{specs_dir}/{stripped-name}/`
   - Or from conversation context if a feature was recently discussed
3. Read `{specs_dir}/{feature}/tasks.md` (required). If missing, instruct user to use the `tasks` skill first.
4. Each tracker command is a separate Bash tool call: `bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" <command> [args]`

## Execution

### Step 1: Parse tasks.md

Extract:
1. **Feature name** from the `# Tasks:` header
2. **Sub-Phases** -- each `## Sub-Phase N:` section becomes a tracker task
3. **Parallel markers** -- `[P]` tasks within a sub-phase
4. **Dependencies** -- parse "Dependencies & Execution Order" section

### Step 2: Create Tracker Epic

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" epic-create "{feature-name}"
```

### Step 3: Create Tracker Tasks (one per sub-phase)

**IMPORTANT**: All `bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" create` arguments MUST be single-line. Never put literal newlines inside `--description`, `--title`, or `--metadata` values. Use semicolons or commas to separate items within a description. Put each command on one line (no `\` continuations).

For each sub-phase:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" create --epic "{epic-id}" --title "Sub-Phase {N}: {title}" --description "{single-line summary; task list}" --priority {priority} --metadata '{"sub_phase": N, "issue_key": null, "feature_branch": "{current-branch-name}"}'
```

If tasks.md includes `owns_files` annotations (file ownership per sub-phase), include them in metadata:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" create --epic "{epic-id}" --title "Sub-Phase {N}: {title}" --description "{single-line summary; task list}" --priority {priority} --metadata '{"sub_phase": N, "issue_key": null, "feature_branch": "{current-branch-name}", "owns_files": ["src/auth/**", "tests/auth/**"]}'
```

### Step 4: Set Dependencies

For each dependency (one Bash tool call per dep-add):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" dep-add {phase-1-id} --blocks {phase-2-id}
```
```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" dep-add {phase-2-id} --blocks {phase-3-id}
```

Repeat for all user stories blocking Polish, etc.

### Step 5: Issue Tracker Bridge

Read `.coco/config.yaml` `issue_tracker.provider`:

**If "linear"**:

1. Create project:
   ```
   Use: mcp__plugin_linear_linear__create_project
   Parameters:
     name: "{feature-name}"
     team: {from config issue_tracker.linear.team}
     summary: "{feature description from design.md}"
     labels: {from config issue_tracker.linear.labels}
   ```

2. Create one issue per sub-phase:
   ```
   Use: mcp__plugin_linear_linear__create_issue
   Parameters:
     title: "Sub-Phase {N}: {title}"
     description: "{purpose}\n\n## Tasks\n{checkbox list}"
     team: {from config}
     project: "{project-id}"
     labels: {from config}
   ```

3. Store issue keys in tracker metadata:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" update {task-id} --metadata '{"issue_key": "{ISSUE-KEY}"}'
   ```

**If "github"**:

Read `issue_tracker.github.use_projects` from config (default: `true`).

**If Projects V2 enabled** (`use_projects: true`):

1. Create a GitHub Project for the feature:
   ```bash
   gh project create --owner {github.owner} --title "{feature-name}" --format json
   ```
   Capture the project number from output.

2. Link the project to the repository:
   ```bash
   gh project link {project_number} --owner {github.owner} --repo {github.repo}
   ```

3. Resolve Status field and option IDs:
   ```bash
   gh project field-list {project_number} --owner {github.owner} --format json
   ```
   Find the "Status" field. Extract `field_id` and option IDs for each status value (Todo, In Progress, In Review, Done).

4. Cache project metadata to `.coco/state/gh-projects.json`:
   ```json
   {
     "features": {
       "{feature-name}": {
         "project_number": {N},
         "project_id": "PVT_...",
         "status_field_id": "PVTSSF_...",
         "status_options": {
           "Todo": "opt-id-1", "In Progress": "opt-id-2",
           "In Review": "opt-id-3", "Done": "opt-id-4"
         }
       }
     }
   }
   ```
   Ensure `.coco/state/` directory exists. If `gh-projects.json` already exists, merge into the `features` key.

5. Create issues and add to project. **Run each sub-phase as separate Bash tool calls** (no loops).

   **IMPORTANT `gh issue create` rules:**
   - Use `--body-file - <<'EOF'` for issue bodies (NOT `--body "$(cat <<'EOF'...)"` which triggers permission prompts)
   - Do NOT include `--repo` — `gh` detects the repo automatically when run from within it

   a. Create the issue:
   ```bash
   gh issue create --title "Sub-Phase {N}: {title}" --label {labels} --body-file - <<'EOF'
   {description}
   EOF
   ```

   b. Add issue to project (capture the item ID from output):
   ```bash
   gh project item-add {project_number} --owner {github.owner} --url {issue_url}
   ```

   c. Set initial status to "Todo":
   ```bash
   gh project item-edit --project-id {project_id} --id {item_id} --field-id {status_field_id} --single-select-option-id {status_options["Todo"]}
   ```

   d. Store issue number and project item ID in tracker metadata:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" update {task-id} --metadata '{"issue_key": "#{N}", "gh_project_item_id": "{item_id}", "gh_project_number": {project_number}}'
   ```

   Repeat steps a-d for each sub-phase. Steps a-d for a single sub-phase depend on each other (run sequentially), but separate sub-phases are independent.

**If Projects V2 disabled** (`use_projects: false`):

1. Create issues using `gh`:
   ```bash
   gh issue create --title "Sub-Phase {N}: {title}" --label {labels} --body-file - <<'EOF'
   {description}
   EOF
   ```

2. Store issue numbers in tracker metadata:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" update {task-id} --metadata '{"issue_key": "#{N}"}'
   ```

**If "none"**:

Skip issue creation. Log "Issue tracker bridge skipped."

### Step 6: Verify (GATE)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" epic-status {epic-id}
```
```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" list --json --epic {epic-id}
```

**All must pass:**
- [ ] Every tracker task exists with correct dependencies
- [ ] If issue tracker configured: every task has `issue_key` in metadata
- [ ] Dependencies match sub-phase ordering from tasks.md

### Step 7: Report

Output:
- Epic ID and name
- Number of tasks created
- Dependency graph summary
- Issue tracker project/issues (if applicable)
- First available task: `bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" ready --json --epic {epic-id}`
- Suggested next step (explain both options to the user):
  - **`/coco:execute`** -- Runs **one task at a time**, pausing after each for you to review. Best when you want to stay hands-on, inspect changes between tasks, or are working on something unfamiliar.
  - **`/coco:loop`** -- Runs **all tasks autonomously** in sequence with circuit-breaker protection (stops after repeated failures). Best when you're confident in the design and want to let Claude work through the epic unattended.

## Design-Only Mode (Light Tier)

When `tasks.md` doesn't exist but `design.md` does (light-tier feature):

1. Read the design from `{specs_dir}/{feature}/design.md` (legacy fallback: `spec.md`)
2. Create a single-task epic directly from the design:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" epic-create "{feature-name}"
   ```
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" create --epic "{epic-id}" --title "{feature-name}: {design overview}" --description "{single-line acceptance criteria}" --metadata '{"issue_key": null, "feature_branch": "{current-branch-name}", "light_tier": true}'
   ```
3. No dependencies to set (single task)
4. Run issue tracker bridge (Step 5) as normal -- creates one issue
5. Run verification (Step 6) and report (Step 7) as normal

Design-only mode is triggered by:
- `/coco:planning-session tactical` routing to Light tier
- `/coco:phase` classifying the feature as Light tier
- Explicit request when tasks.md is missing and design.md exists

## Dry Run Mode

If the conversation context indicates a dry run is desired:
1. Print what would be created (tasks, deps, issues)
2. Show dependency graph as ASCII
3. Ask for confirmation before proceeding
