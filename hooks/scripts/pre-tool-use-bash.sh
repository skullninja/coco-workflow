#!/usr/bin/env bash
# coco-workflow PreToolUse Bash guardrail.
#
# Emits a PreToolUse "deny" permission decision for the narrow set of commands
# that fail SILENTLY -- where the model gets no error to recover from. Denying
# blocks the single tool call and hands the reason back to Claude, which then
# rewrites and continues.
#
# Scope is deliberately minimal. Rules that only avoided permission prompts
# were dropped once autonomous / skip-permissions modes made them redundant,
# and cosmetic rules were dropped because a recoverable deny is not free: it
# costs a turn, and repeated denials starve /coco:loop's no_progress counter
# until the circuit breaker fires. Add a rule here only if the command would
# otherwise corrupt state or resolve wrongly with no visible error.
#
# This MUST stay a command-type hook. A prompt-type hook cannot express a
# recoverable denial: Claude Code maps a prompt hook's "condition not met"
# verdict to preventContinuation, which halts the entire turn. Verified against
# CLI 2.1.220 -- a command hook's permissionDecision:"deny" sets a blockingError
# and never preventContinuation, and permissionDecisionReason is preserved.
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

# --- Silent-failure rules ----------------------------------------------------
#
# Only two rules remain. Both catch commands that fail WITHOUT an error the
# model can see and recover from -- the metadata is silently dropped, or the
# path silently resolves wrong. Everything the model would find out about
# anyway (a clear tracker error, a file-not-found) is left alone: a recoverable
# deny still costs a turn, and enough of them in a row trip /coco:loop's
# no_progress circuit breaker.
#
# Deliberately NOT enforced -- see tests/test-hooks.sh for regression coverage:
#   cd &&              -- only ever avoided a permission prompt, which
#                         autonomous / skip-permissions modes already handle
#   >=2 tracker calls  -- cosmetic; both calls run correctly
#   tracker | python   -- cosmetic; python parses the JSON fine
#   tracker.sh by path -- fails loudly with a clear error
#   'epic create'      -- the tracker itself prints a usage error

if matches '(^|[[:space:];&|(])[A-Za-z_]*TRACKER[A-Za-z_]*='; then
    deny "Blocked: tracker assigned to a shell variable. Variable expansion breaks path resolution here. Call the bare command directly: coco-tracker <subcommand> [args]."
fi

if matches 'coco-tracker' && is_multiline; then
    deny "Blocked: coco-tracker command spans multiple lines. The jq parser splits on newlines -- titles get truncated and --metadata becomes invalid JSON, which the tracker discards as '{}' without failing. Collapse the command and all argument values onto one line; separate list items with '; '."
fi

exit 0
