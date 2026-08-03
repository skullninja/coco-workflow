#!/usr/bin/env bash
# coco-workflow PreToolUse Bash guardrail.
#
# Emits a PreToolUse "deny" permission decision for commands that would
# actually break -- primarily tracker misuse. Denying blocks the single tool
# call and hands the reason back to Claude, which then rewrites and continues.
#
# This MUST stay a command-type hook. A prompt-type hook cannot express a
# recoverable denial: Claude Code maps a prompt hook's "condition not met"
# verdict to preventContinuation, which halts the entire turn.
#
# Silent exit 0 (= allow) when coco is not initialized, or no rule matches.
set -u

LIB_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=coco-lib.sh
. "$LIB_DIR/coco-lib.sh"

INPUT="$(cat)"

COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -n "$COMMAND" ] || exit 0

CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
coco_project_root "$CWD" >/dev/null || exit 0

deny() {
    jq -n --arg reason "$1" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
}

matches() {
    printf '%s' "$COMMAND" | grep -qE "$1"
}

is_multiline() {
    case "$COMMAND" in
        *"
"*) return 0 ;;
        *) return 1 ;;
    esac
}

# grep -o (not -c): -c counts matching lines, so two calls on one line read as one.
TRACKER_CALLS="$(printf '%s' "$COMMAND" | grep -oF 'coco-tracker' | wc -l | tr -d '[:space:]')"
[ -n "$TRACKER_CALLS" ] || TRACKER_CALLS=0

# --- Tracker invocation form -------------------------------------------------

if matches 'tracker\.sh'; then
    deny "Blocked: tracker.sh invoked by path. The plugin installs a 'coco-tracker' executable on PATH. Rewrite as: coco-tracker <subcommand> [args]. Do not use 'bash \${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh', an absolute path, or 'source'."
fi

if matches '(^|[[:space:];&|(])[A-Za-z_]*TRACKER[A-Za-z_]*='; then
    deny "Blocked: tracker assigned to a shell variable. Variable expansion breaks path resolution here. Call the bare command directly: coco-tracker <subcommand> [args]."
fi

if matches '(^|[^[:alnum:]_-])coco-tracker[[:space:]]+(dep[[:space:]]+add|epic[[:space:]]+(create|status|close)|session[[:space:]]+(start|end))'; then
    deny "Blocked: tracker subcommand written with a space. Subcommands are hyphenated: dep-add, epic-create, epic-status, epic-close, session-start, session-end."
fi

# --- Tracker call shape ------------------------------------------------------

if [ "$TRACKER_CALLS" -ge 2 ]; then
    deny "Blocked: $TRACKER_CALLS coco-tracker calls in one command. Each tracker call must be its own Bash tool call -- batching them breaks error attribution. Split into separate Bash invocations."
fi

if [ "$TRACKER_CALLS" -ge 1 ] && is_multiline; then
    deny "Blocked: coco-tracker command spans multiple lines. The jq parser splits on newlines -- titles get truncated and --metadata becomes invalid JSON ('invalid JSON text passed to --argjson'). Collapse the command and all argument values onto one line; separate list items with '; '."
fi

if matches '(^|[^[:alnum:]_-])coco-tracker[^|]*\|[[:space:]]*python3?'; then
    deny "Blocked: tracker output piped to Python. Use jq for all JSON processing. Note 'list --json' returns an array (iterate with jq '.[]'), while 'show ID' and 'ready --json' return a single object."
fi

# --- Shell forms that trigger security prompts -------------------------------

if matches '(^|[;&|(]|[[:space:]])cd[[:space:]]+[^;&|]*&&'; then
    deny "Blocked: 'cd <path> && <command>' triggers a bare-repository-attack security prompt. Drop the cd if the working directory is already correct, or issue the cd and the command as two separate Bash tool calls. Other && chaining is fine -- only cd compounds are blocked."
fi

exit 0
