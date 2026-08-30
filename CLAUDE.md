# CLAUDE.md -- Coco

## Project Overview

Coco is a Claude Code plugin that provides autonomous spec-driven development. It unifies planning (slash commands), execution (built-in task tracker), PR workflow with AI code review, and visibility (configurable issue tracker) into a single plugin distributed via the Claude Code marketplace (or as a git submodule).

## Architecture

Five layers:
- **Discovery**: `/coco:prd` and `/coco:roadmap` produce PRD, analysis, and roadmap artifacts. Supports multi-repo via derived PRDs (`/coco:prd derive`)
- **Planning**: Skills (`interview`, `design`, `tasks`, `import`) produce spec artifacts in `specs/{feature}/`
- **Execution**: `lib/tracker.sh` (bash + jq) manages task state, dependencies, sessions
- **Review**: Two-tier PR workflow with AI code review (`agents/code-reviewer.md`)
- **Visibility**: Issue tracker bridge (Linear MCP, GitHub CLI, or none) mirrors status

## Key Files

| Path | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Claude Code plugin manifest (auto-discovers commands/skills/agents) |
| `hooks/hooks.json` | Claude Code hook definitions (PostToolUse, PreCompact, SessionStart) -- no PreToolUse, see Hooks |
| `bin/coco-tracker` | Tracker wrapper -- on PATH as bare command `coco-tracker` |
| `lib/tracker.sh` | Built-in task tracker -- **core of the system** (invoked via `coco-tracker`) |
| `config/coco.default.yaml` | Default configuration schema |
| `commands/setup.md` | `/coco:setup` -- project initialization (config wizard, git hooks, permissions) |
| `commands/` | 13 slash commands (setup, prd [greenfield/audit/derive], roadmap, phase, loop, execute, dashboard, standup, etc.) |
| `skills/interview/SKILL.md` | Pre-design discovery interview (AI-selected) |
| `skills/design/SKILL.md` | Feature design: spec + implementation plan (AI-selected) |
| `skills/tasks/SKILL.md` | Task list generation with consistency analysis (AI-selected) |
| `skills/import/SKILL.md` | Tracker + issue tracker import (AI-selected) |
| `skills/execute/SKILL.md` | Execution skill (delegates to `/coco:execute` command) |
| `skills/hotfix/SKILL.md` | Single-issue hotfix workflow (with optional PR) |
| `agents/code-reviewer.md` | AI code review agent for PRs |
| `agents/task-executor.md` | Worktree-isolated task executor for parallel execution |
| `agents/pre-commit-tester.md` | UI/UX validation agent (config-driven) |
| `hooks/scripts/post-tool-use-quality.sh` | PostToolUse hook -- runs lint/typecheck after file edits |
| `hooks/scripts/pre-compact.sh` | PreCompact hook -- captures session state before compaction |
| `hooks/scripts/session-start.sh` | SessionStart hook -- restores session context |
| `hooks/scripts/coco-lib.sh` | Shared hook helpers -- resolves the coco project root by walking up |
| `git-hooks/commit-msg.sh` | Commit message validation (reads config) |
| `git-hooks/pre-commit.sh` | Build check + UI change detection (reads config) |
| `GUIDE.md` | Comprehensive workflow guide with deep-dives and quick reference |
| `templates/` | Default templates for PRD, analysis, roadmap, discovery, design, tasks, constitution |
| `scripts/setup.sh` | Creates `.coco/` directory and installs git hooks in host project |
| `scripts/uninstall.sh` | Removes git hooks |
| `tests/test-tracker.sh` | 53 tests for tracker.sh |
| `tests/test-hooks.sh` | 9 tests for `coco-lib.sh` project-root resolution |

## Tracker (`lib/tracker.sh`)

The tracker is the execution engine. It uses JSONL files (`.coco/tasks/tasks.jsonl`) with jq for queries.

### Key Commands

The plugin ships a `coco-tracker` wrapper in `bin/` that Claude Code adds to PATH automatically. Invoke it as a bare command — no `bash` prefix, no path, no `${CLAUDE_PLUGIN_ROOT}`. Each tracker command is a separate Bash tool call. Do NOT use `source` — it creates compound commands that trigger permission prompts.

