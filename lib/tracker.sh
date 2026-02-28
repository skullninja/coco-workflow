#!/usr/bin/env bash
# coco-workflow task tracker
# Replaces the bd CLI with a simple JSONL-based task/dependency tracker.
# Requires: bash 4+, jq 1.6+
#
# Usage: coco_tracker <subcommand> [args]
#
# Data lives in .coco/tasks/tasks.jsonl (one JSON record per line).
# Two record types: "epic" and "task".

set -euo pipefail

# --- Configuration ---

_coco_find_root() {
    if git rev-parse --show-toplevel 2>/dev/null; then
        return
    fi
    # Fallback: walk up looking for .coco/
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.coco" ]]; then
            echo "$dir"
            return
        fi
        dir="$(dirname "$dir")"
    done
    echo "$PWD"
}

COCO_ROOT="${COCO_ROOT:-$(_coco_find_root)}"
COCO_DIR="${COCO_DIR:-$COCO_ROOT/.coco}"
TASKS_DIR="$COCO_DIR/tasks"
TASKS_FILE="$TASKS_DIR/tasks.jsonl"
SESSIONS_FILE="$TASKS_DIR/sessions.jsonl"

_coco_ensure_dirs() {
    mkdir -p "$TASKS_DIR"
    touch "$TASKS_FILE" "$SESSIONS_FILE"
}

# --- ID Generation ---

_coco_next_id() {
    local prefix="$1"
    local max_num=0
    if [[ -s "$TASKS_FILE" ]]; then
        # Match only IDs that are exactly prefix + digits (no trailing dots/suffixes)
        local found
        found=$(jq -r --arg p "$prefix" 'select(.id | test("^" + $p + "\\d+$")) | .id' "$TASKS_FILE" 2>/dev/null | \
            sed "s/^${prefix}//" | sort -n | tail -1)
        if [[ -n "$found" && "$found" =~ ^[0-9]+$ ]]; then
            max_num="$found"
        fi
    fi
    printf "%s%03d" "$prefix" $((max_num + 1))
}

_coco_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# --- JSONL Operations ---
# We use a "last write wins" approach: to update a record, we rewrite the file
# with the updated record replacing the old one.

_coco_read_record() {
    local id="$1"
    if [[ ! -s "$TASKS_FILE" ]]; then
        return 1
    fi
    local record
    record=$(jq -c --arg id "$id" 'select(.id == $id)' "$TASKS_FILE" 2>/dev/null | tail -1)
    if [[ -z "$record" ]]; then
        return 1
    fi
    echo "$record"
}

_coco_write_record() {
    local record="$1"
    local id
    id=$(echo "$record" | jq -r '.id')

    _coco_ensure_dirs

    if [[ -s "$TASKS_FILE" ]] && jq -e --arg id "$id" 'select(.id == $id)' "$TASKS_FILE" >/dev/null 2>&1; then
        # Update existing: rewrite file with replacement
        local tmp="${TASKS_FILE}.tmp"
        jq -c --arg id "$id" --argjson new "$record" \
            'if .id == $id then $new else . end' "$TASKS_FILE" > "$tmp"
        mv "$tmp" "$TASKS_FILE"
    else
        # New record: append
        echo "$record" >> "$TASKS_FILE"
    fi
}

_coco_list_records() {
    local type_filter="${1:-}"
    local status_filter="${2:-}"
    local epic_filter="${3:-}"

    if [[ ! -s "$TASKS_FILE" ]]; then
        echo "[]"
        return
    fi

    local filter="."
    if [[ -n "$type_filter" ]]; then
        filter="$filter | select(.type == \"$type_filter\")"
    fi
    if [[ -n "$status_filter" ]]; then
        filter="$filter | select(.status == \"$status_filter\")"
    fi
    if [[ -n "$epic_filter" ]]; then
        filter="$filter | select(.epic_id == \"$epic_filter\")"
    fi

    jq -s -c "[.[] | $filter]" "$TASKS_FILE" 2>/dev/null || echo "[]"
}

