# Coco Workflow Guide

Comprehensive guide to the spec-driven development workflow.

## Overview

This workflow uses a unified pipeline to take features from description to merged code with minimal human interaction. The system is built around three goals:

1. **Per-phase autonomy** -- After an initial interview/specification step, the pipeline handles task decomposition, dependency resolution, TDD implementation, and commit operations end-to-end.
2. **Parallel execution** -- Independent user stories run concurrently across up to 3 agents, with file-ownership rules preventing conflicts.
3. **Comprehensive tracking** -- Every artifact, status change, commit, and test result is recorded in the coco tracker (execution state) and optionally in an issue tracker (visibility).

### Three-Layer Architecture

| Layer | Tool | Role |
|-------|------|------|
| **Planning** | Coco commands (`/coco.*`) | Produces `specs/{feature}/` artifacts: spec.md, plan.md, tasks.md |
| **Execution** | Coco tracker (`lib/tracker.sh`) | Manages task state, dependency graphs, session memory |
| **Visibility** | Issue tracker (configurable) | Mirrors status for human tracking, commit linkage, project dashboards |

---

## Planning Commands

| Command | Purpose | Input | Output |
|---------|---------|-------|--------|
| `/coco.spec` | Create feature specification | Feature description | `spec.md` |
| `/coco.clarify` | Reduce ambiguity (max 5 questions) | Existing `spec.md` | Updated `spec.md` |
| `/coco.plan` | Generate implementation plan | `spec.md` | `plan.md`, `research.md`, `data-model.md`, `contracts/` |
| `/coco.tasks` | Generate task list (auto-analyzes) | `spec.md` + `plan.md` | `tasks.md` with sub-phases |
| `/coco.analyze` | Cross-artifact consistency analysis | All artifacts | Analysis report |
| `/coco.constitution` | Create/update project constitution | Principle inputs | `.coco/memory/constitution.md` |

**Artifact structure** produced per feature:

```
specs/{feature}/
  spec.md          # What to build and why (business-focused)
  plan.md          # How to build it (technical decisions)
  tasks.md         # Ordered task list with sub-phases
  data-model.md    # Entity definitions and relationships
  research.md      # Technical research and decisions
  contracts/       # Service/protocol interfaces
  quickstart.md    # Quick reference for developers
  checklists/      # Requirements quality checklists
```

**Template system**: Uses templates from `.coco/templates/` (project overrides) or `coco-workflow/templates/` (defaults), and a project constitution at `.coco/memory/constitution.md`.

## Execution Commands

| Command | Purpose |
|---------|---------|
| `/coco.import` | Import tasks.md -> tracker epic + issue tracker |
| `/coco.execute` | TDD execution loop with issue tracker bridge |
| `/coco.loop` | Autonomous execution loop with circuit breaker |
| `/coco.sync` | Reconcile tracker and issue tracker state |
| `/coco.status` | Show execution status and parallel opportunities |
| `/coco.phase` | Orchestrate full pipeline for a roadmap phase |

## Coco Tracker

The built-in tracker (`lib/tracker.sh`) provides persistent task state using JSONL + jq with zero external dependencies.

**Core capabilities:**

| Capability | Commands | Description |
|------------|----------|-------------|
| Task management | `create`, `update`, `close` | Create, claim, and complete tasks |
| Dependency graphs | `dep-add`, `ready` | Define dependencies; `ready` returns next unblocked task |
| Epic management | `epic-create`, `epic-status`, `epic-close` | Group tasks into features |
| Session memory | `session-start`, `session-end` | Track work across sessions |
| Metadata | `update --metadata '{...}'` | Store arbitrary data (issue keys, file ownership) |
| Sync | `sync` | Commit tracker state via git |

**Key patterns:**
- Always use `coco_tracker ready` to find the next task (respects dependency order)
- Tasks store `issue_key` metadata linking to issue tracker entries
- File ownership metadata (`owns_files`) prevents parallel agent conflicts

