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
2. Determine the target epic from `$ARGUMENTS` or most recent open epic.
3. Read loop config. Defaults when a key is absent: `max_iterations: 20`,
   `no_progress_threshold: 3`, `pause_on_error: false`, `dashboard_every: 5`,
   `parallel.enabled: true`, `parallel.max_agents: 3`,
   `parallel.max_agent_attempts: 2`.

   A project initialized before these defaults changed still carries the old
   values in its own `.coco/config.yaml`, which is read in preference to any
   default here. If `pause_on_error` is `true` or `parallel.enabled` is `false`
   in this project, say so in the opening ledger line -- the user may not know
   their config predates the change, and `/coco:setup migrate` reconciles it.

## Pre-Loop Gate

Verify the epic is ready for autonomous execution:

```bash
coco-tracker epic-status {epic-id}
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
git branch --show-current
```

Record the output as the feature branch name for later use.

```bash
coco-tracker session-start "Autonomous loop for {epic-id}"
```

Set counters:
- `iteration = 0`
- `consecutive_no_progress = 0`
- `initial_commit_count = $(git rev-list --count HEAD)`

## Autonomous Loop

### The Loop Does Not Stop To Report

This loop runs to completion inside one turn. **Ending the turn is an exit**, and
the only legitimate exits are the ones enumerated under Exit Conditions below.

Four rules, ordered by how often they are broken:

1. **Never end a turn on a statement about what you are about to do.** If you can
   name the next step, take it -- in the same turn, with a tool call. The moment
   you find yourself writing "Continuing with X", "I'll now X", "Next I'll X", or
   "Moving on to X", delete the sentence and call the tool for X instead.
   Announcing a step is not performing it, and it does not count as progress.

2. **Never offer a checkpoint nobody asked for.** "Unless you want to look at X
   first", "say the word and I'll", "let me know if you'd rather" -- the user
   invoked an autonomous loop. Offering to stop is not deference; it is a stall
   they now have to clear by typing. If a decision genuinely requires them, it is
   an Exit Condition, so exit properly using the report format below.

3. **Status belongs in the ledger line, not in prose.** One line per iteration,
   in the format under Progress Ledger. A paragraph explaining what you just did,
   what you learned, and what you plan next is the shape a stall takes: it reads
   as a natural stopping point, and then you stop.

4. **A failed task is not an exit** when `pause_on_error` is false (the default).
   Log it, leave it `in_progress`, take the next ready task. The circuit breaker
   exists to catch a genuinely stuck loop; do not pre-empt it.

If you are unsure whether to continue: continue. The user can interrupt at any
moment, but they cannot un-stall a loop that has already yielded without typing a
new message -- which is the exact cost this section exists to avoid.

### Progress Ledger

Emit one line at the **start** of every iteration, before doing any work:

```
[{epic-id} "{epic title}" | {done}/{total} tasks | {blocked} blocked | iter {n}/{max} | no-progress {c}/{threshold}] -> {task-id} "{task title}"
```

And one when the iteration resolves:

```
[{epic-id} | {done}/{total} | iter {n}/{max}] {task-id} merged | PR #{n} (+{add}/-{del}, {k} tests) 
```

Use `FAILED`, `BLOCKED`, or `NO-PROGRESS` in place of `merged` where they apply,
and name the reason in the same line. Counts come from `coco-tracker epic-status`.

Two things this makes visible that were previously silent:

- **Parallel falling back to serial.** When `loop.parallel.enabled` is true but a
  batch runs serially anyway, say which condition caused it -- only one task
  ready, or ready tasks missing `owns_files`. Today this decision is invisible,
  so a loop that never parallelizes looks identical to one that cannot.
- **An agent that returned without committing.** Name the agent and its task
  rather than silently counting the iteration as no-progress.

Every `dashboard_every` iterations (config, default 5) and at every exit, render
the full `/coco:dashboard` view inline. The ledger line says where you are; the
dashboard says how far along the epic is.

### Loop Condition

Continue while ALL are true:
- `iteration < max_iterations`
- `consecutive_no_progress < no_progress_threshold`
- Epic has incomplete tasks

### Per-Iteration Steps

**1. Verify branch state**

Clean up stale worktree references (from previous parallel agents or crashed sessions):

```bash
git worktree prune
```

Ensure we're on the feature branch (previous iteration may have merged an issue PR):

```bash
git checkout "$FEATURE_BRANCH"
```
```bash
git pull origin "$FEATURE_BRANCH"
```

**2. Check for next task**

```bash
coco-tracker ready --json --epic {epic-id}
```

If no task is ready but incomplete tasks exist, tasks are blocked. Report and exit:
```
LOOP PAUSED: All remaining tasks are blocked.
Blocked tasks: {list}
Waiting on: {dependency list}
```

**3. Check for parallel dispatch opportunity**

Read `loop.parallel.enabled` from config (default: `true`).

**If parallel is enabled:**

1. Check if multiple tasks are ready:
   ```bash
   coco-tracker ready --json --epic {epic-id}
   ```
   If only one task is ready, fall through to serial execution (step 4).

2. If 2+ tasks are ready, check `owns_files` metadata for overlap:
   ```bash
   coco-tracker list --json --epic {epic-id}
   ```
   Parse `owns_files` from each ready task's metadata. Two tasks overlap if any glob pattern from one matches files that the other also claims.

