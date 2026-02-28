---
description: Compact visual progress dashboard with progress bar, task table, dependency graph, and active/blocked/next status.
---

## User Input

```text
$ARGUMENTS
```

Optional: epic ID. If omitted, auto-detects from open epics.

## Setup

1. Source `${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh`.
2. Read `.coco/config.yaml` for:
   - `issue_tracker.provider` (determines Issue column)
   - `pr.enabled` (determines PR column)
   - `loop.parallel.enabled` (determines worktree info in Active line)
3. Determine epic:
   - If `$ARGUMENTS` contains an epic ID, use it
   - Otherwise, list all open epics via `coco_tracker epic-status`
   - If exactly one open epic, use it automatically
   - If multiple, render the **Multi-Epic Summary** and stop

## Execution

### 1. Gather Data

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"

# Epic metadata
coco_tracker epic-status {epic-id}

# All tasks in epic (JSON)
coco_tracker list --json --epic {epic-id}

# Next ready tasks
coco_tracker ready --json --epic {epic-id}
```

If `loop.parallel.enabled` is true:
```bash
git worktree list --porcelain
```

If `pr.enabled` is true:
```bash
gh pr list --json number,headRefName,state,reviewDecision,mergedAt --limit 100
```

Read the most recent session from `.coco/tasks/sessions.jsonl` (last `session_start` entry without a matching `session_end`) to compute session duration.

### 2. Multi-Epic Summary

If no epic was specified and multiple open epics exist, render this format and **stop**:

```
## Active Epics

| Epic     | Feature              | Progress             | Active |
|----------|----------------------|----------------------|--------|
| epic-001 | User Authentication  | ████████░░ 80% 8/10  | 1 task |
| epic-002 | Payment Integration  | ██░░░░░░░░ 20% 2/10  | --     |

Run `/coco:dashboard {epic-id}` for details.
```

For each epic: count done/total tasks, compute a 10-char progress bar, count in_progress tasks.

### 3. Compute Progress

From the JSON task list:

- `total` = number of tasks
- `done` = count where status is `completed` or `closed`
- `in_progress` = count where status is `in_progress`
- `blocked` = count where status is `pending` AND has unsatisfied dependencies (any `depends_on` ID that is not `completed`/`closed`)
- `ready` = count where status is `pending` AND all dependencies satisfied

**Progress bar** (20 characters wide):
- `filled` = round(done / total * 20)
- `empty` = 20 - filled
- Bar = `█` repeated `filled` times + `░` repeated `empty` times

### 4. Classify Each Task

For each task, determine:

| Display | Condition |
|---------|-----------|
| DONE | `status == "completed"` or `status == "closed"` |
| RUN | `status == "in_progress"` |
| WAIT | `status == "pending"` and all `depends_on` tasks are done |
| BLOCK | `status == "pending"` and some `depends_on` tasks are not done |

**Issue column**: Use `metadata.issue_key`. If `issue_tracker.provider` is `"none"` or no key exists, show `--`.

**PR column**: Cross-reference task's expected branch name against `gh pr list` output by matching `headRefName`. Show:
- `#{N} merged` if merged
- `#{N} review` if open with review requested
- `#{N} open` if open
- `--` if no matching PR or `pr.enabled` is false

### 5. Render Dashboard

Output using this exact format:

```
## {Epic Title}

{epic-id} | {branch-name} | Session: {duration}

{progress-bar} {pct}%  {done}/{total} done  {in_progress} active  {blocked} blocked

| # | Sub-Phase            | Status | Issue   | PR          |
|---|----------------------|--------|---------|-------------|
| {N} | {title}           | {status} | {key} | {pr-info}   |
...
```

Then render the **dependency graph** as a compact horizontal flow:

```
.1 Title ✓ ── .2 Title ✓ ─┬─ .3 Title ✓ ─┬─ .9 Title ○ ─┬─ .10 Title ~
                            ├─ .4 Title ✓  │              │
                            ├─ .5 Title ✓  │              │
                            └─ .6 Title ▶  ┘              │
                            ...                            │
```
✓ done  ▶ active  ○ ready  ~ blocked

**Graph construction rules:**
- Each node: `.{N} {abbreviated-title} {symbol}` -- abbreviate titles to ~12 chars max
- Symbols: `✓` (done), `▶` (in_progress), `○` (ready/wait), `~` (blocked)
- Use `──` for sequential flow, `┬─` / `├─` / `└─` for parallel fan-out
- Flow direction: left to right following dependency order
- Tasks that share the same dependencies fan out vertically from a `┬` branch point
- Tasks that converge (multiple deps feeding one task) connect with `─┘` joins
- Start from tasks with no dependencies (leftmost), end at tasks nothing depends on (rightmost)

Then render the **status lines** (omit any line where the category is empty):

```
**Active** .{N} {title} ({worktree-info}) | .{N} {title} ({worktree-info})
**Blocked** .{N} {title} -- waiting on .{X}, .{Y} | .{N} {title} -- waiting on .{Z}
**Next** .{N} {title} (ready) | .{N} {title} (ready)
```

- **Active**: Only shown when tasks have status `in_progress`. Include worktree name and branch if `loop.parallel.enabled` and worktree is detected.
- **Blocked**: Only shown when blocked tasks exist. List remaining (not-yet-done) dependency IDs using short `.N` notation.
- **Next**: Only shown when ready tasks exist that are not `in_progress`. These are what `/coco:execute` or `/coco:loop` would pick up.

### Edge Cases

- **No epics**: Output "No active epics. Start with `/coco:phase` or `/coco:planning-session tactical`."
- **Zero tasks**: Show epic header + "No tasks imported. Run the `import` skill."
- **All done**: Show 100% progress bar. Omit Active/Blocked/Next lines. Add: "All tasks complete. Merge feature branch or run `/coco:status` for details."
- **`gh` unavailable**: PR column shows `--` for all rows.
- **No git repo**: Omit worktree info and PR column.
- **No active session**: Omit session duration from header line.

## Rules

- Keep output compact -- aim for ~35 lines max for a 10-task epic.
- No prose or explanatory text between sections.
- Task table rows ordered by sub_phase number (from `metadata.sub_phase`) or task ID suffix.
- Strip "Sub-Phase N: " prefix from titles in the table -- just show the name.
- The dependency graph abbreviates titles aggressively to keep lines under ~80 chars.