## Issue Tracker Integration

Configured in `.coco/config.yaml` under `issue_tracker`:

| Provider | How It Works |
|----------|-------------|
| **linear** | Uses Linear MCP for projects, issues, comments, status updates |
| **github** | Uses `gh` CLI for issues, labels, comments |
| **none** | No issue tracker; tracker-only workflow |

**Status mapping** (configurable in `status_map`):

| Tracker Status | Default Issue Status |
|---|---|
| `pending` | Backlog |
| `in_progress` | In Progress |
| `completed` | In Review |
| (PR merged) | Done |

---

## The `/coco.phase` Pipeline

The `/coco.phase` command orchestrates the full lifecycle for all features in a phase.

### Step-by-Step

**Phase 1: Audit**
1. Identify features for the phase
2. Check existing specs, code, tracker epics, and issue tracker projects
3. Classify each: **Already complete** (skip), **Partially built** (reduced spec), or **Greenfield** (full pipeline)

**Phase 2: Plan Presentation**
Present audit results to the user. This is the **last required human interaction**.

**Phase 3: Per-Spec Pipeline (Steps A-G)**

- **Step A -- Specify**: If no `spec.md`, run `/interview` or `/coco.spec`
- **Step B -- Plan**: If no `plan.md`, run `/coco.plan`
- **Step C -- Generate tasks**: If no `tasks.md`, run `/coco.tasks`
- **Step D -- Import**: Run `/coco.import` (tracker epic + dependencies + issue tracker)
- **Step E -- Create branch**: `git checkout -b {feature-name}`
- **Step F -- Execute**: Run `/coco.execute` for TDD loop
- **Step G -- Merge**: Merge to main, update issue tracker

**Phase 4: Completion**
Verify all epics closed, run full test suite, report summary.

---

## The `/coco.loop` Autonomous Loop

The `/coco.loop` command wraps `/coco.execute` in an autonomous loop that runs until the epic is complete or a safety condition triggers.

### How It Works

```
/coco.loop {epic-id}

  while tasks remain:
    1. coco_tracker ready -> next unblocked task
    2. Execute full TDD cycle (same as /coco.execute)
    3. Check progress (git commits)
    4. Check epic status (all tasks closed?)
    5. If no progress for N iterations -> circuit breaker
    6. If all done -> exit with summary
```

### Circuit Breaker

Prevents infinite loops when a task can't be completed:

| Condition | Default | Behavior |
|-----------|---------|----------|
| Max iterations | 20 | Pauses loop, reports remaining tasks |
| No progress | 3 consecutive | Pauses loop, reports stuck task |
| Task error | On by default | Pauses loop on test/build failure |

Configure in `.coco/config.yaml` under `loop:`.

### When to Use

| Situation | Command |
|-----------|---------|
| Hands-off execution of an entire epic | `/coco.loop` |
| Step-by-step execution with manual review | `/coco.execute` |
| Full phase with multiple features | `/coco.phase` (which can use `/coco.loop` per feature) |

---

## Execution Deep-Dive

### TDD Loop (coco-execute skill)

10 steps per sub-phase:

1. **Find next task**: `coco_tracker ready --json` returns next unblocked task
2. **Claim task**: `coco_tracker update <id> --status in_progress`
3. **Bridge to issue tracker (claim)**: Update issue to "In Progress"
4. **TDD implementation**: Write tests (RED) -> implement (GREEN) -> verify
5. **Pre-commit validation**: Check staged files against UI patterns; invoke tester if matches
6. **Commit**: `Brief description. Completes {issue_key}` with task references
7. **Close task**: `coco_tracker close <id>`
8. **Bridge to issue tracker (complete)**: Update to "In Review", post summary
9. **Verify acceptance criteria**: Check all criteria from tasks.md
10. **Check next**: Loop back to step 2 or report completion

### Commit Conventions