# --- Epic Commands ---

_cmd_epic_create() {
    local title=""
    local description=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --description) description="$2"; shift 2 ;;
            *) if [[ -z "$title" ]]; then title="$1"; shift; else echo "ERROR: unexpected arg: $1" >&2; return 1; fi ;;
        esac
    done

    if [[ -z "$title" ]]; then
        echo "ERROR: epic-create requires a title" >&2
        return 1
    fi

    # Sanitize: replace literal newlines with spaces to prevent JSONL corruption
    title="${title//$'\n'/ }"
    description="${description//$'\n'/ }"

    _coco_ensure_dirs
    local id
    id=$(_coco_next_id "epic-")
    local now
    now=$(_coco_timestamp)

    local record
    record=$(jq -nc \
        --arg id "$id" \
        --arg title "$title" \
        --arg desc "$description" \
        --arg now "$now" \
        '{id:$id, type:"epic", title:$title, description:$desc, status:"open", created_at:$now, updated_at:$now}')

    _coco_write_record "$record"
    echo "$record" | jq .
}

_cmd_epic_status() {
    local epic_id="${1:-}"

    if [[ -n "$epic_id" ]]; then
        # Show specific epic + its tasks
        local epic
        epic=$(_coco_read_record "$epic_id") || { echo "ERROR: epic not found: $epic_id" >&2; return 1; }
        echo "$epic" | jq .
        echo "---"
        echo "Tasks:"
        if [[ -s "$TASKS_FILE" ]]; then
            jq -c --arg eid "$epic_id" 'select(.type == "task" and .epic_id == $eid)' "$TASKS_FILE" | \
                jq -r '[.id, .status, .title] | @tsv' | \
                column -t -s $'\t'
        fi
    else
        # Show all epics with task counts
        if [[ ! -s "$TASKS_FILE" ]]; then
            echo "No epics found."
            return
        fi
        jq -c 'select(.type == "epic")' "$TASKS_FILE" | while IFS= read -r epic; do
            local eid etitle estatus total done
            eid=$(echo "$epic" | jq -r '.id')
            etitle=$(echo "$epic" | jq -r '.title')
            estatus=$(echo "$epic" | jq -r '.status')
            total=$(jq -s --arg eid "$eid" '[.[] | select(.type == "task" and .epic_id == $eid)] | length' "$TASKS_FILE")
            done=$(jq -s --arg eid "$eid" '[.[] | select(.type == "task" and .epic_id == $eid and (.status == "completed" or .status == "closed"))] | length' "$TASKS_FILE")
            printf "%-12s %-8s %s (%d/%d tasks)\n" "$eid" "$estatus" "$etitle" "$done" "$total"
        done
    fi
}

_cmd_epic_close() {
    local epic_id="$1"
    if [[ -z "$epic_id" ]]; then
        echo "ERROR: epic-close requires an epic ID" >&2
        return 1
    fi

    local epic
    epic=$(_coco_read_record "$epic_id") || { echo "ERROR: epic not found: $epic_id" >&2; return 1; }

    local now
    now=$(_coco_timestamp)
    epic=$(echo "$epic" | jq -c --arg now "$now" '.status = "closed" | .updated_at = $now | .closed_at = $now')
    _coco_write_record "$epic"
    echo "Epic $epic_id closed."
}

# --- Task Commands ---

