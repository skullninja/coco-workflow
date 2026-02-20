---
description: Execute the next available tracked task with TDD, pre-commit validation, and issue tracker bridge sync.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Setup

1. Read `.coco/config.yaml` for project configuration.
2. Source `${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh`.
3. Determine the active epic (from `$ARGUMENTS` or most recent open epic).

## Pre-Execution Gate (MANDATORY)

Before starting the execution loop, verify the epic was imported correctly:

```bash
coco_tracker epic-status {epic-id}
```

**Check ALL before writing any code:**

1. **Tracker tasks exist** with correct dependencies
2. **If issue tracker configured**: every task has `issue_key` in metadata
3. **Commit message issue keys are real** -- keys must reference actual issues

If any check fails, STOP and run `/coco.import` first.

## Execution Loop

### 1. Find Next Task

```bash
coco_tracker ready --json --epic {epic-id}
```

Never manually pick tasks -- always use `ready` which respects dependency order.

### 2. Claim Task

```bash
coco_tracker update {task-id} --status in_progress
```

### 3. Bridge to Issue Tracker (Start)

Read `issue_key` from task metadata. Based on `issue_tracker.provider` in config:

**If "linear"**: Update issue to "In Progress" using `mcp__plugin_linear_linear__update_issue`
**If "github"**: Add "in-progress" label via `gh issue edit`
**If "none"**: Skip

If `issue_key` is missing and provider is configured, STOP and fix metadata.

### 4. TDD Implementation

Read the sub-phase tasks from `specs/{feature}/tasks.md` and implement:

**a. Write Tests First** (if TDD requested in spec)
- Create test files, verify they fail (RED)

**b. Implement Code**
- Write implementation to make tests pass (GREEN)
- Follow existing patterns in the codebase

**c. Verify**
- Run test suite:
  ```bash
  {test_command from config, or auto-detect}
  ```
- All tests must pass before proceeding

### 5. Pre-Commit Validation

Read `pre_commit.ui_patterns` from `.coco/config.yaml`. Check staged files against patterns:

```bash
git diff --cached --name-only | grep -E '{patterns}'
```

**If ANY matches found** and a pre-commit-tester agent is configured:
- Invoke the pre-commit-tester agent
- Wait for verdict
- If NEEDS FIXES: address issues before continuing

**If NO matches found**:
- Build check is sufficient (run `pre_commit.build_command` if configured)

### 6. Commit

Read `commit.title_format` from config. Format:

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

### 8. Bridge to Issue Tracker (Complete)

Based on `issue_tracker.provider`:

**If "linear"**:
- Update issue state to `status_map.completed` (default: "In Review")
- Update issue description with Implementation Summary:
  - What was built (functional outcomes)
  - Key code changes (files + descriptions)
  - Commit hash
- Post comment with test/build details

**If "github"**:
- Update labels, add comment with summary
- Close issue if appropriate

**If "none"**: Skip

### 9. Acceptance Criteria Check

Read the sub-phase's acceptance criteria from tasks.md. Verify each criterion is satisfied. If any criterion is not met, do not proceed -- implement the missing piece first.

### 10. Check Next

```bash
coco_tracker ready --json --epic {epic-id}
```

If another task is available, loop back to step 2.
If no tasks available, report epic completion.

## Session Management

At session start:
```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"
coco_tracker session-start "Continuing {feature-name}"
coco_tracker epic-status {epic-id}
coco_tracker ready --json --epic {epic-id}
```

At session end:
```bash
coco_tracker session-end
```

## Error Handling

- **Build fails**: Fix errors, do not proceed to commit
- **Tests fail**: Fix failures before proceeding
- **Pre-commit tester fails**: Address feedback before committing
- **Issue tracker unavailable**: Log failure, continue with tracker, run `/coco.sync` at session end
- **Missing `issue_key`**: STOP and fix metadata before continuing