```
Brief description. Completes {ISSUE-KEY}

Detailed explanation.

Task References:
- T001: Description

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Rules enforced by commit-msg hook:**
- Issue key at END of first line with `Completes` prefix
- Bracket format `[ISSUE-X]` is rejected
- Exempt patterns configurable in `.coco/config.yaml`

---

## Parallel Execution

### Pattern

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

### Constraints

- **Max 3 concurrent agents**
- **Never parallelize same-file tasks**
- **Foundation must be serial** (Sub-Phases 1-2)
- **Integration must be serial** (final polish sub-phase)
- File ownership tracked via task metadata

---

## Supporting Infrastructure

### Git Hooks

**`hooks/commit-msg.sh`** -- Validates commit message format per config
**`hooks/pre-commit.sh`** -- Build check and UI change detection per config

### Planning Sessions

| Type | Cadence | Purpose | Command |
|------|---------|---------|---------|
| **Strategic** | Quarterly | Roadmap review, prioritization | `/planning-session strategic` |
| **Tactical** | Per-feature | Full spec -> import pipeline | `/planning-session tactical` |
| **Operational** | Weekly | Status sync, reprioritize | `/planning-session operational` |
| **Triage** | Ad-hoc | Score bugs/features/feedback | `/planning-triage` |

**Triage scoring:** `Score = (Impact + Urgency) / Effort`
- Score >= 3.0: Immediate
- Score 1.5-3.0: Backlog
- Score < 1.5: Defer

---

## Session Management

### Starting a Session

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"
coco_tracker session-start "Working on {feature-name}"
coco_tracker epic-status {epic-id}
coco_tracker ready --json --epic {epic-id}
```

### Resuming Work

- `coco_tracker ready` always returns the correct next task based on dependencies
- Issue tracker reflects current progress for human visibility
- `/coco.execute` can be invoked at any point to continue

### Ending a Session

```bash
coco_tracker session-end
coco_tracker sync
git push
```

---

## Quick Reference

### Command Table

| Command | Purpose |
|---------|---------|
| `/coco.phase` | Orchestrate full pipeline for a phase |
| `/interview` | In-depth interview to create feature spec |
| `/coco.spec` | Create spec.md from feature description |
| `/coco.clarify` | Resolve ambiguities (max 5 questions) |
| `/coco.plan` | Generate plan.md + research + data model |
| `/coco.tasks` | Generate tasks.md with sub-phases (auto-analyzes) |
| `/coco.analyze` | Cross-artifact consistency analysis |
| `/coco.constitution` | Create/update project constitution |
| `/coco.import` | Import tasks.md -> tracker + issue tracker |
| `/coco.execute` | TDD execution loop with issue tracker bridge |
| `/coco.loop` | Autonomous loop with circuit breaker |
| `/coco.sync` | Reconcile tracker and issue tracker state |
| `/coco.status` | Show execution state and opportunities |
| `/planning-session` | Start a planning session |
| `/planning-triage` | Score and disposition an item |

### Common Workflows

**Full feature (multi-session):**
```
/coco.phase {phase-description}  -->  autonomous pipeline
```

**Single feature (autonomous):**
```
/coco.spec {description}
/coco.plan
/coco.tasks
/coco.import
/coco.loop          -->  autonomous until epic complete
```

**Single feature (manual):**
```
/coco.spec {description}
/coco.clarify
/coco.plan
/coco.tasks
/coco.import
/coco.execute       -->  one task at a time
```

**Hotfix (single-issue):**
```
# Uses the coco-hotfix skill
```

**Sync drift:**
```
/coco.sync
```

### Routing Decision

| Scenario | Approach |
|----------|----------|
| Autonomous feature (hands-off) | `/coco.loop` -- runs until epic complete |
| Multi-session feature (manual) | `/coco.execute` -- one task per invocation |
| Single-issue hotfix | coco-hotfix skill |
| Phase orchestration | `/coco.phase` |
| Sync drift | `/coco.sync` |
