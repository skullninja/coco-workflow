# CLAUDE.md -- Coco

## Project Overview

Coco is a Claude Code plugin that provides autonomous spec-driven development. It unifies planning (slash commands), execution (built-in task tracker), PR workflow with AI code review, and visibility (configurable issue tracker) into a single plugin deliverable as a git submodule.

## Architecture

Five layers:
- **Discovery**: `/coco:prd` and `/coco:roadmap` produce PRD, analysis, and roadmap artifacts
- **Planning**: Skills (`spec`, `plan`, `tasks`, `import`) produce spec artifacts in `specs/{feature}/`
- **Execution**: `lib/tracker.sh` (bash + jq) manages task state, dependencies, sessions
- **Review**: Two-tier PR workflow with AI code review (`agents/code-reviewer.md`)
- **Visibility**: Issue tracker bridge (Linear MCP, GitHub CLI, or none) mirrors status

## Key Files

| Path | Purpose |
|------|---------|
| `plugin.json` | Claude Code plugin manifest (auto-discovers commands/skills/agents) |
| `lib/tracker.sh` | Built-in task tracker -- **core of the system** |
| `config/coco.default.yaml` | Default configuration schema |
| `commands/` | 12 slash commands (prd, roadmap, phase, loop, execute, standup, etc.) |
| `skills/spec/SKILL.md` | Feature specification with clarification (AI-selected) |
| `skills/plan/SKILL.md` | Implementation plan generation (AI-selected) |
| `skills/tasks/SKILL.md` | Task list generation with consistency analysis (AI-selected) |
| `skills/import/SKILL.md` | Tracker + issue tracker import (AI-selected) |
| `skills/execute/SKILL.md` | Execution skill (delegates to `/coco:execute` command) |
| `skills/hotfix/SKILL.md` | Single-issue hotfix workflow (with optional PR) |
| `agents/code-reviewer.md` | AI code review agent for PRs |
| `agents/task-executor.md` | Worktree-isolated task executor for parallel execution |
| `agents/pre-commit-tester.md` | UI/UX validation agent (config-driven) |
| `hooks/post-tool-use.md` | PostToolUse hook -- runs lint/typecheck after file edits |
| `hooks/pre-compact.md` | PreCompact hook -- captures session state before compaction |
| `hooks/session-start.md` | SessionStart hook -- restores session context |
| `git-hooks/commit-msg.sh` | Commit message validation (reads config) |
| `git-hooks/pre-commit.sh` | Build check + UI change detection (reads config) |
| `GUIDE.md` | Comprehensive workflow guide with deep-dives and quick reference |
| `templates/` | Default templates for PRD, analysis, roadmap, spec, plan, tasks, constitution |
| `workflows/` | Reference documentation for workflows |
| `scripts/setup.sh` | Creates `.coco/` directory and installs git hooks in host project |
| `scripts/uninstall.sh` | Removes git hooks |
| `tests/test-tracker.sh` | 28 tests for tracker.sh |

## Tracker (`lib/tracker.sh`)

The tracker is the execution engine. It uses JSONL files (`.coco/tasks/tasks.jsonl`) with jq for queries.

### Key Commands

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"

# Task lifecycle
coco_tracker create --epic ID --title "..." [--depends-on ID,ID] [--metadata '{}']
coco_tracker update ID [--status STATUS] [--metadata '{}']
coco_tracker close ID

# Dependency-aware task selection (core value)
coco_tracker ready [--json] [--epic ID]    # Returns next unblocked task

# Epics
coco_tracker epic-create "Title"
coco_tracker epic-status [EPIC_ID]
coco_tracker epic-close EPIC_ID

# Dependencies
coco_tracker dep-add ID --blocks OTHER_ID

# Sessions
coco_tracker session-start "Description"
coco_tracker session-end

