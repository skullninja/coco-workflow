# Contributing to Coco

Thanks for your interest in contributing to Coco! This guide will help you get started.

## Prerequisites

- **bash** (4.0+)
- **jq** (1.6+)
- **git**
- **gh** CLI (optional -- needed for PR workflow and GitHub issue tracker features)

## Getting Started

```bash
git clone https://github.com/skullninja/coco-workflow.git
cd coco-workflow
bash tests/test-tracker.sh
```

All 46 tests should pass. If they do, you're ready to go.

## Project Structure

| Directory | What's inside |
|-----------|---------------|
| `commands/` | Slash commands (markdown with YAML frontmatter) |
| `skills/` | AI-selected skills invoked by commands (interview, design, tasks, import, execute, hotfix) |
| `agents/` | Subagents for code review, task execution, and UI validation |
| `hooks/` | Claude Code hooks (PostToolUse, PreCompact, SessionStart) |
| `git-hooks/` | Git hooks installed by setup (commit-msg, pre-commit) |
| `lib/` | Core engine -- `tracker.sh` (bash + jq task tracker) |
| `config/` | Default configuration schema (`coco.default.yaml`) |
| `templates/` | Default templates for PRD, design, tasks, etc. |
| `scripts/` | Setup and uninstall scripts |
| `tests/` | Tracker test suite |

## How to Contribute

### Bug Reports

Open an issue with:
- Steps to reproduce
- Expected vs actual behavior
- Your environment (OS, bash version, jq version)

### Feature Requests

Open an issue describing the use case and why existing functionality doesn't cover it.

### Pull Requests

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Run `bash tests/test-tracker.sh` and ensure all tests pass
4. Open a PR with a clear description of what changed and why

## Development Guidelines

### Commands and Skills

Commands and skills are markdown files with YAML frontmatter. Claude Code auto-discovers them via `plugin.json`. See existing files in `commands/` and `skills/` for the expected structure.

### Bash Conventions

These conventions keep Claude Code permission prompts to a minimum:

- No `$()` command substitution inside echo/printf -- assign to a variable first
- No multiline strings -- keep `--description`, `--title`, `--metadata` values on a single line
- No `\` line continuations -- long lines are fine
- No `for` loops or multiline blocks -- use separate invocations
- Use `--body-file - <<'EOF'...EOF` instead of `--body "$(cat <<'EOF'...EOF)"` for `gh` commands

See `CLAUDE.md` for the full list.

### Tracker

The tracker (`lib/tracker.sh`) is the core engine. Always invoke it as a standalone command:

```bash
bash lib/tracker.sh <command> [args]
```

Never use `source` -- it creates compound commands that trigger permission prompts.

### jq

- Use `jq -s` (slurp) for aggregate queries on JSONL files
- Wrap subtraction in parens inside `select()`: `((.depends_on // []) - $done) | length == 0`
- ID regex: `test("^" + $prefix + "\\d+$")` to avoid prefix collisions

### Configuration

When adding configurable behavior, update `config/coco.default.yaml` with the new field and its default value. Projects inherit defaults from this file.

## Testing

```bash
bash tests/test-tracker.sh
```

New tracker features need tests. The test file (`tests/test-tracker.sh`) uses a simple assert pattern -- follow the existing style.

## Commit Conventions

- `Completes {KEY}` -- implementation commits
- `Ref {KEY}` -- review fix commits

Where `{KEY}` is the issue tracker key (e.g., `LIN-123`, `#42`).

## License

MIT. By contributing, you agree that your contributions will be licensed under the same license.
