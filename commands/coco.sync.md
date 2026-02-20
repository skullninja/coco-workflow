---
description: Reconcile coco tracker state with the configured issue tracker. Syncs task statuses and reports mismatches.
---

## User Input

```text
$ARGUMENTS
```

`$ARGUMENTS` can optionally specify:
- `--dry-run` -- show what would change without making updates
- `--epic {name}` -- sync a specific epic (default: active)

## Setup

1. Read `.coco/config.yaml` for `issue_tracker` configuration.
2. Source `${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh`.
3. If `issue_tracker.provider` is "none", report "No issue tracker configured" and exit.

## Execution

### 1. Load Tracker State

```bash
coco_tracker list --json --epic {epic-id}
```

Parse all tasks with their statuses and `issue_key` metadata.

### 2. Load Issue Tracker State

For each tracker task that has an `issue_key`:

**If "linear"**:
```
Use: mcp__plugin_linear_linear__get_issue
Parameters:
  id: {issue_key}
```

**If "github"**:
```bash
gh issue view {issue_number} --json state,labels
```

### 3. Compare and Sync

Apply status mapping from `issue_tracker.status_map` in config:

| Tracker Status | Expected Issue Status |
|---|---|
| `pending` | {status_map.pending} (default: Backlog) |
| `in_progress` | {status_map.in_progress} (default: In Progress) |
| `completed` | {status_map.completed} (default: In Review) |

For each mismatch, update the issue tracker to match the coco tracker (tracker is source of truth).

### 4. Report

```
Coco Sync Report
================
Epic: {epic-name}
Tasks synced: {count}
Already in sync: {count}
Updated: {count}

Changes:
  {issue-key}: {old-status} -> {new-status} (Tracker: {tracker-status})

Orphans (tracker task without issue):
  {task-id}: {title}

Orphans (issue not in tracker):
  {issue-key}: {title}
```

### 5. Post Summary (Optional)

If changes were made and provider supports comments, post a sync summary.
