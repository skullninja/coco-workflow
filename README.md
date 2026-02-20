# coco-workflow

Spec-driven development workflow for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Takes features from description to merged code with minimal human interaction.

## What It Does

Coco-workflow unifies planning, task tracking, and issue tracker integration into a single Claude Code plugin. After an initial specification step, the pipeline handles task decomposition, dependency resolution, TDD implementation, commit operations, and issue tracker sync autonomously.

### Three-Layer Architecture

| Layer | Tool | Role |
|-------|------|------|
| **Planning** | Slash commands (`/coco.*`) | Produces spec, plan, and task artifacts |
| **Execution** | Built-in tracker (`lib/tracker.sh`) | Manages dependencies, session memory, task ordering |
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

No daemon, no database, no additional CLI tools.

## Quick Start

### Full Feature Pipeline

```
/coco.spec "Add user authentication"    # Create specification
/coco.plan                               # Generate implementation plan
/coco.tasks                              # Generate task list (auto-analyzes)
/coco.import                             # Import to tracker + issue tracker
/coco.loop                               # Autonomous execution until done
```

### Phase Orchestration (Multiple Features)

```
/coco.phase "Q1 Release"                # Audits, plans, and executes all features
```

### Single-Issue Hotfix

```
# Uses the coco-hotfix skill -- no epic overhead
```

## Commands

| Command | Purpose |
|---------|---------|
| `/coco.spec` | Create feature specification |
| `/coco.clarify` | Interactive Q&A to reduce ambiguity |
| `/coco.plan` | Generate implementation plan + design artifacts |
| `/coco.tasks` | Generate dependency-ordered task list (auto-analyzes) |
| `/coco.analyze` | Cross-artifact consistency analysis |
| `/coco.constitution` | Manage project constitution |
| `/coco.import` | Import tasks to tracker + issue tracker |
| `/coco.execute` | TDD execution loop (one task at a time) |
| `/coco.loop` | Autonomous execution loop with circuit breaker |
| `/coco.sync` | Reconcile tracker and issue tracker state |
| `/coco.status` | Show execution status and parallel opportunities |
| `/coco.phase` | Orchestrate full pipeline for a roadmap phase |
| `/interview` | In-depth user interview for feature specification |
| `/planning-session` | Structured planning sessions (strategic/tactical/operational) |
| `/planning-triage` | Score and disposition bugs/features/feedback |

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

## Autonomous Loop

The `/coco.loop` command (inspired by the [Ralph loop](https://github.com/frankbria/ralph-claude-code) pattern) wraps the TDD execution cycle in an autonomous loop that runs until all tasks in an epic are complete. It includes:

- **Circuit breaker** -- Pauses after consecutive iterations with no progress
- **Safety limit** -- Configurable max iterations
- **Error pause** -- Stops on test/build failures (configurable)
- **Progress tracking** -- Measured by git commits, not just status changes

## Project Structure

```
coco-workflow/                         # This repo (git submodule in your project)
  plugin.json                          # Claude Code plugin manifest
  commands/                            # 15 slash commands
  skills/                              # 2 skills (execute, hotfix)
  agents/                              # 1 agent (pre-commit-tester)
  lib/tracker.sh                       # Built-in task tracker
  hooks/                               # Git hooks (commit-msg, pre-commit)
  templates/                           # Default spec/plan/tasks/constitution templates
  workflows/                           # Reference workflow documentation
  config/coco.default.yaml             # Default configuration
  scripts/                             # setup.sh, uninstall.sh

<your-project>/
  .coco/
    config.yaml                        # Project-specific configuration
    memory/constitution.md             # Project constitution
    templates/                         # Optional template overrides
    tasks/                             # Tracker state (tasks.jsonl, sessions.jsonl)
  specs/{feature}/                     # Spec artifacts per feature
```

## Configuration

Copy and customize `config/coco.default.yaml` to `.coco/config.yaml`:

```yaml
project:
  name: "My Project"
  specs_dir: "specs"

issue_tracker:
  provider: "none"          # linear | github | none

commit:
  title_format: "{description}. Completes {issue_key}"

loop:
  max_iterations: 20
  no_progress_threshold: 3
  pause_on_error: true
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
