# Parallel Execution Workflow

Guidelines for running multiple implementation tasks concurrently within an epic.

## Principles

1. **Foundation first (serial)**: Sub-Phases 1-2 (Setup + Foundational) must complete before parallelizing
2. **User stories (parallel)**: Sub-Phases 3+ can run concurrently after foundation is complete
3. **Integration (serial)**: Final polish sub-phase runs after all stories complete
4. **Safety first**: Never parallelize tasks that modify the same files

## When to Parallelize

- Multiple user story sub-phases are unblocked
- Tasks within a sub-phase are marked `[P]` (different files, no dependencies)
- Multiple agents are available for concurrent work

## Constraints

### Hard Rules
- **Max 3 concurrent agents** -- More causes merge conflicts and context thrashing
- **Never parallelize same-file tasks** -- One agent per file at a time
- **Never parallelize sequential tasks within a user story** -- Respect within-story ordering
- **Foundation must be serial** -- Sub-Phases 1-2 always run sequentially

### File Ownership

Each parallel agent claims ownership of specific files. Track ownership in task metadata:

```bash
coco_tracker update {task-id} --metadata '{"owns_files": ["src/feature-a/**", "tests/feature-a/**"]}'
```

Before starting a task, check that no other in-progress task owns overlapping files:

```bash
coco_tracker list --status in_progress --json
```

### Conflict Resolution

If two agents need the same file:
1. **First-claim-wins**: The agent that started first keeps the file
2. **Second agent pauses**: Wait for first agent to commit
3. **Rebase**: Second agent pulls latest changes before continuing

## Execution Flow

```
Sub-Phase 1: Setup ---------> Sub-Phase 2: Foundational
                                         |
                           +-------------+-------------+
                           v             v             v
                     SP 3: US1     SP 4: US2     SP 5: US3
                     (Agent A)    (Agent B)    (Agent C)
                           |             |             |
                           +-------------+-------------+
                                         v
                                 Sub-Phase N: Polish
```

## Starting Parallel Work

1. Verify foundation is complete:
   ```bash
   coco_tracker list --json --epic {epic-id}
   # All Sub-Phase 1-2 tasks should be "completed"
   ```

2. Identify available parallel tasks:
   ```bash
   coco_tracker ready --json --epic {epic-id}
   ```

3. For each parallel agent, assign a task with file ownership

4. Each agent follows the `coco-execute` skill independently

5. After all parallel tasks complete, proceed to polish sub-phase

## Monitoring

Use `/coco.status` to see:
- Which tasks are running concurrently
- File ownership map
- Available parallelization opportunities
- Blocked tasks and their dependencies