3. If 2+ tasks have non-overlapping `owns_files`, dispatch them in parallel:
   - Spawn up to `loop.parallel.max_agents` (default: 3) `task-executor` agents via the `Task` tool
   - Send all agent calls in a **single message** (multiple tool calls) for true parallelism
   - Each agent receives: task ID, epic ID, feature branch name, config values
   - Wait for all agents to complete

4. After parallel batch completes:
   - Run `git worktree prune` to clean up finished agent worktrees
   - Pull the feature branch to get any remote changes
   - For each successful agent:
     a. Run AI code review on its PR (invoke `code-reviewer` agent)
     b. Handle review-fix loop per PR (max `pr.review.max_review_iterations`)
     c. Merge approved PRs: `gh pr merge {pr-number} --{pr.issue_merge_strategy} --delete-branch`
     d. Bridge to issue tracker (complete) -- set "Done"
   - For each failed agent: mark task for retry in next iteration
   - **An agent that returns without a PR or any commit counts as failed**, not as
     completed. Name it and its task in the ledger line, leave the task
     `in_progress`, and continue. Do not re-dispatch it in the same iteration.

   The orchestrator cannot interrupt a running agent -- the dispatch call blocks
   until the agent returns. The bound is inside the agent instead
   (`loop.parallel.max_agent_attempts`), so an agent that cannot finish gives up
   and reports rather than spinning. A genuinely hung agent will still hold the
   batch; that is a known limit, not something this step can recover from.

5. Skip to step 7 (Check progress) after handling all parallel results.

**If parallel is disabled**, or if ready tasks lack `owns_files` metadata, or if only one task is ready:
Fall through to serial execution (step 4), and **say which of those three it was**
in the ledger line. A loop that silently never parallelizes is indistinguishable
from one that cannot, and missing `owns_files` is a fixable planning gap the user
can only fix if they are told about it.

**4. Record pre-iteration commit count (serial path)**

```bash
git rev-list --count HEAD
```

Record this as the pre-iteration commit count.

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
git rev-list --count HEAD
```

Compare to the pre-iteration count.

If `post_commit_count > pre_commit_count`:
- `consecutive_no_progress = 0` (reset)
- Emit the resolution ledger line (see Progress Ledger)

If `post_commit_count == pre_commit_count`:
- `consecutive_no_progress += 1`
- Emit the ledger line with `NO-PROGRESS` and the reason -- an agent returned
  without committing, a review-fix loop exhausted, a task was skipped after
  failure. "No progress" without a reason is the least useful thing the loop can
  say, because it is exactly when the user most needs to know why.

Then render the dashboard if `iteration % dashboard_every == 0`.

**7. Check epic status**

```bash
coco-tracker epic-status {epic-id}
```

If all tasks are closed: break loop (success).

**8. Increment and continue**

`iteration += 1`

## Exit Conditions

### Success: Epic Complete

All tasks closed. Create the feature PR to main (if `pr.enabled`):

```bash
coco-tracker session-end
```

**If `pr.enabled`:**

```bash
git checkout "$FEATURE_BRANCH"
```
```bash
git pull origin "$FEATURE_BRANCH"
```

Create the feature PR to main:

```bash
gh pr create --base main --head "$FEATURE_BRANCH" --title "{feature-name}: {epic description}" --body-file - <<'EOF'
## Feature Summary

{comprehensive summary of the full feature}

## Issue PRs Merged

{list of all issue PRs merged into this feature branch, with links}

## Test Value Summary

{planned tests written / total planned across all sub-phases; count of unplanned tests carried in from issue PRs}

## Test Results

{full test suite results}

## Issues

{links to all issues in the epic with their keys}
EOF
```

Add the feature PR to the project board (if GitHub Projects V2 enabled):

```bash
gh pr view --json url -q .url
```

Use the URL from the output.

Read `.coco/state/gh-projects.json` and find the feature entry where `project_number` matches the `gh_project_number` metadata from any task in the epic. Extract `project_id`, `status_field_id`, `status_options`, and `project_number` from that entry.

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
- Using the feature entry already resolved above (matched by `gh_project_number`), iterate all tasks in the epic and set project status to "Done" via `gh project item-edit` using the entry's `project_id`, `status_field_id`, and `status_options`
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

Fall back to direct merge (each as a separate Bash tool call):
```bash
git checkout main
```
```bash
git pull
```
```bash
git merge "$FEATURE_BRANCH"
```
```bash
git push
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
coco-tracker sync
```

### Circuit Breaker: No Progress

`consecutive_no_progress >= no_progress_threshold`. The loop is stuck.

```bash
coco-tracker session-end
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
coco-tracker session-end
```

```
LOOP PAUSED: Reached max iterations ({max_iterations}).
Tasks completed: {count} of {total}
Remaining tasks: {list}

To resume: /coco:loop {epic-id}
```

### Error Pause

Only when `pause_on_error` is **true**. It defaults to `false`, in which case a
failed task is skipped (left `in_progress`), logged in the ledger, and the loop
takes the next ready task -- see rule 4 under The Loop Does Not Stop To Report.

If `pause_on_error` is true and a task fails (tests fail repeatedly, build broken):

```bash
coco-tracker session-end
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