_cmd_create() {
    local epic_id="" title="" description="" depends_on="" metadata="{}" priority=2

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --epic) epic_id="$2"; shift 2 ;;
            --title) title="$2"; shift 2 ;;
            --description) description="$2"; shift 2 ;;
            --depends-on) depends_on="$2"; shift 2 ;;
            --metadata) metadata="$2"; shift 2 ;;
            --priority) priority="$2"; shift 2 ;;
            *) echo "ERROR: unknown option: $1" >&2; return 1 ;;
        esac
    done

    if [[ -z "$title" ]]; then
        echo "ERROR: create requires --title" >&2
        return 1
    fi

    # Sanitize: replace literal newlines with spaces to prevent JSONL corruption
    title="${title//$'\n'/ }"
    description="${description//$'\n'/ }"

    _coco_ensure_dirs

    # Generate ID: if epic provided, use epic prefix
    local id
    if [[ -n "$epic_id" ]]; then
        # Count existing tasks in this epic to determine suffix
        local count=0
        if [[ -s "$TASKS_FILE" ]]; then
            count=$(jq -s --arg eid "$epic_id" '[.[] | select(.type == "task" and .epic_id == $eid)] | length' "$TASKS_FILE")
        fi
        id=$(printf "%s.%d" "$epic_id" $((count + 1)))
    else
        id=$(_coco_next_id "task-")
    fi

    # Parse depends_on comma-separated list into JSON array
    local deps_json="[]"
    if [[ -n "$depends_on" ]]; then
        deps_json=$(echo "$depends_on" | tr ',' '\n' | jq -R . | jq -sc .)
    fi

    local now
    now=$(_coco_timestamp)

    local record
    record=$(jq -nc \
        --arg id "$id" \
        --arg epic_id "$epic_id" \
        --arg title "$title" \
        --arg desc "$description" \
        --arg status "pending" \
        --argjson priority "$priority" \
        --argjson depends_on "$deps_json" \
        --argjson metadata "$metadata" \
        --arg now "$now" \
        '{
            id: $id,
            type: "task",
            epic_id: (if $epic_id == "" then null else $epic_id end),
            title: $title,
            description: $desc,
            status: $status,
            priority: $priority,
            depends_on: $depends_on,
            metadata: $metadata,
            created_at: $now,
            updated_at: $now,
            closed_at: null
        }')

    _coco_write_record "$record"
    echo "$record" | jq .
}

_cmd_update() {
    local id="$1"; shift
    if [[ -z "$id" ]]; then
        echo "ERROR: update requires a task ID" >&2
        return 1
    fi

    local record
    record=$(_coco_read_record "$id") || { echo "ERROR: task not found: $id" >&2; return 1; }

    local now
    now=$(_coco_timestamp)

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --status)
                record=$(echo "$record" | jq -c --arg s "$2" --arg now "$now" '.status = $s | .updated_at = $now')
                shift 2
                ;;
            --metadata)
                # Merge metadata (new keys override, existing keys preserved)
                record=$(echo "$record" | jq -c --argjson m "$2" --arg now "$now" '.metadata = (.metadata // {} | . * $m) | .updated_at = $now')
                shift 2
                ;;
            --title)
                local _t="${2//$'\n'/ }"
                record=$(echo "$record" | jq -c --arg t "$_t" --arg now "$now" '.title = $t | .updated_at = $now')
                shift 2
                ;;
            --description)
                local _d="${2//$'\n'/ }"
                record=$(echo "$record" | jq -c --arg d "$_d" --arg now "$now" '.description = $d | .updated_at = $now')
                shift 2
                ;;
            --priority)
                record=$(echo "$record" | jq -c --argjson p "$2" --arg now "$now" '.priority = $p | .updated_at = $now')
                shift 2
                ;;
            *)
                echo "ERROR: unknown update option: $1" >&2
                return 1
                ;;
        esac
    done

    _coco_write_record "$record"
    echo "$record" | jq .
}

_cmd_close() {
    local id="$1"; shift
    local reason="${1:-Closed}"

    if [[ -z "$id" ]]; then
        echo "ERROR: close requires a task ID" >&2
        return 1
    fi

    local record
    record=$(_coco_read_record "$id") || { echo "ERROR: task not found: $id" >&2; return 1; }

    local now
    now=$(_coco_timestamp)
    record=$(echo "$record" | jq -c \
        --arg now "$now" \
        --arg reason "$reason" \
        '.status = "completed" | .updated_at = $now | .closed_at = $now | .close_reason = $reason')

    _coco_write_record "$record"
    echo "Task $id closed."
}

