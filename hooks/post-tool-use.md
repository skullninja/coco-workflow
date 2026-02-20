---
event: PostToolUse
match_tool: Write|Edit
---

After a file was written or edited, check if coco-workflow quality commands are configured and run them.

## Steps

1. Check if `.coco/config.yaml` exists. If not, do nothing.
2. Read the `quality` section from `.coco/config.yaml`.
3. If `quality.lint_command` is empty AND `quality.typecheck_command` is empty, do nothing.
4. Determine the file path that was just modified from the tool result.
5. If the file matches any pattern in `pr.review.exclude_patterns` (e.g., `*.lock`, `*.generated.*`, `vendor/**`, `node_modules/**`), skip quality checks.

### Run lint command

If `quality.lint_command` is configured:

```bash
{lint_command with {file} replaced by the actual file path}
```

If lint fails and `quality.auto_fix` is true:
```bash
{lint_command} --fix {file}
```

Report lint issues to the agent so they can be addressed.

### Run typecheck command

If `quality.typecheck_command` is configured:

```bash
{typecheck_command with {file} replaced by the actual file path}
```

Report typecheck issues to the agent so they can be addressed.

## Important

- Do NOT block the agent. Report issues as informational feedback.
- If neither quality command is configured, exit silently with no output.
- Only check the file that was just modified, not the entire project.
