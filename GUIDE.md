# Coco Guide

Comprehensive guide to the spec-driven development workflow.

## Overview

This workflow uses a unified pipeline to take features from description to merged code with minimal human interaction. The system is built around three goals:

1. **Per-phase autonomy** -- After an initial interview/specification step, the pipeline handles task decomposition, dependency resolution, TDD implementation, and commit operations end-to-end.
2. **Parallel execution** -- Independent user stories run concurrently across up to 3 agents, with file-ownership rules preventing conflicts.
3. **Comprehensive tracking** -- Every artifact, status change, commit, and test result is recorded in the coco tracker (execution state) and optionally in an issue tracker (visibility).

### Five-Layer Architecture

| Layer | Tool | Role |
|-------|------|------|
| **Discovery** | `/coco:prd`, `/coco:roadmap` | Produces PRD, analysis docs, and per-release roadmaps |
| **Planning** | Coco skills (`interview`, `design`, `tasks`, `import`) | Produces `specs/{feature}/` artifacts: discovery.md, design.md, tasks.md |
| **Execution** | Coco tracker (`lib/tracker.sh`) | Manages task state, dependency graphs, session memory |
| **Review** | `code-reviewer` agent | Reviews every PR against correctness, security, and the design's test budget |
| **Visibility** | Issue tracker (configurable) | Mirrors status for human tracking, commit linkage, project dashboards |

---

## Discovery Commands

| Command | Purpose | Input | Output |
|---------|---------|-------|--------|
| `/coco:prd` | Create, audit, or derive PRD | Product description, "audit", or "derive /path" | `docs/prd.md` |
| `/coco:roadmap` | Build prioritized roadmap | Release name (e.g., "v1.0") | `docs/roadmap/{release}.md` |

The Discovery Phase is optional -- projects can start directly with the `design` skill for individual features.

**When to use**: Starting a new product or major release, onboarding an existing project into coco-workflow, transitioning from ad-hoc development to structured roadmap execution, or aligning stakeholders on priorities before writing specs.

**Skip it when**: Working on a single known feature (start with the `design` skill), applying a hotfix (use the `hotfix` skill), or the roadmap already exists and is current.

**Workflow**: `/coco:prd` -> analysis docs (via `/coco:planning-session strategic`) -> `/coco:roadmap` -> `/coco:phase`

### Artifact Structure

```
docs/
  prd.md                              # Product Requirements Document
  analysis/                           # Analysis docs (one per topic)
    market-analysis.md
    technical-feasibility.md
    ...
  roadmap/                            # Per-release roadmap docs
    v1.0.md
    v1.1.md
    ...
```

All paths are configurable via the `discovery:` section in `.coco/config.yaml`:

```yaml
discovery:
  prd_path: "docs/prd.md"
  analysis_dir: "docs/analysis"
  roadmap_dir: "docs/roadmap"
```

### Roadmap Sync

The roadmap is automatically updated as work progresses:

| Event | Update |
|-------|--------|
| Feature completed (`/coco:loop` epic done) | Feature row Status -> "Complete", Spec column filled |
| Phase completed (`/coco:phase` all features merged) | Phase Status -> "Complete", Change Log entry added |

### Multiple Releases

Each release gets its own roadmap file (e.g., `docs/roadmap/v1.0.md`, `docs/roadmap/v1.1.md`). This supports parallel release planning, deferring features to future releases, and tracking completion across releases independently.

---

## Multi-Repo Projects

For multi-platform products with separate repositories (e.g., backend + web UI + iOS), Coco supports **derived PRDs**. A primary repo holds the canonical PRD; satellite repos derive platform-specific PRDs from it.

### The Derive Pattern

```
Backend repo (primary)              Web UI repo (satellite)           iOS repo (satellite)
───────────────────────             ───────────────────────           ──────────────────────
/coco:prd "Full product"            /coco:prd derive ../backend/...  /coco:prd derive ../backend/...
/coco:roadmap v1.0                  /coco:roadmap v1.0               /coco:roadmap v1.0
/coco:phase "Phase 1"               /coco:phase "Phase 1"            /coco:phase "Phase 2"
     │                                   │                                │
     ▼                                   ▼                                ▼
  Independent pipeline               Independent pipeline            Independent pipeline
```

