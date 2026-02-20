---
description: Autonomous execution loop. Runs the TDD cycle repeatedly until all tasks in an epic are complete, with circuit breaker protection.
---

## User Input

```text
$ARGUMENTS
```

`$ARGUMENTS` is an epic ID or feature name. If empty, use the most recent open epic.

## Setup

1. Read `.coco/config.yaml` for project configuration.
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

If any check fails, STOP and run `/coco.import` first.

## Initialize Loop State

```bash
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

**1. Check for next task**

```bash
coco_tracker ready --json --epic {epic-id}
```

If no task is ready but incomplete tasks exist, tasks are blocked. Report and exit:
```
LOOP PAUSED: All remaining tasks are blocked.
Blocked tasks: {list}
Waiting on: {dependency list}
```

**2. Record pre-iteration commit count**

```bash
pre_commit_count=$(git rev-list --count HEAD)
```

**3. Execute the task**

Follow the full `/coco.execute` flow for a single task:
- Claim task (`update --status in_progress`)
- Bridge to issue tracker (start)
- TDD implementation (write tests, implement, verify)
- Pre-commit validation
- Commit with issue key
- Close tracker task
- Bridge to issue tracker (complete)
- Acceptance criteria check

**4. Check progress**

```bash
post_commit_count=$(git rev-list --count HEAD)
```

If `post_commit_count > pre_commit_count`:
- `consecutive_no_progress = 0` (reset)
- Log: `Iteration {iteration}: Task {task-id} completed. {commits} new commit(s).`

If `post_commit_count == pre_commit_count`:
- `consecutive_no_progress += 1`
- Log: `Iteration {iteration}: No progress. ({consecutive_no_progress}/{no_progress_threshold})`

**5. Check epic status**

```bash
coco_tracker epic-status {epic-id}
```

If all tasks are closed: break loop (success).

**6. Increment and continue**

`iteration += 1`

## Exit Conditions

### Success: Epic Complete

All tasks closed. Report summary and clean up:

```bash
coco_tracker session-end
coco_tracker sync
```

```
LOOP COMPLETE
=============
Epic: {epic-id}
Iterations: {iteration}
Tasks completed: {count}
Total commits: {final_count - initial_count}
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

To resume: /coco.loop {epic-id}
To debug: /coco.status {epic-id}
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

To resume: /coco.loop {epic-id}
```

### Error Pause

If `pause_on_error` is true and a task fails (tests fail repeatedly, build broken):

```bash
coco_tracker session-end
```

```
LOOP PAUSED: Task {task-id} failed.
Error: {description}

To resume after fixing: /coco.loop {epic-id}
```

## Error Handling

- **Build/test failure**: If `pause_on_error` is true, exit the loop with a report. If false, skip the task (leave in_progress) and try the next ready task.
- **Issue tracker unavailable**: Log and continue. Run `/coco.sync` after loop completes.
- **Git conflicts**: Exit the loop. Manual resolution required.
- **No ready tasks but epic incomplete**: Exit with blocked-task report.

## Notes

- The loop runs within a single Claude Code session (no fresh instances per iteration).
- Each iteration follows the exact same TDD flow as `/coco.execute`.
- Progress is measured by git commits, not just task status changes.
- The circuit breaker prevents infinite loops when a task can't be completed.
- Use `/coco.status` to inspect state between loop runs.
