---
description: Show current execution status with progress, dependencies, file ownership, and parallelization opportunities.
---

## User Input

```text
$ARGUMENTS
```

## Setup

1. If `$ARGUMENTS` contains an epic ID, use it. Otherwise, find the most recent open epic:
   ```bash
   coco_tracker epic-status
   ```
   Pick the most recent non-closed epic from the output.

## Execution

### 1. Get Epic State

```bash
coco_tracker epic-status {epic-id}
coco_tracker list --json --epic {epic-id}
```

### 2. Categorize Tasks

Group tasks by status:
- **Running** (`in_progress`): Currently being worked on
- **Available** (`pending`, not blocked): Ready to start
- **Blocked** (`pending`, has unresolved blockers): Waiting on dependencies
- **Completed**: Done

### 3. File Ownership Map

For each running task, read `owns_files` from metadata (if present) and display:

```
File Ownership
==============
Task {id} ({title}):
  - {file pattern 1}
  - {file pattern 2}

Unclaimed:
  - {remaining file patterns}
```

### 4. Parallel Opportunities

Identify tasks that could run in parallel right now:

```
Parallel Opportunities
======================
Available tasks with no file conflicts:
  1. {task title} (no overlap with running tasks)

Cannot parallelize:
  - {task title} (blocked by {blocking-tasks})
```

### 5. Worktree / Parallel Status

Read `loop.parallel.enabled` from `.coco/config.yaml`. If parallel execution is enabled:

```
Parallel Execution
==================
Mode: {enabled | disabled}
Max agents: {max_agents}

Active Worktrees:
  - worktree-{task-id}: {task title} ({status: running | completed | failed})
    Branch: {issue-branch}
    PR: #{pr-number} ({review status})

Merge Queue:
  - PR #{N}: {task title} (awaiting review)

Recently Completed:
  - {task-id}: {title} -- merged via PR #{N}
```

If parallel execution is not enabled, skip this section.

### 6. Dependency Graph

Show the dependency tree with status indicators:

```
Dependency Graph
================
[x] Phase 1: Setup
[x] Phase 2: Foundational
  +-- [>] Phase 3: US1 (in_progress)
  +-- [ ] Phase 4: US2 (available)
  +-- [~] Phase 5: Polish (blocked by 3, 4)
```

Legend: `[x]` completed, `[>]` in progress, `[ ]` available, `[~]` blocked

### 7. Output

Present all sections in a clear format. Include:
- Total progress (e.g., "4/8 tasks complete, 1 running, 3 remaining")
- Next recommended action
- If all tasks complete, suggest merging the feature branch