# Git sync
coco_tracker sync
```

### Data Format

JSONL with two record types: `epic` and `task`. Tasks have `depends_on` arrays and arbitrary `metadata` objects. The `ready` command performs topological sort to find unblocked tasks.

### Known Patterns

- **jq slurp mode**: Always use `jq -s` for aggregate JSONL queries (e.g., filtering, counting)
- **jq operator precedence**: Wrap subtraction in parens inside `select()`: `((.depends_on // []) - $done) | length == 0`
- **ID generation**: Uses regex `test("^" + $prefix + "\\d+$")` to avoid prefix collisions (e.g., `epic-001` vs `epic-001.1`)

## Configuration

Projects configure behavior in `.coco/config.yaml`. The schema with defaults is in `config/coco.default.yaml`.

Key sections:
- `project` -- name, specs directory
- `discovery` -- PRD path, analysis directory, roadmap directory
- `quality` -- lint command, typecheck command, auto-fix (used by PostToolUse hook)
- `issue_tracker` -- provider (linear/github/none), status mappings, team/labels, GitHub Projects V2 config
- `commit` -- title format, exempt patterns
- `pre_commit` -- UI patterns for agent triggering, build command
- `testing` -- test command, timeout
- `loop` -- max iterations, no-progress threshold, pause-on-error, parallel execution config
- `pr` -- PR workflow, merge strategies, AI review config, branch naming

## PR Workflow

When `pr.enabled` is true (default), the system uses a two-tier branching model:

```
main
  └── feature/{name}                    (one per epic)
        ├── feature/{name}/{ISSUE-KEY}  (one per task, PR -> feature branch)
        └── ...
  └── PR: feature/{name} -> main        (one per feature)
```

**Issue lifecycle** (issues resolve at PR merge, not at commit):
- Task claimed: issue "In Progress"
- PR created: issue "In Review" (PR body includes `Resolves {ISSUE-KEY}`)
- PR merged: issue "Done"

**Code review**: The `code-reviewer` agent reviews every PR. Findings are classified as critical (blocks merge) or warning (advisory). Critical findings are auto-fixed in a review-fix loop (max 3 iterations). If the loop exhausts, the PR is left open for human review.

Set `pr.enabled: false` to disable PRs and use direct merge (backward compatible).

## Issue Tracker Bridge

The bridge is implemented as conditional instructions in command and skill markdown files (not shell abstractions). Commands and skills read `issue_tracker.provider` from config and follow the appropriate branch:
- **linear**: Uses `mcp__plugin_linear_linear__*` MCP tools
- **github**: Uses `gh` CLI commands. Supports GitHub Projects V2 for board-based status tracking.
- **none**: Skips all issue tracker operations

### GitHub Projects V2

When `issue_tracker.github.use_projects` is `true` (default), the GitHub integration creates and manages GitHub Projects V2 boards:

- **One project per feature**: Created during `import`, matching Linear's project-per-feature model
- **Status columns**: Todo, In Progress, In Review, Done -- mapped via `status_map` config values
- **Field ID caching**: `gh project item-edit` requires opaque IDs. Resolved once during import, cached in `.coco/state/gh-projects.json`
- **Issue lifecycle**: Issues are added to the project board and moved between columns as status changes
- **Phase projects**: `/coco:roadmap` creates a project per phase (cached under `phases` key)
- **Backward compatibility**: Set `use_projects: false` to fall back to label-based status tracking

Cache file structure (`.coco/state/gh-projects.json`):
```json
{
  "features": {
    "feature-name": {
      "project_number": 42,
      "project_id": "PVT_...",
      "status_field_id": "PVTSSF_...",
      "status_options": { "Todo": "opt-id-1", "In Progress": "opt-id-2", ... }
    }
  },
  "phases": {
    "Phase 1: Foundation": { "project_number": 43, "project_id": "PVT_..." }
  }
}
```

## Pipeline

Full pipeline: `/coco:prd` -> `/coco:roadmap` -> `/coco:phase` -> (per feature) `spec` skill -> `plan` skill -> `tasks` skill -> `import` skill -> `/coco:loop`

- `/coco:prd` creates or audits the Product Requirements Document
- `/coco:roadmap` synthesizes PRD + analysis docs into a prioritized, phased roadmap
- `/coco:phase` reads the roadmap and orchestrates multiple features in a phase (invoking skills for each step)
- `/coco:loop` runs autonomously with circuit breaker and PR workflow
- `/coco:execute` runs one task at a time for manual review

The pipeline steps (spec, plan, tasks, import) are skills -- AI-selected and invisible in the `/` autocomplete menu. They are invoked automatically by `/coco:phase`, `/planning-session tactical`, or natural language requests.

## Adaptive Complexity Routing

`/planning-session tactical` and `/coco:phase` classify features by complexity tier:

| Tier | Pipeline |
|------|----------|
| **Trivial** | `hotfix` skill (no epic overhead) |
| **Light** | `spec` (light mode) -> `import` (spec-only mode) |
| **Standard** | Full: `spec` -> `plan` -> `tasks` -> `import` |

Light mode: `spec` generates a minimal spec (single user story, 3-5 acceptance criteria, no clarification pass). `import` creates a single-task epic directly from the spec without requiring plan.md or tasks.md.

## Hooks

Two types of hooks in separate directories:
- **Claude Code hooks** (`hooks/`): Prompt-based `.md` files auto-discovered by Claude Code via `plugin.json`
  - `post-tool-use.md` -- Runs quality checks (lint, typecheck) after Write/Edit
  - `pre-compact.md` -- Captures session state to `.coco/state/session-memory.md`
  - `session-start.md` -- Restores context from session memory
- **Git hooks** (`git-hooks/`): Shell scripts installed to `.git/hooks/` by `setup.sh`
  - `commit-msg.sh` -- Commit message validation
  - `pre-commit.sh` -- Build check + UI change detection

## Template System

Templates resolve in order: `.coco/templates/{name}` (project override) -> `${CLAUDE_PLUGIN_ROOT}/templates/{name}` (default).

## Parallel Execution

After foundation sub-phases complete, user story sub-phases can run in parallel (max 3 agents). File ownership is tracked via task metadata (`owns_files`).

### Worktree-Based Parallel Execution

When `loop.parallel.enabled` is `true`, `/coco:loop` uses git worktree isolation for real parallel execution:

- **`task-executor` agent**: A new agent (`agents/task-executor.md`) with `isolation: worktree` frontmatter. Executes a single task in an isolated git worktree -- TDD, commit, PR creation.
- **Dispatch**: `/coco:loop` detects multiple ready tasks with non-overlapping `owns_files`, spawns up to `max_agents` `task-executor` agents simultaneously via the Task tool.
- **Review flow**: Parent `/coco:loop` handles AI code review and merge after agents complete. Agents do NOT review or merge their own PRs.
- **Fallback**: Tasks without `owns_files` metadata, or when only one task is ready, execute serially (unchanged behavior).

Config:
```yaml
loop:
  parallel:
    enabled: false      # Enable worktree-based parallel execution
    max_agents: 3       # Max concurrent task-executor agents
```

See `workflows/parallel-execution.md` for full details.

## Testing

```bash
bash tests/test-tracker.sh
```

Runs 28 tests covering CRUD, dependencies, ready algorithm, epics, sessions, and metadata.

## Development Notes

- Zero external dependencies beyond bash + jq (gh CLI needed for PR workflow)
- All commands are markdown files with frontmatter -- Claude Code executes them as slash commands
- The plugin uses `${CLAUDE_PLUGIN_ROOT}` to reference its own files
- Host project state lives in `.coco/` (never inside the plugin directory)
- Git hooks read config from `.coco/config.yaml` using jq-based YAML parsing
- Commit formats: `Completes {KEY}` for implementation, `Ref {KEY}` for review fixes
