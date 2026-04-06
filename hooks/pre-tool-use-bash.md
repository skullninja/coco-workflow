---
event: PreToolUse
match_tool: Bash
---

**STOP. Do not run the command if ANY pattern below matches.** Rewrite it as shown, then run the rewritten version instead.

## Blocked Patterns

**`cd && ...` compounds**: `cd /path && command` triggers a "bare repository attack" security prompt. REWRITE: drop the `cd` entirely — the working directory is already correct. If you genuinely need a different directory, use one Bash tool call for `cd` and a separate one for the command.
- BLOCKED: `cd /Users/dave/Projects/foo && git log --oneline`
- REWRITE: `git log --oneline`

**Chained commands with `&&` or `||`**: Chaining breaks permission pattern matching — `Bash(gh:*)` won't match `VAR="..." && gh project ...`. REWRITE: split into separate Bash tool calls, one per command.
- BLOCKED: `git fetch && git checkout feature/foo`
- REWRITE: two separate Bash tool calls: `git fetch` then `git checkout feature/foo`

**`$()` in echo/printf**: Don't add `echo "Created: $(git branch --show-current)"` confirmations. Git commands already print useful output. If you need a variable, assign it on a separate line first.

**Multiline strings**: Keep `--description`, `--title`, `--metadata` values on a single line. Use semicolons to separate items.

**`for` loops or multiline blocks**: Instead of `for x in ...; do ... done`, use separate Bash tool calls for each iteration.

**Piping tracker output to Python**: Use jq for all JSON processing of tracker output. `list --json` returns a JSON array — use `jq '.[]'` to iterate.

**Variable assignment of tracker path**: Never assign the tracker command to a variable (e.g., `TRACKER="bash .../tracker.sh"` then `$TRACKER create ...`). The shell treats the variable value as a single token, causing "no such file or directory" errors. Always use the full command directly: `bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" <command>`.

**Hardcoded paths to tracker.sh**: Never use an absolute path like `bash /Users/.../lib/tracker.sh`. Always use `bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"`. Hardcoded paths break when the plugin is installed in a different location.

**Multiple tracker calls in one command**: Each `tracker.sh` invocation MUST be a separate Bash tool call. If the command contains `tracker.sh` more than once (via newlines, semicolons, or any other means), reject it and split into individual calls.

**`source` of tracker.sh**: Never use `source tracker.sh` or `. tracker.sh`. This creates compound commands that trigger permission prompts. Use `bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" <command>` as a standalone command.

**Space-separated subcommands**: Tracker subcommands are hyphenated, not space-separated. Use `dep-add` (not `dep add`), `epic-create` (not `epic create`), `epic-status` (not `epic status`), `epic-close` (not `epic close`), `session-start` (not `session start`), `session-end` (not `session end`).
