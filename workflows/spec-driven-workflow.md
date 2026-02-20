# Spec-Driven Development Workflow

End-to-end reference for implementing features using the coco-workflow system.

## Overview

Spec-driven features follow a structured process from specification to implementation, with the coco tracker managing dependencies and optional issue tracker integration providing visibility.

## Three-Layer Architecture

| Layer | Tool | Role |
|-------|------|------|
| **Planning** | Coco commands | Produces `specs/{feature}/` with spec, plan, tasks |
| **Execution** | Coco tracker | Manages dependencies, session memory, task ordering |
| **Visibility** | Issue tracker | Mirrors task status for human tracking (optional) |

## Workflow Steps

### 1. Feature Specification

Create spec artifacts in `specs/{feature}/`:

- **spec.md** -- Feature specification with user stories and acceptance criteria (`/coco.spec`)
- **plan.md** -- Technical implementation plan (`/coco.plan`)
- **tasks.md** -- Dependency-ordered task list (`/coco.tasks`)
- **data-model.md** -- Data structures and relationships (if applicable)
- **contracts/** -- Service/protocol interfaces (if applicable)
- **research.md** -- Technical research and decisions (if applicable)

### 2. Import to Tracker

Use `/coco.import` to:
- Create tracker epic and tasks (one per sub-phase)
- Set dependency graph
- Create issue tracker project and issues (if configured)
- Link tracker tasks to issues via metadata

### 3. Execute

**Autonomous (recommended):** Use `/coco.loop` for hands-off execution with circuit breaker protection. Runs the full TDD cycle for every task until the epic is complete.

**Manual:** Use `/coco.execute` or the `coco-execute` skill for one task at a time with manual review between steps.

Either approach follows the same TDD flow per task:
- `coco_tracker ready` finds next unblocked task
- Claim task, update issue tracker status
- Implement with TDD (test first, then code)
- Pre-commit validation for UI changes
- Commit with issue key reference
- Close task, update issue tracker
- Loop until epic complete

### 4. Commit Standards

```
Brief description of changes. Completes ISSUE-KEY

Detailed explanation of what was implemented and why.

Task References:
- T001: Description
- T002: Description

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Format Rules:**
- Issue key at the END of first line (not beginning)
- "Completes" prefix before the issue key
- No brackets around the issue key

### 5. Progress Tracking

As work progresses:
1. Tracker task status updates automatically via execution loop
2. Issue tracker status syncs via bridge (if configured)
3. Use `/coco.status` for current state
4. Use `/coco.sync` to reconcile any drift

### 6. Feature Completion

When all sub-phases are done:
1. All tracker tasks closed
2. Issue tracker issues in final status
3. Full test suite passes
4. Create pull request
5. After merge: update issue tracker projects to completed

## When to Use What

- **Autonomous features**: Use `/coco.loop` (hands-off, circuit breaker, full epic in one command)
- **Manual features**: Use `/coco.execute` (step-by-step, manual review between tasks)
- **Single-issue hotfixes**: Use `coco-hotfix` skill (simpler, no epic overhead)
- **Quick changes**: Commit directly with `Completes ISSUE-KEY` format

## Parallel Execution

After foundation sub-phases complete, user story sub-phases can run in parallel. See `parallel-execution.md` for guidelines.
