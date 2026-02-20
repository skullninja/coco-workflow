# CLAUDE.md -- coco-workflow

## Project Overview

Coco-workflow is a Claude Code plugin that provides a spec-driven development workflow. It unifies planning (slash commands), execution (built-in task tracker), and visibility (configurable issue tracker) into a single plugin deliverable as a git submodule.

## Architecture

Three layers:
- **Planning**: `/coco.*` commands produce spec artifacts in `specs/{feature}/`
- **Execution**: `lib/tracker.sh` (bash + jq) manages task state, dependencies, sessions
- **Visibility**: Issue tracker bridge (Linear MCP, GitHub CLI, or none) mirrors status

## Key Files

| Path | Purpose |
|------|---------|
| `plugin.json` | Claude Code plugin manifest (auto-discovers commands/skills/agents) |
| `lib/tracker.sh` | Built-in task tracker -- **core of the system** |
| `config/coco.default.yaml` | Default configuration schema |
| `commands/` | 15 slash commands (coco.spec, coco.plan, coco.tasks, coco.import, coco.execute, coco.loop, etc.) |
| `skills/execute/SKILL.md` | Primary execution skill (10-step TDD loop) |
| `skills/hotfix/SKILL.md` | Single-issue hotfix workflow |
| `agents/pre-commit-tester.md` | UI/UX validation agent (config-driven) |
| `hooks/commit-msg.sh` | Commit message validation (reads config) |
| `hooks/pre-commit.sh` | Build check + UI change detection (reads config) |
| `templates/` | Default templates for spec, plan, tasks, constitution |
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
- `issue_tracker` -- provider (linear/github/none), status mappings, team/labels
- `commit` -- title format, exempt patterns
- `pre_commit` -- UI patterns for agent triggering, build command
- `testing` -- test command, timeout
- `loop` -- max iterations, no-progress threshold, pause-on-error

## Issue Tracker Bridge

The bridge is implemented as conditional instructions in command markdown files (not shell abstractions). Commands read `issue_tracker.provider` from config and follow the appropriate branch:
- **linear**: Uses `mcp__plugin_linear_linear__*` MCP tools
- **github**: Uses `gh` CLI commands
- **none**: Skips all issue tracker operations

## Command Pipeline

Typical flow: `/coco.spec` -> `/coco.plan` -> `/coco.tasks` (auto-runs `/coco.analyze`) -> `/coco.import` -> `/coco.loop`

- `/coco.loop` runs autonomously with circuit breaker (inspired by Ralph loop pattern)
- `/coco.execute` runs one task at a time for manual review
- `/coco.phase` orchestrates multiple features in a roadmap phase

## Template System

Templates resolve in order: `.coco/templates/{name}` (project override) -> `${CLAUDE_PLUGIN_ROOT}/templates/{name}` (default).

## Parallel Execution

After foundation sub-phases complete, user story sub-phases can run in parallel (max 3 agents). File ownership is tracked via task metadata (`owns_files`). See `workflows/parallel-execution.md`.

## Testing

```bash
bash tests/test-tracker.sh
```

Runs 28 tests covering CRUD, dependencies, ready algorithm, epics, sessions, and metadata.

## Development Notes

- Zero external dependencies beyond bash + jq
- All commands are markdown files with frontmatter -- Claude Code executes them as slash commands
- The plugin uses `${CLAUDE_PLUGIN_ROOT}` to reference its own files
- Host project state lives in `.coco/` (never inside the plugin directory)
- Git hooks read config from `.coco/config.yaml` using jq-based YAML parsing
