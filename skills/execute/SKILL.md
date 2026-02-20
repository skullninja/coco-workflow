---
name: coco-execute
description: Execute the next available tracked task with TDD, pre-commit validation, PR workflow, AI code review, and issue tracker bridge sync. Primary execution interface for multi-session feature work.
---

# Coco Execute Skill

Primary execution interface for spec-driven features. Manages dependency-aware task selection, TDD implementation, PR creation with AI code review, and issue tracker synchronization across sessions.

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
4. **If `pr.enabled`**: verify on a `feature/*` branch and remote origin is configured

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

### 3. Create Issue Branch

**If `pr.enabled` is false**: skip this step.

Read `issue_key` from task metadata. Determine branch name based on `pr.branch.issue_branch_naming`:

```bash
FEATURE_BRANCH=$(git branch --show-current)
ISSUE_BRANCH="${FEATURE_BRANCH}/{issue_key}"
git checkout -b "$ISSUE_BRANCH"
```

### 4. Bridge to Issue Tracker (Start)

Read `issue_key` from task metadata. Read `.coco/config.yaml` for `issue_tracker.provider`:

**If "linear"**: `mcp__plugin_linear_linear__update_issue` with state from `status_map.in_progress`
**If "github"**: `gh issue edit {number} --add-label in-progress`
**If "none"**: Skip

If `issue_key` is missing and provider is not "none", STOP and fix metadata.

### 5. TDD Implementation

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

### 6. Pre-Commit Validation (REQUIRED for UI changes)

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

### 7. Commit

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

**NOTE**: `Completes {issue_key}` is for traceability only. It does NOT resolve the issue. Issue resolution happens at PR merge (step 12).

### 8. Create PR

**If `pr.enabled` is false**: skip to step 12.

```bash
git push -u origin "$ISSUE_BRANCH"

gh pr create \
  --base "$FEATURE_BRANCH" \
  --head "$ISSUE_BRANCH" \
  --title "{issue_key}: {task title}" \
  --body "{summary}\n\nResolves {issue_key}\n\n{details}"
```

**Issue ID in PR body is MANDATORY** (`Resolves {KEY}` for Linear, `Closes #{N}` for GitHub).

Update issue tracker to "In Review" (`status_map.in_review`).

### 9. AI Code Review

**If `pr.review.enabled` is false**: skip to step 11.

Invoke the `code-reviewer` agent with the PR number. The agent reviews the diff and posts a structured comment with verdict: APPROVED or CHANGES REQUESTED.

### 10. Review-Fix Loop

**If verdict is APPROVED**: skip to step 11.

For up to `pr.review.max_review_iterations` (default: 3):
1. Parse critical findings (CR-N entries)
2. Fix each critical issue
3. Run tests to verify
4. Commit: `Address review feedback (iteration N). Ref {issue_key}`
5. Push and re-invoke the reviewer
6. If APPROVED: break

If loop exhausted: leave PR open, post escalation comment, exit task with warning.

### 11. Merge PR

```bash
gh pr merge {pr-number} --{pr.issue_merge_strategy} --delete-branch
git checkout "$FEATURE_BRANCH"
git pull origin "$FEATURE_BRANCH"
```

### 12. Close Tracker Task

```bash
coco_tracker close {task-id}
```

### 13. Bridge to Issue Tracker (Complete)

**Triggered by PR merge (or by commit if PRs disabled).** This is when the issue resolves.

**If "linear"**: Update issue state to `status_map.completed` ("Done"), post implementation summary
**If "github"**: Update labels, add comment (`Closes #N` in PR body may auto-close)
**If "none"**: Skip

### 14. Acceptance Criteria Check

Read the sub-phase's acceptance criteria from `specs/{feature}/tasks.md`. Verify each criterion is satisfied. If any criterion is not met, implement the missing piece first.

### 15. Check Next

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
- **PR creation fails**: Log error, leave branch with commits, exit task
- **Review agent fails**: Skip review, proceed to merge with warning
- **Review-fix loop exhausted**: Leave PR open, exit task with warning
- **Issue tracker unavailable**: Log failure, continue with tracker, run `/coco.sync` at session end
- **Missing `issue_key`**: STOP. Fix metadata before continuing. Never silently skip the bridge.
