---
description: Execute the next available tracked task with TDD, pre-commit validation, PR creation, AI code review, and issue tracker bridge sync.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Setup

1. Read `.coco/config.yaml` for project configuration (including `pr` section).
2. Source `${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh`.
3. Determine the active epic (from `$ARGUMENTS` or most recent open epic).
4. Determine the feature branch:
   - If on a `feature/*` branch, that is the feature branch
   - Otherwise, read `feature_branch` from the first task's metadata in the epic

## Pre-Execution Gate (MANDATORY)

Before starting the execution loop, verify the epic was imported correctly:

```bash
coco_tracker epic-status {epic-id}
```

**Check ALL before writing any code:**

1. **Tracker tasks exist** with correct dependencies
2. **If issue tracker configured**: every task has `issue_key` in metadata
3. **Commit message issue keys are real** -- keys must reference actual issues
4. **If `pr.enabled`**: verify on a `feature/*` branch and remote origin is configured

If any check fails, STOP and use the `coco-import` skill first.

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

### 3. Create Issue Branch

**If `pr.enabled` is false**: skip this step.

Read `issue_key` from task metadata. Determine branch name:
- If `pr.branch.issue_branch_naming` is `"issue_key"`: use `{issue_key}` (e.g., `AUTH-3`)
- If `"task_id"`: use the tracker task ID (e.g., `epic-001.3`)
- Normalize: lowercase, replace spaces with hyphens

```bash
FEATURE_BRANCH=$(git branch --show-current)
ISSUE_BRANCH="${FEATURE_BRANCH}/{issue_key}"
git checkout -b "$ISSUE_BRANCH"
```

### 4. Bridge to Issue Tracker (Start)

Read `issue_key` from task metadata. Based on `issue_tracker.provider` in config:

**If "linear"**: Update issue to `status_map.in_progress` using `mcp__plugin_linear_linear__update_issue`

**If "github"**:
- If `github.use_projects` is true and task has `gh_project_item_id` in metadata:
  Read `.coco/state/gh-projects.json` for field IDs, then:
  ```bash
  gh project item-edit \
    --project-id {project_id} \
    --id {gh_project_item_id} \
    --field-id {status_field_id} \
    --single-select-option-id {status_options[status_map.in_progress]}
  ```
- Otherwise (legacy fallback): `gh issue edit {issue_number} --add-label "in-progress"`

**If "none"**: Skip

If `issue_key` is missing and provider is configured, STOP and fix metadata.

### 5. TDD Implementation

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

### 6. Pre-Commit Validation

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

### 7. Commit

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

**NOTE**: The `Completes {issue_key}` in the commit message is for **traceability only**. It does NOT resolve the issue. Issue resolution happens at PR merge (step 12).

### 8. Create PR

**If `pr.enabled` is false**: skip to step 12 (Close Tracker Task).

Push the issue branch and create a PR:

```bash
git push -u origin "$ISSUE_BRANCH"
```

Create the PR with the issue ID in the body:

```bash
gh pr create \
  --base "$FEATURE_BRANCH" \
  --head "$ISSUE_BRANCH" \
  --title "{issue_key}: {task title}" \
  --body "$(cat <<'EOF'
## Summary

{implementation summary from commit message body}

Resolves {issue_key}

## Task Reference

- **Task**: {task-id} -- {task title}
- **Epic**: {epic-id}

## Changes

{list of files changed with brief descriptions}

## Test Results

{test output summary}
EOF
)"
```

**Issue ID in PR body is MANDATORY:**
- For Linear issues: `Resolves {ISSUE-KEY}` (e.g., `Resolves AUTH-3`)
- For GitHub issues: `Closes #{N}` (e.g., `Closes #7`)
- For no provider: `Ref {task-id}`

Update issue tracker status to "In Review":

**If "linear"**: Update issue state to `status_map.in_review` using `mcp__plugin_linear_linear__update_issue`

