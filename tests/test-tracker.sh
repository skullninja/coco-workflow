#!/usr/bin/env bash
# Test suite for coco_tracker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACKER="$SCRIPT_DIR/../lib/tracker.sh"

# Create a temp directory for test data
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

export COCO_ROOT="$TEST_DIR"
export COCO_DIR="$TEST_DIR/.coco"

source "$TRACKER"

PASS=0
FAIL=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -q "$needle"; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected to contain: $needle"
        echo "    actual: $haystack"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_null() {
    local label="$1" actual="$2"
    if [[ "$actual" != "null" && -n "$actual" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (was null or empty)"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
echo "=== Test: Epic Creation ==="

output=$(coco_tracker epic-create "Test Feature" --description "A test epic")
epic_id=$(echo "$output" | jq -r '.id')
assert_eq "epic has ID" "epic-001" "$epic_id"
assert_eq "epic type" "epic" "$(echo "$output" | jq -r '.type')"
assert_eq "epic status" "open" "$(echo "$output" | jq -r '.status')"
assert_eq "epic title" "Test Feature" "$(echo "$output" | jq -r '.title')"

# ============================================================
echo ""
echo "=== Test: Task Creation ==="

t1=$(coco_tracker create --epic "epic-001" --title "Sub-Phase 1: Setup" --description "Create initial structure" --priority 1)
t1_id=$(echo "$t1" | jq -r '.id')
assert_eq "task 1 ID" "epic-001.1" "$t1_id"
assert_eq "task 1 status" "pending" "$(echo "$t1" | jq -r '.status')"
assert_eq "task 1 epic" "epic-001" "$(echo "$t1" | jq -r '.epic_id')"

t2=$(coco_tracker create --epic "epic-001" --title "Sub-Phase 2: Foundation" --priority 1)
t2_id=$(echo "$t2" | jq -r '.id')
assert_eq "task 2 ID" "epic-001.2" "$t2_id"

t3=$(coco_tracker create --epic "epic-001" --title "Sub-Phase 3: US1" --priority 2)
t3_id=$(echo "$t3" | jq -r '.id')
assert_eq "task 3 ID" "epic-001.3" "$t3_id"

t4=$(coco_tracker create --epic "epic-001" --title "Sub-Phase 4: US2" --priority 2)
t4_id=$(echo "$t4" | jq -r '.id')

t5=$(coco_tracker create --epic "epic-001" --title "Sub-Phase 5: Polish" --priority 3)
t5_id=$(echo "$t5" | jq -r '.id')

# ============================================================
echo ""
echo "=== Test: Dependencies ==="

# Phase 1 blocks Phase 2
coco_tracker dep-add "epic-001.1" --blocks "epic-001.2" >/dev/null
# Phase 2 blocks US1 and US2
coco_tracker dep-add "epic-001.2" --blocks "epic-001.3" >/dev/null
coco_tracker dep-add "epic-001.2" --blocks "epic-001.4" >/dev/null
# US1 and US2 block Polish
coco_tracker dep-add "epic-001.3" --blocks "epic-001.5" >/dev/null
coco_tracker dep-add "epic-001.4" --blocks "epic-001.5" >/dev/null

# Verify dependencies are stored
t2_deps=$(coco_tracker show "epic-001.2" | jq -r '.depends_on | sort | join(",")')
assert_eq "task 2 depends_on" "epic-001.1" "$t2_deps"

t5_deps=$(coco_tracker show "epic-001.5" | jq -r '.depends_on | sort | join(",")')
assert_eq "task 5 depends_on" "epic-001.3,epic-001.4" "$t5_deps"

# ============================================================
echo ""
echo "=== Test: Ready Algorithm ==="

# Only Phase 1 should be ready (no deps)
ready1=$(coco_tracker ready --json --epic "epic-001")
ready1_id=$(echo "$ready1" | jq -r '.id')
assert_eq "first ready task" "epic-001.1" "$ready1_id"

# Close Phase 1 -> Phase 2 should become ready
coco_tracker close "epic-001.1" >/dev/null
ready2=$(coco_tracker ready --json --epic "epic-001")
ready2_id=$(echo "$ready2" | jq -r '.id')
assert_eq "after closing phase 1, phase 2 is ready" "epic-001.2" "$ready2_id"

# Close Phase 2 -> US1 and US2 should both be ready (parallel)
coco_tracker close "epic-001.2" >/dev/null
# ready returns first by priority+creation order, but both should be available
all_ready=$(jq -s -c --arg epic "epic-001" '
    [.[] | select(.status == "completed" or .status == "closed") | .id] as $done |
    [.[] | select(.type == "task" and .status == "pending" and .epic_id == $epic)] |
    [.[] | select(((.depends_on // []) - $done) | length == 0)] |
    [.[].id] | sort
' "$TASKS_FILE")
assert_eq "US1 and US2 both ready" '["epic-001.3","epic-001.4"]' "$all_ready"

# Close US1, Polish still blocked (US2 still pending)
coco_tracker close "epic-001.3" >/dev/null
ready_after_us1=$(coco_tracker ready --json --epic "epic-001")
ready_after_us1_id=$(echo "$ready_after_us1" | jq -r '.id')
assert_eq "after US1 closed, US2 is next (polish still blocked)" "epic-001.4" "$ready_after_us1_id"

# Close US2, Polish should be ready
coco_tracker close "epic-001.4" >/dev/null
ready_final=$(coco_tracker ready --json --epic "epic-001")
ready_final_id=$(echo "$ready_final" | jq -r '.id')
assert_eq "after US1+US2 closed, polish is ready" "epic-001.5" "$ready_final_id"

# Close Polish -> no more ready tasks
coco_tracker close "epic-001.5" >/dev/null
ready_none=$(coco_tracker ready --json --epic "epic-001")
assert_eq "all tasks done, ready returns null" "null" "$ready_none"

# ============================================================
echo ""
echo "=== Test: Metadata ==="

# Create a new epic and task with metadata
coco_tracker epic-create "Metadata Test" >/dev/null
mt=$(coco_tracker create --epic "epic-002" --title "Test task" --metadata '{"issue_key":"PROJ-42","sub_phase":1}')
mt_id=$(echo "$mt" | jq -r '.id')
mt_issue=$(echo "$mt" | jq -r '.metadata.issue_key')
assert_eq "metadata issue_key" "PROJ-42" "$mt_issue"

# Update metadata (merge)
coco_tracker update "$mt_id" --metadata '{"owns_files":["src/foo.ts"]}' >/dev/null
mt_updated=$(coco_tracker show "$mt_id")
assert_eq "metadata preserved after merge" "PROJ-42" "$(echo "$mt_updated" | jq -r '.metadata.issue_key')"
assert_eq "metadata added" "src/foo.ts" "$(echo "$mt_updated" | jq -r '.metadata.owns_files[0]')"

# ============================================================
echo ""
echo "=== Test: Status Update ==="

coco_tracker update "$mt_id" --status "in_progress" >/dev/null
mt_status=$(coco_tracker show "$mt_id" | jq -r '.status')
assert_eq "status updated to in_progress" "in_progress" "$mt_status"

# ============================================================
echo ""
echo "=== Test: List ==="

all_tasks=$(coco_tracker list --json)
count=$(echo "$all_tasks" | jq 'length')
assert_eq "total task count" "6" "$count"

open_tasks=$(coco_tracker list --status "in_progress" --json)
open_count=$(echo "$open_tasks" | jq 'length')
assert_eq "in_progress task count" "1" "$open_count"

# ============================================================
echo ""
echo "=== Test: Session ==="

coco_tracker session-start "Test session" >/dev/null
coco_tracker session-end >/dev/null
session_count=$(wc -l < "$SESSIONS_FILE" | tr -d ' ')
assert_eq "session records" "2" "$session_count"

# ============================================================
echo ""
echo "=== Test: Epic Status ==="

output=$(coco_tracker epic-status "epic-001")
assert_contains "epic status shows title" "Test Feature" "$output"

# ============================================================
echo ""
echo "=== Test: Epic Close ==="

coco_tracker epic-close "epic-001" >/dev/null
epic_status=$(coco_tracker show "epic-001" | jq -r '.status')
assert_eq "epic closed" "closed" "$epic_status"

# ============================================================
echo ""
echo "=== Test: Task Without Epic ==="

standalone=$(coco_tracker create --title "Standalone task" --priority 1)
standalone_id=$(echo "$standalone" | jq -r '.id')
assert_eq "standalone task has task- prefix" "task-001" "$standalone_id"
assert_eq "standalone epic_id is null" "null" "$(echo "$standalone" | jq -r '.epic_id')"

# ============================================================
echo ""
echo "=== Test: Update Field Variants ==="

# Create a task to update
coco_tracker epic-create "Update Tests" >/dev/null
upd=$(coco_tracker create --epic "epic-003" --title "Original title" --priority 3)
upd_id=$(echo "$upd" | jq -r '.id')

coco_tracker update "$upd_id" --title "New title" >/dev/null
assert_eq "title updated" "New title" "$(coco_tracker show "$upd_id" | jq -r '.title')"

coco_tracker update "$upd_id" --description "Added description" >/dev/null
assert_eq "description updated" "Added description" "$(coco_tracker show "$upd_id" | jq -r '.description')"

coco_tracker update "$upd_id" --priority 1 >/dev/null
assert_eq "priority updated" "1" "$(coco_tracker show "$upd_id" | jq -r '.priority')"

# ============================================================
echo ""
echo "=== Test: Close With Reason ==="

coco_tracker close "$upd_id" "Duplicate task" >/dev/null
upd_closed=$(coco_tracker show "$upd_id")
assert_eq "close reason stored" "Duplicate task" "$(echo "$upd_closed" | jq -r '.close_reason')"
assert_not_null "closed_at timestamp set" "$(echo "$upd_closed" | jq -r '.closed_at')"

# ============================================================
echo ""
echo "=== Test: ID Collision Avoidance ==="

# epic-001 already exists with tasks epic-001.1 through epic-001.5
# Creating a new epic should be epic-004 (not collide with epic-001.x)
new_epic=$(coco_tracker epic-create "Collision Test")
new_epic_id=$(echo "$new_epic" | jq -r '.id')
assert_eq "new epic avoids collision with dotted IDs" "epic-004" "$new_epic_id"

# Create tasks in new epic, verify sequential numbering
ct1=$(coco_tracker create --epic "epic-004" --title "CT Task 1")
ct2=$(coco_tracker create --epic "epic-004" --title "CT Task 2")
assert_eq "first task in new epic" "epic-004.1" "$(echo "$ct1" | jq -r '.id')"
assert_eq "second task in new epic" "epic-004.2" "$(echo "$ct2" | jq -r '.id')"

# Second standalone task should be task-002 (task-001 exists from earlier)
standalone2=$(coco_tracker create --title "Another standalone" --priority 2)
assert_eq "standalone ID increments correctly" "task-002" "$(echo "$standalone2" | jq -r '.id')"

# ============================================================
echo ""
echo "=== Test: Ready Across Epics ==="

# epic-004 has two pending tasks with no deps -- ready without --epic should find them
ready_all=$(coco_tracker ready --json)
ready_all_id=$(echo "$ready_all" | jq -r '.id')
# Should return a task (not null) -- exact ID depends on priority sort
assert_not_null "cross-epic ready finds a task" "$ready_all_id"

# ============================================================
echo ""
echo "=== Test: Error Handling ==="

# Missing required args
create_err=$(coco_tracker create 2>&1 || true)
assert_contains "create without --title errors" "ERROR" "$create_err"

epic_create_err=$(coco_tracker epic-create 2>&1 || true)
assert_contains "epic-create without title errors" "ERROR" "$epic_create_err"

dep_add_err=$(coco_tracker dep-add 2>&1 || true)
assert_contains "dep-add without args errors" "ERROR" "$dep_add_err"

# Non-existent IDs
show_err=$(coco_tracker show "nonexistent-999" 2>&1 || true)
assert_contains "show non-existent ID errors" "ERROR" "$show_err"

update_err=$(coco_tracker update "nonexistent-999" --status "in_progress" 2>&1 || true)
assert_contains "update non-existent ID errors" "ERROR" "$update_err"

close_err=$(coco_tracker close "nonexistent-999" 2>&1 || true)
assert_contains "close non-existent ID errors" "ERROR" "$close_err"

dep_add_bad=$(coco_tracker dep-add "nonexistent-999" --blocks "epic-004.1" 2>&1 || true)
assert_contains "dep-add with bad dependency errors" "ERROR" "$dep_add_bad"

# Unknown subcommand
unknown_err=$(coco_tracker foobar 2>&1 || true)
assert_contains "unknown subcommand errors" "ERROR" "$unknown_err"

# ============================================================
echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed"
echo "==============================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
