---
event: PreToolUse
match_tool: Bash
---

Check the proposed Bash command for patterns that trigger Claude Code permission prompts. If ANY pattern matches, **do not run the command** — instead, rewrite it as described.

## Blocked Patterns

**`cd && ...` compounds**: Never combine `cd /path && command`. Use separate Bash tool calls — one for `cd`, one for the command. This triggers a "bare repository attack" security prompt.

**Chained commands with `&&` or `||`**: Never combine commands with `&&` or `||` (e.g., `git fetch && git checkout`, `VAR="..." && gh ...`). Use separate Bash tool calls for each command. Chaining breaks permission pattern matching — `Bash(gh:*)` won't match `VAR="..." && gh project ...` because the command doesn't start with `gh`.

**`$()` in echo/printf**: Don't add `echo "Created: $(git branch --show-current)"` confirmations. Git commands already print useful output. If you need a variable, assign it on a separate line first.

**Multiline strings**: Keep `--description`, `--title`, `--metadata` values on a single line. Use semicolons to separate items.

**`for` loops or multiline blocks**: Instead of `for x in ...; do ... done`, use separate Bash tool calls for each iteration.

**Piping tracker output to Python**: Use jq for all JSON processing of tracker output. `list --json` returns a JSON array — use `jq '.[]'` to iterate.

**Variable assignment of tracker path**: Never assign the tracker command to a variable (e.g., `TRACKER="bash .../tracker.sh"` then `$TRACKER create ...`). The shell treats the variable value as a single token, causing "no such file or directory" errors. Always use the full command directly: `bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" <command>`.

**Hardcoded paths to tracker.sh**: Never use an absolute path like `bash /Users/.../lib/tracker.sh`. Always use `bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"`. Hardcoded paths break when the plugin is installed in a different location.

**Multiple tracker calls in one command**: Each `tracker.sh` invocation MUST be a separate Bash tool call. If the command contains `tracker.sh` more than once (via newlines, semicolons, or any other means), reject it and split into individual calls.

**`source` of tracker.sh**: Never use `source tracker.sh` or `. tracker.sh`. This creates compound commands that trigger permission prompts. Use `bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" <command>` as a standalone command.

**Space-separated subcommands**: Tracker subcommands are hyphenated, not space-separated. Use `dep-add` (not `dep add`), `epic-create` (not `epic create`), `epic-status` (not `epic status`), `epic-close` (not `epic close`), `session-start` (not `session start`), `session-end` (not `session end`).