### When to Use

- **Multi-platform products**: backend + web + mobile repos that share a product vision
- **Microservice architectures**: multiple service repos driven from one product spec
- **Monorepo alternatives**: when teams prefer separate repos but need shared planning

### Workflow

1. **Primary repo**: Create the canonical PRD with `/coco:prd` and roadmap with `/coco:roadmap`
2. **Satellite repo**: Run `/coco:prd derive ../primary/docs/prd.md` to select platform-relevant features
   - Optionally pass a phase name to pre-select features: `/coco:prd derive ../primary/docs/prd.md "Phase 2: iOS App"`
3. **Independent pipelines**: Each satellite runs its own `/coco:roadmap` -> `/coco:phase` -> `/coco:loop`

### Cross-Repo Dependency Tracking

Derived PRDs include a **Cross-Repo Dependencies** table listing APIs and services from other repos. The design template's **Cross-Repo Context** section lets designers document specific external dependencies per feature.

### Keeping Derived PRDs in Sync

When the source PRD is updated (new features, changed priorities), re-run `/coco:prd derive` in the satellite repo. The command detects the existing derived PRD and enters update mode -- showing new features from the source and letting you add or remove features while preserving the Change Log.

---

## Planning Skills

Planning steps are AI-selected skills (invisible in `/` autocomplete). They are invoked automatically by `/coco:phase`, `/coco:planning-session tactical`, or natural language requests.

| Skill | Purpose | Input | Output |
|-------|---------|-------|--------|
| `interview` | Pre-design discovery interview | Feature description | `discovery.md` (structured brief) |
| `design` | Create feature design (spec + implementation plan) with optional clarification | Feature description, `discovery.md` (optional) | `design.md`, `data-model.md` (optional) |
| `tasks` | Generate task list with consistency analysis | `design.md` | `tasks.md` with sub-phases + analysis report |
| `import` | Import tasks to tracker + issue tracker | `tasks.md` | Tracker epic + issues |

### Additional Planning Commands

| Command | Purpose |
|---------|---------|
| `/coco:constitution` | Create/update project constitution |

**Artifact structure** produced per feature:

```
specs/{feature}/
  discovery.md     # Pre-design context from interview (optional, Standard tier)
  design.md        # What to build, why, and how (merged spec + plan)
  tasks.md         # Ordered task list with sub-phases
  data-model.md    # Entity definitions and relationships (optional, data-heavy features only)
```

**Template system**: Uses templates from `.coco/templates/` (project overrides) or `coco-workflow/templates/` (defaults), and a project constitution at `.coco/memory/constitution.md`.

## Execution Commands

| Command | Purpose |
|---------|---------|
| `/coco:execute` | TDD + PR + AI review loop with issue tracker bridge |
| `/coco:loop` | Autonomous execution loop with circuit breaker |
| `/coco:sync` | Reconcile tracker and issue tracker state |
| `/coco:dashboard` | Compact visual progress dashboard with progress bar and dependency graph |
| `/coco:status` | Show detailed execution status and parallel opportunities |
| `/coco:test-audit` | Score the test suite against the value rubric, report low-value tests |
| `/coco:phase` | Orchestrate full pipeline for a roadmap phase |

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
- Always use `coco-tracker ready` to find the next task (respects dependency order)
- Tasks store `issue_key` metadata linking to issue tracker entries
- File ownership metadata (`owns_files`) prevents parallel agent conflicts

## Issue Tracker Integration

Configured in `.coco/config.yaml` under `issue_tracker`:

| Provider | How It Works |
|----------|-------------|
| **linear** | Uses Linear MCP for projects, issues, comments, status updates |
| **github** | Uses `gh` CLI for issues + GitHub Projects V2 for board-based tracking |
| **none** | No issue tracker; tracker-only workflow |

**Status mapping** (configurable in `status_map`):

| Tracker Status | Default Issue Status |
|---|---|
| `pending` | Backlog |
| `in_progress` | In Progress |
| `completed` | In Review |
| (PR merged) | Done |

### GitHub Projects V2

When `issue_tracker.github.use_projects` is `true` (default), the GitHub integration creates GitHub Projects V2 boards for visual status tracking:

- **One project per feature** -- created during `import`, with Status columns (Todo, In Progress, In Review, Done)
- **Phase-level projects** -- `/coco:roadmap` creates a project per roadmap phase
- **Field ID caching** -- opaque IDs for `gh project item-edit` are resolved once and cached in `.coco/state/gh-projects.json`
- **Automatic status transitions** -- `/coco:execute` and `/coco:loop` move issues between board columns
- **Backfill support** -- `/coco:sync` detects pre-existing issues without project association and offers to add them
- **Legacy fallback** -- set `use_projects: false` for label-based tracking (existing behavior)

---

## The `/coco:phase` Pipeline

The `/coco:phase` command orchestrates the full lifecycle for all features in a phase.

### Step-by-Step

**Phase 1: Audit**
1. Identify features for the phase
2. Check existing specs, code, tracker epics, and issue tracker projects
3. Classify each: **Already complete** (skip), **Partially built** (reduced spec), or **Greenfield** (full pipeline)

**Phase 2: Plan Presentation**
Present audit results to the user. This is the **last required human interaction**.

**Phase 3: Per-Feature Pipeline (Steps A-F)**

- **Step A -- Design**: If no `design.md`, run the `interview` skill (Standard tier, if no `discovery.md`) then the `design` skill
- **Step B -- Generate tasks**: If no `tasks.md`, run the `tasks` skill
- **Step C -- Import**: Run the `import` skill (tracker epic + dependencies + issue tracker)
- **Step D -- Create branch**: `git checkout -b {feature-name}`
- **Step E -- Execute**: Run `/coco:execute` for TDD loop
- **Step F -- Merge**: Merge to main, update issue tracker

**Phase 4: Completion**
Verify all epics closed, run full test suite, report summary.

---

## The `/coco:loop` Autonomous Loop

The `/coco:loop` command wraps `/coco:execute` in an autonomous loop that runs until the epic is complete or a safety condition triggers.

### How It Works

```
/coco:loop {epic-id}

  while tasks remain:
    0. Emit the ledger line (epic, done/total, blocked, iter, no-progress)
    1. coco-tracker ready -> next unblocked task(s)
    2. If parallel enabled + multiple ready tasks with non-overlapping owns_files:
       -> Dispatch task-executor agents in parallel (worktree isolation)
       -> Review and merge PRs after all agents complete
       (otherwise say which of the three conditions forced serial)
    3. Otherwise: Execute full TDD cycle serially (same as /coco:execute)
    4. Check progress (git commits); emit the resolution ledger line
    5. Every dashboard_every iterations -> render /coco:dashboard inline
    6. Check epic status (all tasks closed?)
    7. If no progress for N iterations -> circuit breaker
    8. If all done -> exit with summary
```

**The loop does not stop to report.** It runs to completion in a single turn.
Ending the turn is an exit, and the only exits are the ones in the table below.
It will not end a turn on a statement about what it is about to do next, and it
will not offer an optional checkpoint between tasks -- those read as courtesy but
cost you a message to clear. Interrupt it whenever you like; it will not
interrupt itself.

Progress is legible without stopping it. Every iteration opens and closes with a
ledger line:

```
[epic-003 "Set Editor" | 4/7 tasks | 2 blocked | iter 5/20 | no-progress 0/3] -> epic-003.4 "Selection model"
[epic-003 | 5/7 | iter 5/20] epic-003.4 merged | PR #82 (+120/-14, 3 tests)
```

### Circuit Breaker

Prevents infinite loops when a task can't be completed:

| Condition | Default | Behavior |
|-----------|---------|----------|
| Max iterations | 20 | Pauses loop, reports remaining tasks |
| No progress | 3 consecutive | Pauses loop, reports stuck task |
| Task error | **Off** (`pause_on_error: false`) | Skips the failed task, leaves it `in_progress`, takes the next ready one |

Configure in `.coco/config.yaml` under `loop:`.

`pause_on_error` defaulted to `true` before 0.5.0, which turned every flaky test
into a full stop needing a human. The no-progress breaker already catches a
genuinely stuck loop, so the first failure no longer needs to end the run. Set it
back to `true` if you would rather inspect each failure as it happens.

### When to Use

