---
description: Autonomous execution loop. Runs the TDD cycle repeatedly until all tasks in an epic are complete, with circuit breaker protection and PR workflow.
---

## User Input

```text
$ARGUMENTS
```

`$ARGUMENTS` is an epic ID or feature name. If empty, use the most recent open epic.

## Setup

1. Read `.coco/config.yaml` for project configuration (including `pr` and `loop` sections).
2. Source `${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh`.
3. Determine the target epic from `$ARGUMENTS` or most recent open epic.
4. Read loop config (defaults: `max_iterations: 20`, `no_progress_threshold: 3`, `pause_on_error: true`).

## Pre-Loop Gate

Verify the epic is ready for autonomous execution:

```bash
coco_tracker epic-status {epic-id}
```

**Check ALL before entering the loop:**

1. **Tracker epic exists** and has tasks
2. **Dependencies are set** -- at least one task is unblocked (`ready` returns a result)
3. **If issue tracker configured**: every task has `issue_key` in metadata
4. **If `pr.enabled`**: verify on a `feature/*` branch
5. **If `pr.enabled`**: verify remote origin is configured (`git remote -v`)
6. **If `pr.enabled`**: verify `gh` CLI is available

If any check fails, STOP and report what needs to be fixed.

## Initialize Loop State

```bash
FEATURE_BRANCH=$(git branch --show-current)
coco_tracker session-start "Autonomous loop for {epic-id}"
```

Set counters:
- `iteration = 0`
- `consecutive_no_progress = 0`
- `initial_commit_count = $(git rev-list --count HEAD)`

## Autonomous Loop

### Loop Condition

Continue while ALL are true:
- `iteration < max_iterations`
- `consecutive_no_progress < no_progress_threshold`
- Epic has incomplete tasks

### Per-Iteration Steps

**1. Verify branch state**

Ensure we're on the feature branch (previous iteration may have merged an issue PR):

```bash
git checkout "$FEATURE_BRANCH"
git pull origin "$FEATURE_BRANCH"
```

**2. Check for next task**

```bash
coco_tracker ready --json --epic {epic-id}
```

If no task is ready but incomplete tasks exist, tasks are blocked. Report and exit:
```
LOOP PAUSED: All remaining tasks are blocked.
Blocked tasks: {list}
Waiting on: {dependency list}
```

**3. Check for parallel dispatch opportunity**

Read `loop.parallel.enabled` from config (default: `false`).

**If parallel is enabled:**

1. Check if multiple tasks are ready:
   ```bash
   coco_tracker ready --json --epic {epic-id}
   ```
   If only one task is ready, fall through to serial execution (step 4).

2. If 2+ tasks are ready, check `owns_files` metadata for overlap:
   ```bash
   coco_tracker list --json --epic {epic-id}
   ```
   Parse `owns_files` from each ready task's metadata. Two tasks overlap if any glob pattern from one matches files that the other also claims.

3. If 2+ tasks have non-overlapping `owns_files`, dispatch them in parallel:
   - Spawn up to `loop.parallel.max_agents` (default: 3) `task-executor` agents via the `Task` tool
   - Send all agent calls in a **single message** (multiple tool calls) for true parallelism
   - Each agent receives: task ID, epic ID, feature branch name, config values
   - Wait for all agents to complete

4. After parallel batch completes:
   - Pull the feature branch to get any remote changes
   - For each successful agent:
     a. Run AI code review on its PR (invoke `code-reviewer` agent)
     b. Handle review-fix loop per PR (max `pr.review.max_review_iterations`)
     c. Merge approved PRs: `gh pr merge {pr-number} --{pr.issue_merge_strategy} --delete-branch`
     d. Bridge to issue tracker (complete) -- set "Done"
   - For each failed agent: mark task for retry in next iteration

5. Skip to step 7 (Check progress) after handling all parallel results.

**If parallel is disabled**, or if ready tasks lack `owns_files` metadata, or if only one task is ready:
Fall through to serial execution (step 4).

**4. Record pre-iteration commit count (serial path)**

```bash
pre_commit_count=$(git rev-list --count HEAD)
```

**5. Execute the task (serial path)**

Follow the full `/coco:execute` flow for a single task (all 15 steps):
- Claim task
- Create issue branch (if `pr.enabled`)
- Bridge to issue tracker (start)
- TDD implementation
- Pre-commit validation
- Commit with issue key
- Create PR (if `pr.enabled`)
- AI code review + review-fix loop (if `pr.review.enabled`)
- Merge PR (if `pr.enabled`)
- Close tracker task
- Bridge to issue tracker (complete -- issue resolves at PR merge)
- Acceptance criteria check

**6. Check progress**

```bash
post_commit_count=$(git rev-list --count HEAD)
```

If `post_commit_count > pre_commit_count`:
- `consecutive_no_progress = 0` (reset)
- Log: `Iteration {iteration}: Task {task-id} completed. {commits} new commit(s).`

