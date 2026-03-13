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