| Situation | Command |
|-----------|---------|
| Hands-off execution of an entire epic | `/coco:loop` |
| Step-by-step execution with manual review | `/coco:execute` |
| Full phase with multiple features | `/coco:phase` (which can use `/coco:loop` per feature) |

---

## Execution Deep-Dive

### Execution Loop (execute skill)

15 steps per sub-phase (steps 3, 8-11 gated on `pr.enabled`):

1. **Find next task**: `coco-tracker ready --json` returns next unblocked task
2. **Claim task**: `coco-tracker update <id> --status in_progress`
3. **Create issue branch**: `git checkout -b feature/{name}/{ISSUE-KEY}` (if PRs enabled)
4. **Bridge to issue tracker (start)**: Update issue to "In Progress"
5. **TDD implementation**: Write the tests the design's Test Strategy calls for (RED) -> implement (GREEN) -> verify
6. **Pre-commit validation**: Check staged files against UI patterns; invoke tester if matches
7. **Commit**: `Brief description. Completes {issue_key}` (traceability -- does NOT resolve issue)
8. **Create PR**: `gh pr create` with `Resolves {ISSUE-KEY}` in body; issue moves to "In Review"
9. **AI code review**: `code-reviewer` agent reviews PR diff, posts findings
10. **Review-fix loop**: Auto-fix critical findings, push, re-review (max 3 iterations)
11. **Merge PR**: `gh pr merge`; switch back to feature branch
12. **Close task**: `coco-tracker close <id>`
13. **Bridge to issue tracker (complete)**: Issue moves to "Done" (at PR merge)
14. **Verify acceptance criteria**: Check all criteria from tasks.md
15. **Check next**: Loop back to step 2 or report completion

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

## Test Value

TDD tells you to write a test before the code. It does not tell you *which* tests are worth writing, and left unchecked that produces suites that grow faster than the behavior they defend — slow, brittle, and expensive to refactor around.

Coco handles both directions with one mechanism: **the design commits to a test budget, and every later stage measures actual tests against it.**

### The budget

`design.md` carries a mandatory `## Test Strategy` section keyed on the `FR-###` requirement IDs:

```markdown
| FR | Test? | Level | Failure mode defended |
|----|-------|-------|-----------------------|
| FR-001 | yes | unit | expired token accepted as valid |
| FR-003 | no | -- | -- |

### Not worth testing
- **Label padding**: cosmetic, caught immediately in dev
```

Deciding what *not* to test is part of the design. `Failure mode defended` must name a concrete defect — "validates FR-001" is not a failure mode.

Light-tier features emit a degenerate form (a TDD verdict plus a not-worth-testing list, no table). They do not skip it — small features are where over-testing is most wasteful.

### How it is enforced

| Stage | What happens |
|-------|--------------|
| `tasks` | Generates one test task per `Test? = yes` FR. Consistency analysis pass **G** flags both under-testing and over-testing at HIGH severity |
| `import` | Carries `test_plan` into tracker task metadata |
| `execute` / `task-executor` | Writes exactly the planned tests. An unplanned test is **written and recorded**, never blocked — it appears in the PR body's `## Test Value` table with a justification |
| `code-reviewer` | Reads that table against the diff. Objectively bad tests are **critical** and block merge |
| `/coco:test-audit` | Sweeps the existing suite against the same rubric |

Write-time is advisory, review-time blocks. That keeps the executor from fighting itself mid-task while still putting a real gate where a human already looks.

### What blocks a merge

Only findings decidable from the diff alone — tautologies, mock-only assertions, tests of third-party libraries, exact duplicates, and tests of behavior the design explicitly excluded. Everything else about tests (naming, structure, "this should be a unit test") stays a warning.

That line matters. A blanket "test smells are critical" rule would burn all three review-fix iterations on ordinary PRs and escalate to a human every time, making the pipeline worse rather than better.

Configure with `testing.test_value_enforcement`: `blocking` (default), `advisory` (report as warnings), or `off`.

### Auditing an existing suite

```bash
/coco:test-audit                # whole repo
/coco:test-audit tests/auth     # scoped
/coco:test-audit --summary      # terminal only, no report file
```

The audit is **read-only** — it writes one report and never touches a test. Findings get IDs (`TA-1`, `TA-2`), and you act on them by asking Claude to "fix TA-1 and TA-4", which routes to the hotfix skill: one branch, one PR, one review per fix.

