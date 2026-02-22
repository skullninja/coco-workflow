# Parallel Execution Workflow

Guidelines for running multiple implementation tasks concurrently within an epic using git worktree isolation.

## Principles

1. **Foundation first (serial)**: Sub-Phases 1-2 (Setup + Foundational) must complete before parallelizing
2. **User stories (parallel)**: Sub-Phases 3+ can run concurrently after foundation is complete
3. **Integration (serial)**: Final polish sub-phase runs after all stories complete
4. **Safety first**: Never parallelize tasks that modify the same files
5. **Worktree isolation**: Each parallel agent runs in its own git worktree, preventing filesystem conflicts

## Configuration

Enable parallel execution in `.coco/config.yaml`:

```yaml
loop:
  parallel:
    enabled: true       # Enable worktree-based parallel execution
    max_agents: 3       # Max concurrent task-executor agents
```

## When to Parallelize

- Multiple user story sub-phases are unblocked (`coco_tracker ready` returns 2+ tasks)
- Tasks have non-overlapping `owns_files` metadata
- `loop.parallel.enabled` is true in config

## Constraints

### Hard Rules
- **Max 3 concurrent agents** -- More causes merge conflicts and context thrashing
- **Never parallelize same-file tasks** -- `owns_files` metadata must not overlap
- **Never parallelize sequential tasks within a user story** -- Respect within-story ordering
- **Foundation must be serial** -- Sub-Phases 1-2 always run sequentially
- **Tasks without `owns_files` execute serially** -- Parallel requires explicit file ownership

### File Ownership

File ownership is determined during task generation (`coco-tasks` skill) and stored in tracker metadata during import (`coco-import` skill):

```bash
coco_tracker create --epic "{epic-id}" \
  --title "Sub-Phase 3: User Auth" \
  --metadata '{"owns_files": ["src/auth/**", "tests/auth/**"]}'
```

`/coco.loop` checks for overlap before dispatching parallel agents.

### Conflict Resolution

With worktree isolation, filesystem conflicts are eliminated. Merge conflicts are handled by the parent `/coco.loop`:

1. Each `task-executor` agent works in its own worktree -- no shared filesystem state
2. After agents complete, the parent merges PRs sequentially into the feature branch
3. If a merge conflict occurs, the parent resolves it or flags for manual intervention

## Execution Flow

```
Sub-Phase 1: Setup ---------> Sub-Phase 2: Foundational
                                         |
                           +-------------+-------------+
                           v             v             v
                     SP 3: US1     SP 4: US2     SP 5: US3
                   (task-executor) (task-executor) (task-executor)
                   [worktree-1]   [worktree-2]   [worktree-3]
                           |             |             |
                           v             v             v
                     PR -> feature  PR -> feature  PR -> feature
                           |             |             |
                           +--- review ---+--- review -+
                                         v
                                 Sub-Phase N: Polish
```

## How It Works

### 1. `/coco.loop` detects parallel opportunity

```bash
coco_tracker ready --json --epic {epic-id}
# Returns 2+ tasks with non-overlapping owns_files
```

### 2. Dispatch `task-executor` agents

`/coco.loop` spawns up to `max_agents` `task-executor` agents via the `Task` tool in a single message (multiple tool calls for true parallelism).

Each `task-executor` agent:
- Has `isolation: worktree` in its frontmatter -- Claude Code automatically creates a git worktree
- Receives: task ID, epic ID, feature branch name, config values
- Works in complete filesystem isolation

### 3. Each agent executes independently

In its isolated worktree, each `task-executor`:
1. Claims the task in the tracker
2. Creates an issue branch from the feature branch
3. Updates issue tracker status to "In Progress"
4. Implements the task (TDD)
5. Commits and creates a PR targeting the feature branch
6. Updates issue tracker status to "In Review"
7. Closes the tracker task
8. Returns: task ID, commit hash, PR number, status

The agent does **not** run AI code review or merge the PR -- the parent handles that.

### 4. Parent handles review and merge

After all agents complete, `/coco.loop`:
1. Pulls the feature branch
2. For each successful agent's PR:
   - Invokes `code-reviewer` agent
   - Handles review-fix loop (if changes requested)
   - Merges the PR
   - Updates issue tracker to "Done"
3. For failed agents: marks task for retry in next iteration

### 5. Continue loop

After the parallel batch is processed, `/coco.loop` checks for more ready tasks and repeats.

## Monitoring

Use `/coco.status` to see:
- Which worktrees are running (active `task-executor` agents)
- Agent status per worktree (in-progress, completed, failed)
- File ownership map per active task
- Merge queue (completed worktrees waiting for review)
- Available parallelization opportunities
- Blocked tasks and their dependencies

## Fallback Behavior

Parallel execution gracefully degrades to serial when:
- `loop.parallel.enabled` is false (default)
- Only one task is ready
- Ready tasks lack `owns_files` metadata
- Ready tasks have overlapping file ownership

In all these cases, `/coco.loop` falls through to the standard serial execution path.
