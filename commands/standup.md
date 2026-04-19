---
description: Show a daily standup summary with completed, in-progress, and blocked tasks across all active epics.
---

## User Input

```text
$ARGUMENTS
```

`$ARGUMENTS` can be an epic ID to scope the standup, or empty for all active epics.

## Setup

1. Read `.coco/config.yaml` for project configuration.

## Execution

### 1. Gather Tracker State

Get all epics and tasks:
```bash
coco-tracker list --json
```

If `$ARGUMENTS` specifies an epic, filter to that epic. Otherwise, include all non-closed epics.

### 2. Gather Git Activity

Get recent commits (last 24 hours):
```bash
git log --oneline --since="24 hours ago" --format="%h %s (%ar)"
```

Get current branch:
```bash
git branch --show-current
```

### 3. Gather Issue Tracker State (if configured)

Read `issue_tracker.provider` from config:

**If "linear"**: Use `mcp__plugin_linear_linear__list_issues` to get issues for active projects with recent updates.

**If "github"**:
- Use `gh issue list` to get recent issue activity.
- If `github.use_projects` is true: also query `gh project item-list {project_number} --owner {github.owner} --format json` to show board column status alongside tracker state.

**If "none"**: Skip.

### 4. Produce Standup Report

Output a structured standup:

```
## Standup: {YYYY-MM-DD}

### Done (last 24h)
- {task-id}: {title} -- {commit-hash} ({time ago})
  {issue-key if available}

### In Progress
- {task-id}: {title} -- claimed {time ago}
  Branch: {branch from metadata}
  Issue: {issue-key from metadata}

### Blocked
- {task-id}: {title}
  Waiting on: {dependency-id} ({dependency-title})

### Up Next
- {task-id}: {title} (next ready task per dependency order)

### Metrics
- Tasks completed (24h): {count}
- Commits (24h): {count}
- Active epics: {count} ({completed}/{total} tasks, {percent}% complete)
```

### 5. Issue Tracker Summary (if configured)

If an issue tracker is configured, append:

```
### Issue Tracker
- Open issues: {count}
- In Review: {count}
- Recently closed: {count in last 24h}
```

## Rules

- If no active epics exist, report "No active epics. Start with `/coco:phase` or `/coco:planning-session tactical`."
- If no activity in the last 24 hours, report "No activity in the last 24 hours" with current state.
- Keep the output scannable -- tables and bullet points, not prose.
