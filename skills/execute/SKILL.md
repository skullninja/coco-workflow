---
name: coco-execute
description: Execute the next available tracked task with TDD, pre-commit validation, and issue tracker bridge sync. Primary execution interface for multi-session feature work.
---

# Coco Execute Skill

Primary execution interface for spec-driven features. Manages dependency-aware task selection, TDD implementation, and issue tracker synchronization across sessions.

## When to Use

- Implementing a feature that has been imported into the coco tracker as an epic
- Executing tasks from a `specs/{feature}/tasks.md` that has been converted to tracked tasks
- Any multi-session work where dependency tracking matters

For single-issue hotfixes or quick changes, use the `hotfix` skill instead.

## Pre-Execution Gate (MANDATORY)

Before starting the execution loop, verify the epic was imported correctly:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"
coco_tracker epic-status {epic-id}
```

**Check ALL of the following before writing any code:**

1. **Tracker tasks exist** with correct dependencies
2. **If issue tracker configured**: every task has `issue_key` in metadata (check `.coco/config.yaml` for `issue_tracker.provider`)
3. **Commit message issue keys are real** -- keys must reference actual issues, not invented numbers

**If any check fails:** Do NOT proceed. Run `/coco.import` first.

## Execution Loop

### 1. Find Next Task

```bash
coco_tracker ready --json --epic {epic-id}
```

This returns the next unblocked task respecting dependency order. Never manually pick tasks -- always use `ready`.

### 2. Claim Task

```bash
coco_tracker update {task-id} --status in_progress
```

### 3. Bridge to Issue Tracker (REQUIRED if configured)

Read `issue_key` from task metadata. Read `.coco/config.yaml` for `issue_tracker.provider`:

**If "linear"**: `mcp__plugin_linear_linear__update_issue` with state from `status_map.in_progress`
**If "github"**: `gh issue edit {number} --add-label in-progress`
**If "none"**: Skip

If `issue_key` is missing and provider is not "none", STOP and fix metadata.

### 4. TDD Implementation

Follow the TDD cycle for each task group within the sub-phase:

**a. Write Tests First**
- Create test files for the sub-phase's functionality
- Verify tests fail without implementation (RED)

**b. Implement Code**
- Write implementation to make tests pass (GREEN)
- Follow existing patterns in the codebase

**c. Verify**
- Run test suite (use `testing.test_command` from config, or auto-detect)
- All tests must pass before proceeding

### 5. Pre-Commit Validation (REQUIRED for UI changes)

Read `pre_commit.ui_patterns` from `.coco/config.yaml`. Check staged files:

```bash
git diff --cached --name-only | grep -E '{patterns from config}'
```

**If ANY matches found:**
- Invoke the `pre-commit-tester` agent if configured
- Wait for verdict
- If NEEDS FIXES: address issues before continuing
- If READY TO COMMIT: proceed

**If NO matches found:**
- Run `pre_commit.build_command` if configured

### 6. Commit

Read `commit.title_format` from config (default: `{description}. Completes {issue_key}`):

```bash
git add {specific-files}
git commit -m "$(cat <<'EOF'
{description}. Completes {issue_key}

{Implementation details}

Task References:
- {task-ref}: {description}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**CRITICAL**: `{issue_key}` MUST come from task metadata. Never invent keys.

### 7. Close Tracker Task

```bash
coco_tracker close {task-id}
```

### 8. Bridge to Issue Tracker (Post-Commit -- REQUIRED if configured)

Based on `issue_tracker.provider`:

**If "linear"**:
- Update issue state to `status_map.completed` (default: "In Review")
- Update issue description with Implementation Summary
- Post comment with test/build details

**If "github"**:
- Update labels, add comment with summary

**If "none"**: Skip

### 9. Acceptance Criteria Check

Read the sub-phase's acceptance criteria from `specs/{feature}/tasks.md`. Verify each criterion is satisfied. If any criterion is not met, implement the missing piece first.

### 10. Check Next

```bash
coco_tracker ready --json --epic {epic-id}
```

If another task is available and unblocked, loop back to step 2.
If no tasks available, report epic completion.

## Session Management

At the start of each session:
```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"
coco_tracker session-start "Continuing {feature-name}"
coco_tracker epic-status {epic-id}
coco_tracker ready --json --epic {epic-id}
```

Before ending a session:
```bash
coco_tracker session-end
```

## Error Handling

- **Build fails**: Fix errors, do not proceed to commit
- **Tests fail**: Fix test failures before proceeding
- **Pre-commit tester fails**: Address feedback before committing
- **Issue tracker unavailable**: Log failure ("Issue tracker bridge skipped: {reason}"), continue with tracker, run `/coco.sync` at session end
- **Missing `issue_key`**: STOP. Fix metadata before continuing. Never silently skip the bridge.
