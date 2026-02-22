---
event: SessionStart
---

On session start, check for saved coco-workflow session memory and restore context.

## Steps

1. Check if `.coco/state/session-memory.md` exists. If not, do nothing.

2. Read `.coco/state/session-memory.md` and present a brief summary:

```
Resuming coco-workflow context:
- Branch: {branch}
- Active epic: {epic-id} ({name}) -- {progress}
- In-progress task: {task-id} ({title})
- Next ready: {task-id} ({title})
```

3. If there are in-progress tasks, suggest:
   - Verify the current state: `coco_tracker epic-status {epic-id}`
   - Continue execution: `/coco:execute` or `/coco:loop`

4. If the session memory is older than 24 hours, note this and suggest running `/coco:sync` to reconcile state.

## Important

- Keep the output brief -- just enough to orient the agent.
- Do NOT automatically start executing tasks. Just present the context.
- The session memory file is informational -- the tracker is the source of truth.
