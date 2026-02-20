---
name: coco-import
description: Import a coco-workflow tasks.md into the coco tracker as an epic with dependencies, and create matching issues in the configured issue tracker.
---

# Coco Import Skill

Import a tasks.md into the coco tracker and optionally create matching issues in the configured issue tracker.

## When to Use

- Importing tasks as part of the coco-workflow pipeline
- Called by `/coco.phase` (Step D) or `/planning-session tactical`
- When tasks.md exists in `specs/{feature}/` and needs to be loaded into the tracker

Prerequisites: `tasks.md` must exist. If missing, use the `coco-tasks` skill first.

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
3. Read `{specs_dir}/{feature}/tasks.md` (required). If missing, instruct user to use the `coco-tasks` skill first.
4. Source `${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh` for tracker operations.

## Execution

### Step 1: Parse tasks.md

Extract:
1. **Feature name** from the `# Tasks:` header
2. **Sub-Phases** -- each `## Sub-Phase N:` section becomes a tracker task
3. **Parallel markers** -- `[P]` tasks within a sub-phase
4. **Dependencies** -- parse "Dependencies & Execution Order" section

### Step 2: Create Tracker Epic

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"
coco_tracker epic-create "{feature-name}"
```

### Step 3: Create Tracker Tasks (one per sub-phase)

For each sub-phase:

```bash
coco_tracker create --epic "{epic-id}" \
  --title "Sub-Phase {N}: {title}" \
  --description "{sub-phase purpose + task list}" \
  --priority {priority} \
  --metadata '{"sub_phase": N, "issue_key": null, "feature_branch": "{current-branch-name}"}'
```

### Step 4: Set Dependencies

```bash
# Setup blocks Foundational
coco_tracker dep-add {phase-1-id} --blocks {phase-2-id}

# Foundational blocks all user stories
coco_tracker dep-add {phase-2-id} --blocks {phase-3-id}
# ... etc

# All user stories block Polish
coco_tracker dep-add {phase-3-id} --blocks {polish-id}
# ... etc
```

### Step 5: Issue Tracker Bridge

Read `.coco/config.yaml` `issue_tracker.provider`:

**If "linear"**:

1. Create project:
   ```
   Use: mcp__plugin_linear_linear__create_project
   Parameters:
     name: "{feature-name}"
     team: {from config issue_tracker.linear.team}
     summary: "{feature description from spec.md}"
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
   coco_tracker update {task-id} --metadata '{"issue_key": "{ISSUE-KEY}"}'
   ```

**If "github"**:

1. Create issues using `gh`:
   ```bash
   gh issue create --title "Sub-Phase {N}: {title}" --body "{description}" --label {labels}
   ```

2. Store issue numbers in tracker metadata:
   ```bash
   coco_tracker update {task-id} --metadata '{"issue_key": "#{N}"}'
   ```

**If "none"**:

Skip issue creation. Log "Issue tracker bridge skipped."

### Step 6: Verify (GATE)

```bash
coco_tracker epic-status {epic-id}
coco_tracker list --json --epic {epic-id}
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
- First available task: `coco_tracker ready --json --epic {epic-id}`
- Suggested next step: `/coco.execute` or `/coco.loop`

## Dry Run Mode

If the conversation context indicates a dry run is desired:
1. Print what would be created (tasks, deps, issues)
2. Show dependency graph as ASCII
3. Ask for confirmation before proceeding