_cmd_show() {
    local id="$1"
    if [[ -z "$id" ]]; then
        echo "ERROR: show requires a task/epic ID" >&2
        return 1
    fi

    local record
    record=$(_coco_read_record "$id") || { echo "ERROR: not found: $id" >&2; return 1; }
    echo "$record" | jq .
}

_cmd_list() {
    local status_val="" epic="" json=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --status) status_val="$2"; shift 2 ;;
            --epic) epic="$2"; shift 2 ;;
            --json) json=true; shift ;;
            *) echo "ERROR: unknown list option: $1" >&2; return 1 ;;
        esac
    done

    if [[ ! -s "$TASKS_FILE" ]]; then
        if $json; then echo "[]"; else echo "No tasks found."; fi
        return
    fi

    local filter="select(.type == \"task\")"
    if [[ -n "$status_val" ]]; then
        filter="$filter | select(.status == \"$status_val\")"
    fi
    if [[ -n "$epic" ]]; then
        filter="$filter | select(.epic_id == \"$epic\")"
    fi

    if $json; then
        jq -s -c "[.[] | $filter]" "$TASKS_FILE"
    else
        jq -c "$filter" "$TASKS_FILE" | \
            jq -r '[.id, .status, .priority, .title] | @tsv' | \
            column -t -s $'\t'
    fi
}

# --- Dependency Commands ---

_cmd_dep_add() {
    local id="" blocks=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --blocks) blocks="$2"; shift 2 ;;
            *) if [[ -z "$id" ]]; then id="$1"; shift; else echo "ERROR: unexpected arg: $1" >&2; return 1; fi ;;
        esac
    done

    if [[ -z "$id" || -z "$blocks" ]]; then
        echo "ERROR: dep-add requires ID and --blocks OTHER_ID" >&2
        echo "Usage: coco_tracker dep-add TASK_ID --blocks BLOCKED_TASK_ID" >&2
        echo "  Meaning: TASK_ID must complete before BLOCKED_TASK_ID can start." >&2
        return 1
    fi

    # Add $id to the depends_on list of $blocks
    local blocked_record
    blocked_record=$(_coco_read_record "$blocks") || { echo "ERROR: blocked task not found: $blocks" >&2; return 1; }

    # Verify the dependency task exists
    _coco_read_record "$id" >/dev/null || { echo "ERROR: dependency task not found: $id" >&2; return 1; }

    local now
    now=$(_coco_timestamp)
    blocked_record=$(echo "$blocked_record" | jq -c \
        --arg dep "$id" \
        --arg now "$now" \
        '.depends_on = ((.depends_on // []) + [$dep] | unique) | .updated_at = $now')

    _coco_write_record "$blocked_record"
    echo "Added dependency: $blocks depends on $id"
}

# --- Ready Command (Core Algorithm) ---