```bash
coco-tracker <command> [args]
```

```bash
# Task lifecycle
coco-tracker create --epic ID --title "..." [--depends-on ID,ID] [--metadata '{}']
coco-tracker update ID [--status STATUS] [--metadata '{}']
coco-tracker close ID
coco-tracker show ID                       # Get single task details (JSON)
coco-tracker list [--status STATUS] [--epic ID] [--json]  # List tasks

# Dependency-aware task selection (core value)
coco-tracker ready [--json] [--epic ID]    # Next unblocked task

# Epics
coco-tracker epic-create "Title"
coco-tracker epic-status                   # List all epics (no arg)
coco-tracker epic-status EPIC_ID           # Single epic + task summary
coco-tracker epic-close EPIC_ID

# Dependencies
coco-tracker dep-add ID --blocks OTHER_ID

# Sessions
coco-tracker session-start "Description"
coco-tracker session-end

# Git sync
coco-tracker sync
```

These are the **only valid tracker commands**. Do NOT invent commands like `epic-list` — use `epic-status` (no args) to list epics, or `list --json` to list tasks.

**Output formats**: `list --json` returns a JSON **array** (`[...]`). Use `jq '.[]'` to iterate elements. `show ID` and `ready --json` return a single JSON object. Do NOT pipe tracker output to Python — use jq for all JSON processing.

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
- `discovery` -- PRD path, analysis directory, roadmap directory, source PRD (for derived/satellite repos)
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

Full pipeline: `/coco:prd` -> `/coco:roadmap` -> `/coco:phase` -> (per feature) `interview` skill -> `design` skill -> `tasks` skill -> `import` skill -> `/coco:loop`

For multi-repo projects, satellite repos use `/coco:prd derive /path/to/source/prd.md` to create a platform-specific PRD from a primary repo's PRD, then run the standard pipeline independently.

- `/coco:prd` creates, audits, or derives the Product Requirements Document
- `/coco:roadmap` synthesizes PRD + analysis docs into a prioritized, phased roadmap
- `/coco:phase` reads the roadmap and orchestrates multiple features in a phase (invoking skills for each step)
- `/coco:loop` runs autonomously with circuit breaker and PR workflow
- `/coco:execute` runs one task at a time for manual review

The pipeline steps (interview, design, tasks, import) are **skills, not commands**. They are AI-selected and invisible in the `/` autocomplete menu. They are invoked automatically by `/coco:phase`, `/coco:planning-session tactical`, or natural language requests. **NEVER suggest `/coco:tasks`, `/coco:import`, `/coco:design`, or `/coco:interview` to users** -- these do not exist as slash commands. Instead, tell users to ask Claude in natural language (e.g., "interview me about this feature", "generate tasks", "import into tracker").

## Adaptive Complexity Routing

`/coco:planning-session tactical` and `/coco:phase` classify features by complexity tier:

| Tier | Pipeline |
|------|----------|
| **Trivial** | `hotfix` skill (no epic overhead) |
| **Light** | `design` (light mode) -> `import` (design-only mode) |
| **Standard** | Full: `interview` -> `design` -> `tasks` -> `import` |

Light mode: `design` generates a minimal design (single user story, 3-5 acceptance criteria, no technical approach or clarification pass). `import` creates a single-task epic directly from the design without requiring tasks.md.

## Hooks

Two types of hooks in separate directories:
- **Claude Code hooks** (`hooks/hooks.json`): JSON config pointing at `command`-type scripts in `hooks/scripts/`. Events defined:
  - `PostToolUse` (matcher `Write|Edit`) -- Runs quality checks (lint, typecheck)
  - `PreCompact` -- Captures session state to `.coco/state/session-memory.md`
  - `SessionStart` -- Restores context from session memory
- **Git hooks** (`git-hooks/`): Shell scripts installed to `.git/hooks/` by `setup.sh`
  - `commit-msg.sh` -- Commit message validation
  - `pre-commit.sh` -- Build check + UI change detection

