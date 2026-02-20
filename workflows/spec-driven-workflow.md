# Spec-Driven Development Workflow

End-to-end reference for implementing features using the coco-workflow system.

## Overview

Spec-driven features follow a structured process from specification to merged code, with the coco tracker managing dependencies, PRs providing review gates, and optional issue tracker integration providing visibility.

## Three-Layer Architecture

| Layer | Tool | Role |
|-------|------|------|
| **Planning** | Coco skills | Produces `specs/{feature}/` with spec, plan, tasks |
| **Execution** | Coco tracker | Manages dependencies, session memory, task ordering |
| **Review** | PRs + code-reviewer agent | AI code review on every PR before merge |
| **Visibility** | Issue tracker | Mirrors task status for human tracking (optional) |

## Branching Model

When `pr.enabled` is true (default), the system uses a two-tier branching model:

```
main
  └── feature/{name}                    (one per epic)
        ├── feature/{name}/{ISSUE-1}    (one per task, PR -> feature branch)
        ├── feature/{name}/{ISSUE-2}
        └── ...
  └── PR: feature/{name} -> main        (one per feature)
```

## Workflow Steps

### 1. Feature Specification

Create spec artifacts in `specs/{feature}/`:

- **spec.md** -- Feature specification with user stories and acceptance criteria (`coco-spec` skill)
- **plan.md** -- Technical implementation plan (`coco-plan` skill)
- **tasks.md** -- Dependency-ordered task list (`coco-tasks` skill)
- **data-model.md** -- Data structures and relationships (if applicable)
- **contracts/** -- Service/protocol interfaces (if applicable)
- **research.md** -- Technical research and decisions (if applicable)

The `coco-spec` skill creates the feature branch (`feature/{name}`) automatically.

### 2. Import to Tracker

Use the `coco-import` skill to:
- Create tracker epic and tasks (one per sub-phase)
- Set dependency graph
- Create issue tracker project and issues (if configured)
- Link tracker tasks to issues via metadata
- Store feature branch name in task metadata

### 3. Execute

**Autonomous (recommended):** Use `/coco.loop` for hands-off execution with circuit breaker protection. Runs the full TDD + PR + review cycle for every task until the epic is complete.

**Manual:** Use `/coco.execute` or the `coco-execute` skill for one task at a time with manual review between steps.

Either approach follows the same flow per task:
1. `coco_tracker ready` finds next unblocked task
2. Create issue branch off feature branch (if `pr.enabled`)
3. Claim task, update issue tracker to "In Progress"
4. Implement with TDD (test first, then code)
5. Pre-commit validation for UI changes
6. Commit with `Completes {ISSUE-KEY}` (traceability only -- does NOT resolve issue)
7. Create PR from issue branch to feature branch (if `pr.enabled`)
8. AI code review via `code-reviewer` agent
9. Fix critical findings, re-review (up to 3 iterations)
10. Merge PR -- **this is when the issue resolves** (moves to "Done")
11. Close tracker task
12. Loop until epic complete

### 4. Commit Standards

**Implementation commits:**
```
Brief description of changes. Completes ISSUE-KEY

Detailed explanation of what was implemented and why.

Task References:
- T001: Description
- T002: Description

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Review-fix commits:**
```
Address review feedback (iteration N). Ref ISSUE-KEY

Fixes:
- CR-1: Description of fix

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Format Rules:**
- Issue key at the END of first line (not beginning)
- `Completes` prefix for implementation commits, `Ref` prefix for review fixes
- No brackets around the issue key

### 5. PR and Code Review

Every PR goes through AI code review before merge:

1. **PR created** with issue ID in body (`Resolves {ISSUE-KEY}` or `Closes #{N}`)
2. **code-reviewer agent** reads the diff, posts structured findings
3. Findings classified as **critical** (blocks merge) or **warning** (advisory)
4. Critical findings are auto-fixed, pushed, and re-reviewed (max 3 iterations)
5. After approval, PR is merged

Issue status transitions:
- Commit pushed: issue stays "In Progress"
- PR created: issue moves to "In Review"
- PR merged: issue moves to "Done"

### 6. Feature Completion

When all tasks are done, `/coco.loop` (or manual flow) creates a feature PR to main:

1. All issue PRs merged to feature branch
2. Feature PR created: `feature/{name}` -> `main`
3. Full-feature AI code review (reviews entire feature diff)
4. Critical findings fixed on feature branch
5. PR merged to main
6. All issues updated to final status ("Done")
7. Feature branch deleted

## When to Use What

- **Autonomous features**: Use `/coco.loop` (hands-off, PRs, AI review, circuit breaker)
- **Manual features**: Use `/coco.execute` (step-by-step, manual review between tasks)
- **Single-issue hotfixes**: Use `coco-hotfix` skill (simpler, optional PR)
- **Quick changes**: Commit directly with `Completes ISSUE-KEY` format

## Parallel Execution

After foundation sub-phases complete, user story sub-phases can run in parallel. See `parallel-execution.md` for guidelines.
