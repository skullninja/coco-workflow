# Import Workflow

Convert a completed `tasks.md` into a tracked epic with optional issue tracker integration.

**CRITICAL**: This workflow MUST be completed in full before execution can begin. If an issue tracker is configured, the metadata linkage steps are required for the execution loop's bridge to function.

## Prerequisites

- Completed `specs/{feature}/tasks.md` with sub-phases and dependency info
- `.coco/config.yaml` with project configuration

## Process

### Step 1: Parse tasks.md

Read `specs/{feature}/tasks.md` and extract:
1. **Feature name** from the `# Tasks:` header
2. **Sub-Phases** -- each `## Sub-Phase N:` section becomes a task
3. **Parallel markers** -- `[P]` tasks within a sub-phase
4. **Dependencies** -- parse "Dependencies & Execution Order" section

### Step 2: Create Tracker Epic

```bash
coco_tracker epic-create "{feature-name}"
```

### Step 3: Create Tracker Tasks (one per sub-phase)

For each sub-phase, create a task with the sub-phase description and task list.

### Step 4: Set Dependencies

Map the dependency graph from tasks.md:
- Setup -> Foundational
- Foundational -> All user stories
- All user stories -> Polish

### Step 5: Issue Tracker Bridge (if configured)

Read `issue_tracker.provider` from `.coco/config.yaml`:

- **linear**: Create project and issues via Linear MCP, store keys in metadata
- **github**: Create issues via `gh`, store numbers in metadata
- **none**: Skip

### Step 6: Verify Gate

All must pass before proceeding to execution:
- Every tracker task exists with correct dependencies
- If issue tracker configured: every task has `issue_key` in metadata
- Dependencies match tasks.md ordering

## Output

- Epic ID and name
- Number of tasks created
- Dependency graph summary
- Issue tracker project/issues (if applicable)
- First available task (`coco_tracker ready`)