All three Claude Code hook scripts gate on `.coco/config.yaml`, resolved via `coco_project_root` in `hooks/scripts/coco-lib.sh`, which **walks upward** from the hook's cwd (then `$CLAUDE_PROJECT_DIR`, then `$PWD`). Hooks routinely fire with cwd set to a package subdirectory or a parallel-execution worktree, so a bare relative `.coco/config.yaml` check silently no-ops there. `tests/test-hooks.sh` covers that resolution directly -- it is the one code path all three hooks share, and it fails invisibly in both directions (hooks stop firing in real projects, or start firing in unrelated ones).

**No coco hook blocks a tool call.** There is deliberately no `PreToolUse` hook.

### Why there is no PreToolUse hook

There was one, from 0.2.x through 0.3.0. It denied Bash commands believed to fail silently. Removed in 0.3.1, because each rule it still carried was defending a failure mode that does not occur:

| Rule | Claimed failure | What actually happens |
|------|-----------------|-----------------------|
| tracker assigned to a shell variable | expansion resolves the path wrongly | `TRACKER=coco-tracker; $TRACKER list` works fine. The claim was true when the tracker was invoked as `bash ${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh`; it stopped being true when `bin/coco-tracker` went on PATH, and the rule was never revisited |
| multiline `coco-tracker` command | titles truncate, `--metadata` becomes invalid JSON | `lib/tracker.sh:142` collapses newlines in titles to spaces, and jq accepts newlines inside JSON. Both now have assertions in `tests/test-tracker.sh` |

Earlier rounds had already dropped `cd &&` compounds, 2+ tracker calls per command, tracker piped to python, `tracker.sh` by path, and space-separated subcommands (`epic create`) -- as permission-prompt avoidance that autonomous / skip-permissions modes made redundant, or as commands that fail loudly on their own.

Measured across one developer's local transcripts before removal: **164 denials, none of which prevented a real failure.** The heaviest single case was a `task-executor` subagent inside a `/coco:loop` worktree, taking 18.

**A recoverable deny is not free.** It costs a turn, and consecutive denials produce no commits, which starves `/coco:loop`'s `no_progress` counter until the circuit breaker exits the loop -- reading as "the hook stopped execution" when nothing halted.

The one real gap the multiline rule gestured at was in the tracker, not the harness: invalid `--metadata` printed a warning, substituted `{}`, and **exited 0**, so `owns_files` and `test_plan` could vanish while every caller saw success. `lib/tracker.sh` now errors and returns 1 from both `create` and `update`. Fix the tool; do not police the caller.

### Before adding a PreToolUse hook back

**Demonstrate the failure first.** Every rule this hook ever carried came from a plausible-sounding theory, and each one that was eventually tested did not reproduce. Write the failing `tests/test-tracker.sh` case before writing the rule. If the command cannot be made to fail, there is nothing to deny.

**It must be a `command` hook, never a `prompt` hook.** A prompt hook's sub-model returns `{ok, reason}`, and Claude Code maps `ok: false` to `preventContinuation` -- which **halts the entire turn** ("hook stopped continuation"), not just the one tool call. A command hook returning:

```json
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "..."}}
```

blocks only that call and hands the reason back to Claude, which rewrites and continues. Verified against CLI 2.1.220: `permissionDecision: "deny"` sets `permissionBehavior="deny"` plus a `blockingError`, and never `preventContinuation` -- which is assigned only in the prompt-hook path. The reason survives as `blockingError: hookSpecificOutput.permissionDecisionReason || reason || "Blocked by hook"`. Prompt hooks have since gained a `continueOnBlock: true` escape hatch, but a command hook is still the right tool for a per-call denial.


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

## Installation

Two installation paths, both produce the same result:

**Marketplace (recommended):**
```
/plugin marketplace add skullninja/coco-workflow
/plugin install coco@coco-local
/coco:setup
```

The plugin ID is `coco@coco-local`. The marketplace name comes from the `name` field in `.claude-plugin/marketplace.json`, not from the repo slug used to add it — so adding `skullninja/coco-workflow` registers a marketplace called `coco-local`. `scripts/setup.sh` uses the same name for submodule installs, so both paths resolve to one plugin ID.

**Git submodule (legacy):**
```bash
git submodule add https://github.com/skullninja/coco-workflow.git coco-workflow
bash coco-workflow/scripts/setup.sh
```

## Testing

```bash
bash tests/test-tracker.sh
bash tests/test-hooks.sh
```

