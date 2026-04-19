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
2. If `issue_tracker.provider` is "none", report "No issue tracker configured" and exit.

## Execution

### 0. Clean Up Stale Worktrees

Remove stale git worktree references left by crashed or completed agents:

```bash
git worktree prune
```

If `.claude/worktrees/` contains directories with no corresponding git worktree, remove them:

```bash
git worktree list --porcelain
```

Compare against directories in `.claude/worktrees/`. Remove any orphaned directories.

### 1. Load Tracker State

```bash
coco-tracker list --json --epic {epic-id}
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

If `github.use_projects` is true:
1. Read `.coco/state/gh-projects.json` and find the feature entry where `project_number` matches the task's `gh_project_number` metadata. Extract `project_id`, `status_field_id`, and `status_options` from that entry.
2. Query project board status as source of truth:
   ```bash
   gh project item-list {project_number} --owner {github.owner} --format json
   ```
   Match each task's `gh_project_item_id` to get its current board column status.
3. **Backfill detection**: For tasks with `issue_key` but no `gh_project_item_id` (pre-existing issues created before Projects V2 was enabled), offer to backfill:
   ```bash
   gh project item-add {project_number} --owner {github.owner} --url {issue_url}
   ```
   Then update tracker metadata with the new `gh_project_item_id`.

If `github.use_projects` is false (legacy):
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
