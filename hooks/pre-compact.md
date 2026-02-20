---
event: PreCompact
---

Before conversation compaction, capture coco-workflow session state so it can be restored after compaction.

## Steps

1. Check if `.coco/config.yaml` exists. If not, do nothing -- this project doesn't use coco-workflow.

2. Source the tracker and capture current state:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"
```

3. Gather the following information:
   - **Active epics**: `coco_tracker list --json | jq -s '[.[] | select(.type == "epic" and .status != "completed")]'`
   - **In-progress tasks**: `coco_tracker list --json | jq -s '[.[] | select(.type == "task" and .status == "in_progress")]'`
   - **Current git branch**: `git branch --show-current`
   - **Next ready task**: `coco_tracker ready --json` (for the most recent open epic)

4. Write the state to `.coco/state/session-memory.md`:

```markdown
# Coco Session Memory

**Captured**: {timestamp}
**Branch**: {current branch}

## Active Epics

| Epic ID | Name | Progress |
|---------|------|----------|
| {id} | {name} | {completed}/{total} tasks |

## In-Progress Tasks

| Task ID | Epic | Title | Issue Key |
|---------|------|-------|-----------|
| {id} | {epic} | {title} | {issue_key from metadata} |

## Next Ready Task

- **{task-id}**: {title}

## Context Notes

{Summarize what was being worked on in the current conversation -- key decisions made, blockers encountered, what step of the execution loop we're in}
```

5. Confirm the file was written.

## Important

- Keep the memory file concise -- it will be read back on session start.
- The "Context Notes" section should capture conversation-specific context that the tracker doesn't store (decisions, approach taken, blockers).
- Do NOT capture code content -- only references and state.