`test-tracker.sh` runs 53 tests covering CRUD, dependencies, ready algorithm, epics, sessions, and metadata. The `Invalid Metadata` group is the load-bearing one: it asserts that malformed `--metadata` fails with a non-zero exit on both `create` and `update` and leaves existing state untouched, and -- in the other direction -- that a **multiline but valid** command is accepted. Those last two assertions are what stop the deleted PreToolUse rule being reintroduced on the same false premise.

`test-hooks.sh` runs 9 tests over `coco_project_root` in `hooks/scripts/coco-lib.sh`: the upward walk from nested and worktree-like directories, the gate that keeps hooks out of non-coco projects, and the `hint -> $CLAUDE_PROJECT_DIR -> $PWD` fallback chain including a hint directory that no longer exists (`/coco:loop` prunes the worktrees its agents ran in). All three behaviors were mutation-tested: breaking the walk, the gate, or the fallback each fails the suite.

## Development Notes

- Zero external dependencies beyond bash + jq (gh CLI needed for PR workflow)
- All commands are markdown files with frontmatter -- Claude Code executes them as slash commands
- The plugin uses `${CLAUDE_PLUGIN_ROOT}` to reference its own files
- Host project state lives in `.coco/` (never inside the plugin directory)
- Git hooks read config from `.coco/config.yaml` using jq-based YAML parsing
- Commit formats: `Completes {KEY}` for implementation, `Ref {KEY}` for review fixes

### Every change needs a version bump, or it does not ship

Claude Code installs a plugin into a **version-keyed cache**: `~/.claude/plugins/cache/{marketplace}/{plugin}/{version}/`. `${CLAUDE_PLUGIN_ROOT}` resolves there, not to the marketplace git clone. The cache is only refreshed when the version string in `.claude-plugin/plugin.json` changes.

So merging to `main` ships nothing on its own. A commit that edits plugin files without bumping the version is invisible to every installed session, indefinitely, with no warning.

This has already happened once: `3a74275` trimmed the PreToolUse hook from six rules to two and deliberately said "no version bump" (PR #3 was going to claim the next number). The cache stayed pinned at `0.3.0` and kept serving the six-rule hook for weeks after the trim merged -- including into `/coco:loop` worktrees, whose denials were then blamed on the hook design rather than on a stale build.

Bump `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` **together, in the same commit as the change**. If a pending PR already claims the next minor, take a patch (`0.3.1`) rather than deferring the bump. Verify a release actually landed with:

```bash
which coco-tracker
```

The version segment in that path is the build that is really running.

## Bash Command Guidelines

**Nothing here is enforced.** No hook blocks Bash commands -- see [Why there is no PreToolUse hook](#why-there-is-no-pretooluse-hook). These are conventions: they keep tracker calls readable and reduce permission prompts in interactive sessions. Under autonomous or skip-permissions modes most are purely cosmetic.

The one command shape that still costs you something is malformed `--metadata`, and the tracker now rejects it with a clear error and a non-zero exit. Keep `--metadata` to valid JSON; a newline inside it is fine.

- **Always use `coco-tracker`**: call it directly rather than `bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"`, `source`, or a hardcoded absolute path. The alternatives fail with a clear error, but the bare command is correct and shorter.
- **Hyphenated subcommands**: `epic-create`, `dep-add`, `session-start`. The space-separated forms just produce a usage error.
- **One tracker call per Bash tool invocation**: batching works, but separate calls give clearer error attribution.
- **Use jq, not python, for tracker JSON**: `list --json` returns an array (iterate with `jq '.[]'`); `show ID` and `ready --json` return a single object.
- **No `$()` in echo/printf**: git commands already print useful output. Assign to a variable on its own line if needed.
- **No `\` line continuations**: write each command on one line. Long lines are fine.
- **Avoid `cd &&` compounds**: `cd /path && command` can trigger a "bare repository attack" security prompt interactively. Issue the `cd` and the command as separate Bash tool calls.
- **Minimize command chaining** and **avoid `for` loops / multiline blocks**: separate Bash tool calls give clearer output.
- **Use `--body-file -` for `gh` commands**: `--body-file - <<'EOF'...EOF` instead of `--body "$(cat <<'EOF'...EOF)"`.