Verdicts are Keep, Keep-rewrite, Consolidate, Delete, and Escalate. Two safeguards are worth knowing:

- **Keep-rewrite over Delete.** A test that defends a real failure mode badly gets rewritten, not deleted. Deleting loses real coverage; leaving it loses nothing but misleads every later reader.
- **Escalate never auto-deletes.** A test introduced by a bugfix commit (`git log -S`) is proof the failure mode is real and was once undefended. So is the sole defender of a security or data-integrity property. Those go to a human.

The rubric lives at `templates/test-value-rubric.md` and is overridable per project at `.coco/templates/test-value-rubric.md`.

---

## Parallel Execution

### Worktree-Based Parallel Execution

When `loop.parallel.enabled` is `true`, `/coco:loop` dispatches `task-executor` agents with `isolation: worktree` for real parallel execution:

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

Each `task-executor` runs in its own git worktree with full filesystem isolation. After agents complete, `/coco:loop` reviews and merges each PR sequentially.

### Configuration

```yaml
loop:
  parallel:
    enabled: true            # Worktree-based parallel execution (default since 0.5.0)
    max_agents: 3            # Max concurrent task-executor agents
    max_agent_attempts: 2    # Agent gives up and reports rather than spinning
```

`max_agent_attempts` bounds an agent **from the inside**. The orchestrator cannot
interrupt a running one -- the dispatch call blocks until it returns -- so the
agent has to give up on its own and return a failure the parent can log. A
genuinely hung agent will still hold the batch; that is a known limit.

### Constraints

- **Max 3 concurrent agents** (configurable via `max_agents`)
- **Never parallelize same-file tasks** -- requires non-overlapping `owns_files` metadata
- **Foundation must be serial** (Sub-Phases 1-2)
- **Integration must be serial** (final polish sub-phase)
- File ownership generated by `tasks` skill, stored in tracker metadata by `import`
- Tasks without `owns_files` execute serially even when parallel is enabled -- the loop now says so in its ledger line rather than falling back silently

---

## Supporting Infrastructure

### Upgrading and Config Drift

Updating the plugin is two steps, and skipping either is silent.

`${CLAUDE_PLUGIN_ROOT}` resolves into a **version-keyed cache**
(`~/.claude/plugins/cache/{marketplace}/{plugin}/{version}/`), not the marketplace
git clone. The cache refreshes only when the version in `plugin.json` changes, so
`which coco-tracker` is the honest check -- the version segment in that path is
the build that is really running. A session already open keeps the version it
started with; open a new one.

`.coco/config.yaml` is copied from `config/coco.default.yaml` once, at setup, and
never consulted again. No command falls back to the plugin default. A project set
up before a default changed keeps the old value indefinitely, which is how
`pause_on_error: true` survived past the release that reversed it.

```
/coco:setup migrate
```

Adds keys the project is missing -- safe and silent, since an absent key already
behaves as its default -- and *reports* keys whose value differs from the current
default, applying a change only when you select it. It will not revert a
deliberate choice in bulk.

### Git Hooks

**`git-hooks/commit-msg.sh`** -- Validates commit message format per config
**`git-hooks/pre-commit.sh`** -- Build check and UI change detection per config

### No Bash Guardrail

Coco used to ship a `PreToolUse` hook that denied certain `coco-tracker` command forms. It was removed in 0.3.1. Every rule it still carried turned out to be defending a failure that does not happen — a tracker assigned to a shell variable works fine now that `coco-tracker` is on PATH, and a multiline command is handled by the tracker itself (newlines in titles collapse to spaces, and jq accepts newlines inside JSON).

A blocked call is recoverable — Claude rewrites and continues — but it is not free. It costs a turn, and consecutive blocks produce no commits, which starves `/coco:loop`'s no-progress counter until the circuit breaker exits the loop. That reads as "the hook stopped execution" even though nothing halted.

Where a real silent failure did exist, it was fixed at the source rather than policed at the harness: `coco-tracker create` and `update` now **fail** on malformed `--metadata` instead of substituting `{}` and exiting 0.

### Planning Sessions

