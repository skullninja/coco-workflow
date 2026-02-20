<p align="center">
  <img src="assets/coco.png" alt="Coco" width="200">
</p>

# coco-workflow

Named after **Coco**, a toy poodle who is small, fiercely opinionated, and relentlessly autonomous -- much like this plugin. She chases birds with the same energy coco-workflow chases tasks through a dependency graph: methodically, loudly, and without asking for permission. When she's not barking at strangers or sneaking cheese, she's napping -- recharging for the next burst of chaotic productivity.

Spec-driven development workflow for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Takes features from description to merged code with minimal human interaction.

## What It Does

Coco-workflow unifies planning, task tracking, PR workflow with AI code review, and issue tracker integration into a single Claude Code plugin. After an initial specification step, the pipeline handles task decomposition, dependency resolution, TDD implementation, PR creation, AI code review, and issue tracker sync autonomously. Like its namesake, it's small, zero-dependency, and will not stop until the job is done (or the circuit breaker fires).

### Architecture

| Layer | Tool | Role |
|-------|------|------|
| **Discovery** | `/coco.prd`, `/coco.roadmap` | Produces PRD, analysis docs, and prioritized roadmaps |
| **Planning** | Skills (`coco-spec`, `coco-plan`, `coco-tasks`) | Produces spec, plan, and task artifacts |
| **Execution** | Built-in tracker (`lib/tracker.sh`) | Manages dependencies, session memory, task ordering |
| **Review** | PRs + code-reviewer agent | AI code review on every PR before merge |
| **Visibility** | Issue tracker (configurable) | Mirrors status for human tracking (Linear, GitHub, or none) |

## Installation

Add as a git submodule to your project:

```bash
git submodule add <repo-url> coco-workflow
bash coco-workflow/scripts/setup.sh
```

`setup.sh` creates the `.coco/` directory structure and installs git hooks. Claude Code auto-discovers the plugin via `coco-workflow/plugin.json`.

### Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- `jq` (for the built-in task tracker)
- `git`
- `gh` (GitHub CLI -- for PR workflow; optional if `pr.enabled: false`)

No daemon, no database, no additional CLI tools.

## Quick Start

### Full Pipeline (Discovery to Delivery)

```
/coco.prd "My product description"       # Create Product Requirements Document
/planning-session strategic              # Create analysis docs for open questions
/coco.roadmap v1.0                       # Build prioritized, phased roadmap
/coco.phase "Phase 1: Foundation"        # Orchestrate all features in a phase
```

### Single Feature Pipeline

The pipeline steps (spec, plan, tasks, import) are now automated via skills that AI selects automatically. Use `/planning-session tactical` or describe the feature naturally:

```
/planning-session tactical               # Guided: spec -> plan -> tasks -> import
/coco.loop                               # Autonomous execution until done
```

### Phase Orchestration (Multiple Features)

```
/coco.phase "Phase 1: Foundation"        # Reads roadmap, orchestrates all features
```

### Single-Issue Hotfix

```
# Uses the coco-hotfix skill -- no epic overhead
```

## Commands (12)

| Command | Purpose |
|---------|---------|
| `/coco.prd` | Create or audit Product Requirements Document |
| `/coco.roadmap` | Build prioritized, phased roadmap from PRD + analysis |
| `/coco.phase` | Orchestrate full pipeline for a roadmap phase |
| `/coco.loop` | Autonomous execution loop with circuit breaker |
| `/coco.execute` | TDD execution loop (one task at a time) |
| `/coco.constitution` | Manage project constitution |
| `/coco.status` | Show execution status and parallel opportunities |
| `/coco.standup` | Daily standup summary with done/in-progress/blocked/metrics |
| `/coco.sync` | Reconcile tracker and issue tracker state |
| `/planning-session` | Structured planning sessions with adaptive complexity routing |
| `/planning-triage` | Score and disposition bugs/features/feedback |
| `/interview` | In-depth user interview for feature specification |

## Skills (5)

Skills are AI-selected workflow steps that run automatically as part of the pipeline. They don't appear in the `/` autocomplete menu.

| Skill | Purpose |
|-------|---------|
| `coco-spec` | Generate feature specification with optional clarification |
| `coco-plan` | Generate implementation plan with design artifacts |
| `coco-tasks` | Generate dependency-ordered task list with consistency analysis |
| `coco-import` | Import tasks to tracker + issue tracker |
| `coco-hotfix` | Single-issue hotfix workflow |

## Built-In Task Tracker

The tracker (`lib/tracker.sh`) replaces external task management tools with a zero-dependency bash + jq solution. It provides:

- **Task CRUD** with status tracking (pending / in_progress / completed)
- **Dependency graphs** with topological sort (`ready` returns next unblocked task)
- **Epic management** for grouping tasks into features
- **Session memory** for tracking work across Claude Code sessions
- **Metadata storage** for issue keys, file ownership, and custom data
- **Git sync** for committing tracker state

## Issue Tracker Integration

Configured in `.coco/config.yaml`:

| Provider | Integration |
|----------|------------|
| **Linear** | Via Linear MCP -- projects, issues, comments, status updates |
| **GitHub** | Via `gh` CLI -- issues, labels, comments |
| **None** | Tracker-only workflow, no external calls |

Status mappings, team names, labels, and issue key formats are all config-driven.

## PR Workflow and Code Review

When `pr.enabled` is true (default), the system uses a two-tier branching model:

```
main
  └── feature/{name}                    (one per epic)
        ├── feature/{name}/{ISSUE-1}    (one per task, PR -> feature branch)
        └── ...
  └── PR: feature/{name} -> main        (one per feature, after all tasks done)
```

Every PR is reviewed by the AI `code-reviewer` agent before merge:
- Findings classified as **critical** (blocks merge) or **warning** (advisory)
- Critical findings are auto-fixed and re-reviewed (up to 3 iterations)
- Issues resolve at PR merge, not at commit push

Set `pr.enabled: false` to disable PRs and use direct merge.

## Autonomous Loop

The `/coco.loop` command (inspired by the [Ralph loop](https://github.com/frankbria/ralph-claude-code) pattern) wraps the full TDD + PR + review cycle in an autonomous loop that runs until all tasks in an epic are complete. It includes:

- **Circuit breaker** -- Pauses after consecutive iterations with no progress
- **Safety limit** -- Configurable max iterations
- **Error pause** -- Stops on test/build failures (configurable)
- **Progress tracking** -- Measured by git commits, not just status changes
- **Feature PR** -- Automatically creates and reviews the feature-to-main PR on completion

## Hooks (3)

Claude Code hooks provide event-driven automation:

| Hook | Event | Purpose |
|------|-------|---------|
| `post-tool-use` | After `Write`/`Edit` | Runs configured lint and typecheck commands against modified files |
| `pre-compact` | Before compaction | Captures active epic, tasks, branch, and context to session memory |
| `session-start` | Session start | Restores context from session memory if available |

Configure quality hooks in `.coco/config.yaml`:

```yaml
quality:
  lint_command: "ruff check {file}"     # Run after each edit
  typecheck_command: "mypy {file}"      # Run after each edit
  auto_fix: false                       # Auto-run lint --fix on failure
```

## Adaptive Complexity Routing

`/planning-session tactical` and `/coco.phase` automatically route features to the right pipeline depth:

| Tier | Signal | Pipeline |
|------|--------|----------|
| **Trivial** | Single file, bug fix, "quick" | `coco-hotfix` skill (no epic) |
| **Light** | 1-3 files, single story | `coco-spec` -> `coco-import` (skip plan + tasks) |
| **Standard** | Multi-file, dependencies | Full: `coco-spec` -> `coco-plan` -> `coco-tasks` -> `coco-import` |

## Project Structure

```
coco-workflow/                         # This repo (git submodule in your project)
  plugin.json                          # Claude Code plugin manifest
  commands/                            # 12 slash commands
  skills/                              # 5 skills (spec, plan, tasks, import, execute, hotfix)
  agents/                              # 2 agents (code-reviewer, pre-commit-tester)
  hooks/                               # Claude Code hooks (post-tool-use, pre-compact, session-start)
  git-hooks/                           # Git hooks (commit-msg, pre-commit)
  lib/tracker.sh                       # Built-in task tracker
  templates/                           # Default templates (PRD, analysis, roadmap, spec, plan, tasks, constitution)
  workflows/                           # Reference workflow documentation
  config/coco.default.yaml             # Default configuration
  scripts/                             # setup.sh, uninstall.sh

<your-project>/
  .coco/
    config.yaml                        # Project-specific configuration
    memory/constitution.md             # Project constitution
    templates/                         # Optional template overrides
    tasks/                             # Tracker state (tasks.jsonl, sessions.jsonl)
  docs/
    prd.md                             # Product Requirements Document
    analysis/                          # Analysis documents
    roadmap/                           # Per-release roadmap documents
  specs/{feature}/                     # Spec artifacts per feature
```

## Configuration

Copy and customize `config/coco.default.yaml` to `.coco/config.yaml`:

```yaml
project:
  name: "My Project"
  specs_dir: "specs"

discovery:
  prd_path: "docs/prd.md"
  analysis_dir: "docs/analysis"
  roadmap_dir: "docs/roadmap"

issue_tracker:
  provider: "none"          # linear | github | none

quality:
  lint_command: ""            # e.g., "ruff check {file}", "eslint {file}"
  typecheck_command: ""       # e.g., "mypy {file}", "tsc --noEmit"
  auto_fix: false

commit:
  title_format: "{description}. Completes {issue_key}"

loop:
  max_iterations: 20
  no_progress_threshold: 3
  pause_on_error: true

pr:
  enabled: true
  issue_merge_strategy: "squash"
  feature_merge_strategy: "merge"
  review:
    enabled: true
    max_review_iterations: 3
```

See `config/coco.default.yaml` for all options.

## Acknowledgments

This project builds on ideas and patterns from several tools:

- **[Ralph](https://github.com/snarktank/ralph)** and **[ralph-claude-code](https://github.com/frankbria/ralph-claude-code)** -- The autonomous loop pattern with circuit breaker and completion detection that inspired `/coco.loop`
- **[Choo Choo Ralph](https://github.com/mj-meyer/choo-choo-ralph)** -- Demonstrated the value of combining structured task tracking (Beads) with autonomous execution (Ralph), validating the approach coco-workflow takes natively
- **[Beads](https://github.com/daveio/beads)** -- Git-native task tracker with dependency-aware task selection. Coco-workflow's built-in tracker reimplements the core value (JSONL persistence, topological sort, epic grouping) without the external CLI, daemon, or SQLite dependencies
- **[Spec-Kit](https://github.com/daveio/spec-kit)** -- Spec-driven planning commands for Claude Code. Coco-workflow consolidates and extends these into a unified command surface with auto-analyze gates and config-driven behavior

## License

Private. All rights reserved.