_cmd_ready() {
    local json=false epic=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) json=true; shift ;;
            --epic) epic="$2"; shift 2 ;;
            --all) shift ;; # For future use, currently returns all ready
            *) echo "ERROR: unknown ready option: $1" >&2; return 1 ;;
        esac
    done

    if [[ ! -s "$TASKS_FILE" ]]; then
        if $json; then echo "null"; else echo "No tasks found."; fi
        return
    fi

    # The ready algorithm:
    # 1. Get all completed/closed task IDs
    # 2. Get all pending tasks (optionally filtered by epic)
    # 3. For each pending task, check if all depends_on are completed/closed
    # 4. Sort by priority (ascending) then created_at
    # 5. Return the first one (or null if none ready)

    local epic_filter=""
    if [[ -n "$epic" ]]; then
        epic_filter="and .epic_id == \$epic"
    fi

    local result
    result=$(jq -s -c --arg epic "$epic" "
        # Build set of completed IDs
        [.[] | select(.status == \"completed\" or .status == \"closed\") | .id] as \$done |

        # Find pending tasks (optionally filtered by epic)
        [.[] | select(.type == \"task\" and .status == \"pending\" $epic_filter)] |

        # Filter to those whose deps are all satisfied
        [.[] | select(
            ((.depends_on // []) - \$done) | length == 0
        )] |

        # Sort by priority asc, then created_at asc
        sort_by(.priority, .created_at)
    " "$TASKS_FILE")

    if $json; then
        # Return first ready task or null
        echo "$result" | jq -c '.[0] // null'
    else
        local count
        count=$(echo "$result" | jq 'length')
        if [[ "$count" -eq 0 ]]; then
            echo "No ready tasks."
        else
            echo "$result" | jq -r '.[] | [.id, .priority, .title] | @tsv' | column -t -s $'\t'
        fi
    fi
}

# --- Session Commands ---

_cmd_session_start() {
    local description="${1:-Session}"
    _coco_ensure_dirs
    local now
    now=$(_coco_timestamp)
    local record
    record=$(jq -nc \
        --arg desc "$description" \
        --arg now "$now" \
        '{type:"session_start", description:$desc, timestamp:$now}')
    echo "$record" >> "$SESSIONS_FILE"
    echo "Session started: $description"
}

_cmd_session_end() {
    _coco_ensure_dirs
    local now
    now=$(_coco_timestamp)
    local record
    record=$(jq -nc --arg now "$now" '{type:"session_end", timestamp:$now}')
    echo "$record" >> "$SESSIONS_FILE"
    echo "Session ended."
}

# --- Sync Command ---

_cmd_sync() {
    if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
        echo "ERROR: not in a git repository" >&2
        return 1
    fi

    git add "$TASKS_DIR/" 2>/dev/null || true
    if git diff --cached --quiet "$TASKS_DIR/" 2>/dev/null; then
        echo "Task state already in sync with git."
    else
        git commit -m "coco: sync task state" -- "$TASKS_DIR/" >/dev/null
        echo "Task state committed to git."
    fi
}

# --- Main Dispatch ---

coco_tracker() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        create)         _cmd_create "$@" ;;
        update)         _cmd_update "$@" ;;
        close)          _cmd_close "$@" ;;
        show)           _cmd_show "$@" ;;
        list)           _cmd_list "$@" ;;
        epic-create)    _cmd_epic_create "$@" ;;
        epic-status)    _cmd_epic_status "$@" ;;
        epic-close)     _cmd_epic_close "$@" ;;
        dep-add)        _cmd_dep_add "$@" ;;
        ready)          _cmd_ready "$@" ;;
        session-start)  _cmd_session_start "$@" ;;
        session-end)    _cmd_session_end "$@" ;;
        sync)           _cmd_sync "$@" ;;
        help|--help|-h)
            cat <<'EOF'
coco_tracker - JSONL-based task tracker for coco-workflow

Usage: coco_tracker <subcommand> [args]

Task Commands:
  create --title "..." [--epic ID] [--depends-on ID,ID] [--metadata '{}'] [--priority N]
  update ID [--status STATUS] [--metadata '{}'] [--title "..."] [--priority N]
  close ID [REASON]
  show ID
  list [--status STATUS] [--epic ID] [--json]

Epic Commands:
  epic-create "Title" [--description "..."]
  epic-status [EPIC_ID]
  epic-close EPIC_ID

Dependency Commands:
  dep-add TASK_ID --blocks BLOCKED_TASK_ID

Ready (find next unblocked task):
  ready [--json] [--epic ID]

Session Commands:
  session-start "Description"
  session-end

Sync:
  sync                             # Stage + commit task state to git
EOF
            ;;
        *)
            echo "ERROR: unknown command: $cmd" >&2
            echo "Run 'coco_tracker help' for usage." >&2
            return 1
            ;;
    esac
}

# Allow sourcing or direct execution (compatible with both bash and zsh)
if [ -n "${BASH_VERSION:-}" ] && [ "${BASH_SOURCE[0]}" = "$0" ]; then
    coco_tracker "$@"
fi