If `post_commit_count == pre_commit_count`:
- `consecutive_no_progress += 1`
- Log: `Iteration {iteration}: No progress. ({consecutive_no_progress}/{no_progress_threshold})`

**7. Check epic status**

```bash
coco_tracker epic-status {epic-id}
```

If all tasks are closed: break loop (success).

**8. Increment and continue**

`iteration += 1`

## Exit Conditions

### Success: Epic Complete

All tasks closed. Create the feature PR to main (if `pr.enabled`):

```bash
coco_tracker session-end
```

**If `pr.enabled`:**

```bash
# Ensure feature branch is up to date
git checkout "$FEATURE_BRANCH"
git pull origin "$FEATURE_BRANCH"

# Create feature PR to main
gh pr create --base main --head "$FEATURE_BRANCH" --title "{feature-name}: {epic description}" --body-file - <<'EOF'
## Feature Summary

{comprehensive summary of the full feature}

## Issue PRs Merged

{list of all issue PRs merged into this feature branch, with links}

## Test Results

{full test suite results}

## Issues

{links to all issues in the epic with their keys}
EOF
```

Add the feature PR to the project board (if GitHub Projects V2 enabled):

```bash
PR_URL=$(gh pr view --json url -q .url)
```

Read `.coco/state/gh-projects.json` for the feature's `project_number`:

```bash
gh project item-add {project_number} --owner {github.owner} --url "$PR_URL"
```

Then trigger a **full-feature AI code review**:
1. Invoke `code-reviewer` agent on the feature PR (reviews the full diff against main)
2. If CHANGES REQUESTED: enter review-fix loop (fixes committed directly to feature branch)
3. After approval, merge:

```bash
gh pr merge {feature-pr-number} --{pr.feature_merge_strategy} --delete-branch
```

Update all issues in the epic to final status (`status_map.completed`).

**If "github"** with Projects V2 enabled:
- Iterate all tasks in the epic, set project status to "Done" via `gh project item-edit`
- Close the GitHub Project:
  ```bash
  gh project close {project_number} --owner {github.owner}
  ```

**If "linear"**: Update all issues and close the project as before.

**Update roadmap** (if a roadmap file references this feature):
1. Read `discovery.roadmap_dir` from config (default: `docs/roadmap`)
2. Glob `{roadmap_dir}/*.md` and search for the feature slug in roadmap tables
3. If found, update the feature's `Status` column from "In Progress" to "Complete"
4. Update the feature's `Spec` column to point to `specs/{slug}/`

**If `pr.enabled` is false:**

Fall back to direct merge:
```bash
git checkout main && git pull && git merge "$FEATURE_BRANCH" && git push
```

**Report:**

```
LOOP COMPLETE
=============
Epic: {epic-id}
Iterations: {iteration}
Tasks completed: {count}
Issue PRs merged: {count}
Feature PR: #{pr-number} (merged)
Total commits: {final_count - initial_count}
```

```bash
coco_tracker sync
```

### Circuit Breaker: No Progress

`consecutive_no_progress >= no_progress_threshold`. The loop is stuck.

```bash
coco_tracker session-end
```

```
LOOP PAUSED: Circuit breaker triggered.
{no_progress_threshold} consecutive iterations with no commits.
Last attempted task: {task-id} -- {task-title}

To resume: /coco:loop {epic-id}
To debug: /coco:status {epic-id}
```

### Safety Limit: Max Iterations

`iteration >= max_iterations`. May need more iterations or tasks are too large.

```bash
coco_tracker session-end
```

```
LOOP PAUSED: Reached max iterations ({max_iterations}).
Tasks completed: {count} of {total}
Remaining tasks: {list}

To resume: /coco:loop {epic-id}
```

### Error Pause

If `pause_on_error` is true and a task fails (tests fail repeatedly, build broken):

```bash
coco_tracker session-end
```

```
LOOP PAUSED: Task {task-id} failed.
Error: {description}

To resume after fixing: /coco:loop {epic-id}
```

## Error Handling

- **Build/test failure**: If `pause_on_error` is true, exit the loop with a report. If false, skip the task (leave in_progress) and try the next ready task.
- **PR creation fails**: Log error, leave branch with commits, exit iteration.
- **Review-fix loop exhausted**: Leave PR open, exit iteration with warning, continue to next task.
- **Issue tracker unavailable**: Log and continue. Run `/coco:sync` after loop completes.
- **Git conflicts**: Exit the loop. Manual resolution required.
- **No ready tasks but epic incomplete**: Exit with blocked-task report.
- **`gh` not available**: STOP with error if `pr.enabled`.

## Notes

- The loop runs within a single Claude Code session (no fresh instances per iteration).
- Each iteration follows the exact same flow as `/coco:execute` (including PR steps when enabled).
- Progress is measured by git commits, not just task status changes. PR merge commits count as progress.
- The circuit breaker prevents infinite loops when a task can't be completed.
- The feature PR to main on epic completion gets a full-feature review (larger diff scope).
- Use `/coco:status` to inspect state between loop runs.
