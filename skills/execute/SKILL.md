---
name: coco-execute
description: Execute the next available tracked task with TDD, pre-commit validation, PR workflow, AI code review, and issue tracker bridge sync. Primary execution interface for multi-session feature work.
---

# Coco Execute Skill

This skill delegates to the `/coco.execute` command, which implements the full 15-step TDD execution loop with PR workflow, AI code review, and issue tracker bridge sync.

## When to Use

- Implementing a feature that has been imported into the coco tracker as an epic
- Executing tasks from a `specs/{feature}/tasks.md` that has been converted to tracked tasks
- Any multi-session work where dependency tracking matters

## Alternatives

- For single-issue hotfixes or quick changes, use the `coco-hotfix` skill instead
- For autonomous execution until epic completion, use `/coco.loop`

## Execution

Run the `/coco.execute` command. It handles:

1. Pre-execution gate (tracker + issue tracker verification)
2. Dependency-aware task selection via `coco_tracker ready`
3. Issue branch creation (if `pr.enabled`)
4. Issue tracker bridge (start: "In Progress")
5. TDD implementation (RED -> GREEN -> verify)
6. Pre-commit validation (UI change detection)
7. Commit with issue key traceability
8. PR creation with issue ID (if `pr.enabled`)
9. AI code review via `code-reviewer` agent
10. Review-fix loop (max 3 iterations)
11. PR merge (if `pr.enabled`)
12. Tracker task close
13. Issue tracker bridge (complete: "Done" at PR merge)
14. Acceptance criteria verification
15. Next task check (loop or report completion)
