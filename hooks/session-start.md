---
event: SessionStart
---

On session start, check if Coco is initialized, then restore session context if available.

## Steps

0. **First-run detection**: Check if `.coco/config.yaml` exists.
   - If it does NOT exist: output the following message and **stop** (do not continue to step 1):
     ```
     Coco plugin detected but not initialized. Run /coco:setup to get started.
     ```
   - If it exists: continue to step 1.

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