| Type | Cadence | Purpose | Command |
|------|---------|---------|---------|
| **Strategic** | Quarterly | Roadmap review, prioritization | `/coco:planning-session strategic` |
| **Tactical** | Per-feature | Full design -> import pipeline | `/coco:planning-session tactical` |
| **Operational** | Weekly | Status sync, reprioritize | `/coco:planning-session operational` |
| **Triage** | Ad-hoc | Score bugs/features/feedback | `/coco:planning-triage` |

**Triage scoring:** `Score = (Impact + Urgency) / Effort`
- Score >= 3.0: Immediate
- Score 1.5-3.0: Backlog
- Score < 1.5: Defer

---

## Session Management

### Starting a Session

```bash
coco-tracker session-start "Working on {feature-name}"
coco-tracker epic-status {epic-id}
coco-tracker ready --json --epic {epic-id}
```

### Resuming Work

- `coco-tracker ready` always returns the correct next task based on dependencies
- Issue tracker reflects current progress for human visibility
- `/coco:execute` can be invoked at any point to continue

### Ending a Session

```bash
coco-tracker session-end
coco-tracker sync
git push
```

---

## Quick Reference

### Command Table (14 commands)

| Command | Purpose |
|---------|---------|
| `/coco:setup` | Initialize Coco (config, hooks, permissions). `migrate` reconciles an existing config against current defaults |
| `/coco:prd` | Create, audit, or derive Product Requirements Document |
| `/coco:roadmap` | Build prioritized, phased roadmap from PRD + analysis |
| `/coco:phase` | Orchestrate full pipeline for a phase |
| `/coco:loop` | Autonomous loop with circuit breaker |
| `/coco:execute` | TDD + PR + AI review loop with issue tracker bridge |
| `/coco:constitution` | Create/update project constitution |
| `/coco:dashboard` | Compact visual progress dashboard |
| `/coco:status` | Show detailed execution state and opportunities |
| `/coco:standup` | Daily standup -- done, in-progress, blocked, metrics |
| `/coco:sync` | Reconcile tracker and issue tracker state |
| `/coco:test-audit` | Score the test suite, report low-value tests |
| `/coco:planning-session` | Start a planning session |
| `/coco:planning-triage` | Score and disposition an item |

### Skill Table (6 skills, AI-selected)

| Skill | Purpose |
|-------|---------|
| `interview` | Pre-design discovery interview producing discovery.md |
| `design` | Create design.md (spec + plan) with optional clarification |
| `tasks` | Generate tasks.md with sub-phases + consistency analysis |
| `import` | Import tasks.md -> tracker + issue tracker |
| `hotfix` | Single-issue hotfix workflow |
| `execute` | Delegates to /coco:execute command |

### Common Workflows

**Full product (discovery to delivery):**
```
/coco:prd {description}         -->  Product Requirements Document
/coco:planning-session strategic      -->  analysis docs for open questions
/coco:roadmap v1.0               -->  prioritized, phased roadmap
/coco:phase "Phase 1: ..."       -->  autonomous pipeline per phase
```

**Full feature (multi-session):**
```
/coco:phase {phase-description}  -->  autonomous pipeline
```

**Single feature (automated pipeline):**
```
/coco:planning-session tactical   -->  runs interview -> design -> tasks -> import
/coco:loop                   -->  autonomous until epic complete
```

**Single feature (manual step-by-step):**
```
/coco:planning-session tactical   -->  runs skills for interview, design, tasks, import
/coco:execute                -->  one task at a time
```

**Hotfix (single-issue):**
```
# Uses the hotfix skill
```

**Sync drift:**
```
/coco:sync
```

### Routing Decision

| Scenario | Approach |
|----------|----------|
| New product or major release | `/coco:prd` -> `/coco:roadmap` -> `/coco:phase` |
| Multi-repo satellite | `/coco:prd derive /path/to/source` -> `/coco:roadmap` -> `/coco:phase` |
| Existing project onboarding | `/coco:prd audit` -> `/coco:roadmap` |
| Autonomous feature (hands-off) | `/coco:loop` -- runs until epic complete |
| Multi-session feature (manual) | `/coco:execute` -- one task per invocation |
| Single-issue hotfix | hotfix skill |
| Phase orchestration | `/coco:phase` |
| Sync drift | `/coco:sync` |
| Test suite feels bloated or slow | `/coco:test-audit`, then hotfix skill per finding |
