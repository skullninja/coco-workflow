#!/usr/bin/env bash
# coco-workflow shared hook helpers.
# Sourced by the hook scripts in this directory. Defines no side effects.

# coco_find_root <start-dir>
# Walks upward from <start-dir> looking for .coco/config.yaml.
# Prints the directory containing .coco/ and returns 0, or returns 1.
#
# Walking upward matters: hooks fire with cwd set to wherever the agent is
# working, which is routinely a package subdirectory (repo/pkg) or a git
# worktree created for parallel task execution. A bare relative
# "[ -f .coco/config.yaml ]" check silently no-ops in both cases.
coco_find_root() {
    local dir="${1:-$PWD}"

    [ -d "$dir" ] || return 1
    dir="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1

    while :; do
        if [ -f "$dir/.coco/config.yaml" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
        [ "$dir" = "/" ] && return 1
        dir="$(dirname "$dir")"
    done
}

# coco_project_root [cwd-hint]
# Resolves the coco project root from a cwd hint, then $CLAUDE_PROJECT_DIR,
# then $PWD. Prints the root and returns 0, or returns 1 if coco is not
# initialized anywhere up the tree.
coco_project_root() {
    local hint="${1:-}"

    if [ -n "$hint" ] && coco_find_root "$hint"; then
        return 0
    fi
    if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && coco_find_root "$CLAUDE_PROJECT_DIR"; then
        return 0
    fi
    coco_find_root "$PWD"
}