**If "github"**:
- If `github.use_projects` is true and task has `gh_project_item_id` in metadata:
  ```bash
  gh project item-edit \
    --project-id {project_id} \
    --id {gh_project_item_id} \
    --field-id {status_field_id} \
    --single-select-option-id {status_options[status_map.in_review]}
  ```
- Otherwise (legacy fallback): `gh issue edit {issue_number} --add-label "in-review"`

**If "none"**: Skip

### 9. AI Code Review

**If `pr.review.enabled` is false**: skip to step 11 (Merge PR).

Invoke the `code-reviewer` agent with the PR number as context.

The agent will:
1. Read the PR diff via `gh pr diff {pr-number}`
2. Analyze against review criteria (correctness, security, breaking changes, test coverage, performance, code quality)
3. Post structured review comment on the PR
4. Return verdict: **APPROVED** or **CHANGES REQUESTED**

### 10. Review-Fix Loop

**If verdict is APPROVED**: skip to step 11.

If **CHANGES REQUESTED**, enter the fix loop:

Set `review_iteration = 1`.

**While** `review_iteration <= pr.review.max_review_iterations` (default: 3):

1. Parse critical findings from the review comment (CR-N entries with file:line and suggested fix)
2. For each critical finding:
   - Read the referenced file and line
   - Apply the suggested fix
   - Run tests to verify no regressions
3. Commit fixes:
   ```bash
   git add {fixed-files}
   git commit -m "$(cat <<'EOF'
   Address review feedback (iteration {N}). Ref {issue_key}

   Fixes:
   - CR-1: {brief description of fix}
   - CR-2: {brief description of fix}

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```
4. Push: `git push`
5. Re-invoke the `code-reviewer` agent
6. If **APPROVED**: break the loop
7. `review_iteration += 1`

**If loop exhausted** (max iterations reached):
- Post comment on PR: "Automated review-fix limit reached. Requesting human review."
- Leave PR open for human intervention
- Update issue tracker to flag for review
- Log the escalation
- Do NOT merge -- exit the task with a warning

### 11. Merge PR

After review is approved (or if review is disabled):

```bash
gh pr merge {pr-number} --{pr.issue_merge_strategy} --delete-branch
```

Switch back to the feature branch:

```bash
git checkout "$FEATURE_BRANCH"
git pull origin "$FEATURE_BRANCH"
```

### 12. Close Tracker Task

```bash
coco_tracker close {task-id}
```

### 13. Bridge to Issue Tracker (Complete)

**This step runs when the PR is merged (or immediately after commit if PRs are disabled).**

Based on `issue_tracker.provider`:

**If "linear"**:
- Update issue state to `status_map.completed` (default: "Done")
- Update issue description with Implementation Summary:
  - What was built (functional outcomes)
  - Key code changes (files + descriptions)
  - Commit hash and PR number (if applicable)
- Post comment with test/build details

**If "github"**:
- If `github.use_projects` is true and task has `gh_project_item_id` in metadata:
  ```bash
  gh project item-edit \
    --project-id {project_id} \
    --id {gh_project_item_id} \
    --field-id {status_field_id} \
    --single-select-option-id {status_options[status_map.completed]}
  ```
- Add comment with summary
- Close issue (the `Closes #N` in PR body may auto-close it)

**If "none"**: Skip

### 14. Acceptance Criteria Check

Read the sub-phase's acceptance criteria from tasks.md. Verify each criterion is satisfied. If any criterion is not met, do not proceed -- implement the missing piece first.

### 15. Check Next

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
- **PR creation fails**: Log error, leave branch with commits, exit task
- **Review agent fails**: Skip review, proceed to merge with warning
- **Review-fix loop exhausted**: Leave PR open, exit task with warning
- **`gh` not available**: STOP with error asking user to install GitHub CLI
- **No remote configured**: STOP with error (PRs require a remote)
- **Issue tracker unavailable**: Log failure, continue with tracker, run `/coco.sync` at session end
- **Missing `issue_key`**: STOP and fix metadata before continuing
