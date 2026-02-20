# Workflow Analysis

Analysis of the coco-workflow system: effectiveness, capabilities, and improvement opportunities.

## Executive Summary

The coco-workflow system unifies planning (spec commands), execution (built-in tracker), and visibility (configurable issue tracker) into a single Claude Code plugin. The system achieves strong autonomy for implementation, good traceability from spec to commit, and zero external dependencies beyond jq.

**Current state:**

- **Autonomy**: High after the interview/specification step; `/coco.loop` drives fully autonomous execution through TDD, commit, and merge with circuit breaker protection
- **Parallelism**: Supported with up to 3 concurrent agents and file-ownership tracking
- **Tracking**: Comprehensive tracker -> issue tracker direction; configurable for Linear, GitHub, or standalone
- **Portability**: Git submodule delivery, config-driven behavior, no project-specific assumptions

---

## Capability Matrix

### Planning Commands

| Command | Purpose | Used in Pipeline |
|---------|---------|-----------------|
| `/coco.spec` | Create spec from natural language | Yes -- primary entry point |
| `/coco.clarify` | Reduce ambiguity (max 5 questions) | Optional -- available for tactical sessions |
| `/coco.plan` | Generate implementation plan | Yes -- produces design artifacts |
| `/coco.tasks` | Generate task list (auto-analyzes) | Yes -- core output for tracker import |
| `/coco.analyze` | Cross-artifact analysis | Yes -- auto-invoked by `/coco.tasks` |
| `/coco.constitution` | Project constitution | Setup phase only |

**Key improvement over previous system**: `/coco.analyze` is now auto-invoked by `/coco.tasks`, ensuring cross-artifact consistency is always checked before import.

### Tracker

| Capability | Description |
|------------|-------------|
| Task CRUD | Create, update, close tasks with status tracking |
| Dependency graphs | `dep-add` + `ready` for topological task selection |
| Epic management | Group tasks into features with progress tracking |
| Session memory | Track work across Claude Code sessions |
| Metadata | Store arbitrary data (issue keys, file ownership, sub-phase) |
| Git sync | Commit tracker state via git |

**Key improvement**: Zero external dependencies. No daemon, no SQLite, no CLI installation. Just bash + jq on JSONL files.

### Issue Tracker Bridge

| Provider | Functions Used |
|----------|---------------|
| **Linear** | create/update project, create/update/get issue, create comment |
| **GitHub** | `gh issue create/edit/close`, `gh pr create` |
| **None** | Tracker-only workflow, no external calls |

**Key improvement**: Issue tracker is configurable rather than hardcoded to Linear. Status mappings, team names, labels, and issue key formats are all config-driven.

---

## Effectiveness Assessment

### Autonomy

**Strengths:**
- After specification, the pipeline runs without human input through import, TDD, commit, and merge
- `/coco.loop` provides fully autonomous execution with circuit breaker protection (inspired by the Ralph loop pattern)
- Error handling has defined fallback paths (issue tracker unavailable -> log + sync later)
- Session management allows interruption and seamless resumption

**Friction points:**

| Point | Impact | Mitigation |
|-------|--------|------------|
| Interview step requires human | Medium | Once per feature; `/coco.spec` auto-fills most fields |
| Pre-commit tester needs project customization | Low | Generic agent with config-driven patterns |

### Parallelism

**Current state:**
- Max 3 concurrent agents for user story sub-phases
- File ownership tracked via tracker task metadata
- Foundation serial, user stories parallel, polish serial

**Bottlenecks:**

| Bottleneck | Description |
|------------|-------------|
| File ownership is self-declared | Agents must set and check `owns_files` metadata |
| Serial foundation | Sub-Phases 1-2 cannot be parallelized |
| No automated conflict detection | Second agent must manually rebase |

### Tracking

**What is tracked:**
- Task state transitions (tracker + issue tracker)
- Dependency graph (tracker)
- Commit -> issue linkage (via `Completes {issue_key}` format)
- Implementation summaries (issue tracker descriptions)
- Test results (issue tracker comments)
- Session history (tracker sessions.jsonl)

---

## Architecture Comparison

### Previous (3 separate tools)

```
Spec-Kit (8 commands) -> Beads (bd CLI, SQLite, daemon) -> Linear (hardcoded)
```

**Problems:**
- Beads required external installation, daemon, SQLite
- Linear was hardcoded (team names, labels, status mappings)
- Everything was project-specific (iOS, Swift, Sommel)
- 3 separate tool configurations

### Current (unified plugin)

```
Coco commands (15) -> Coco tracker (bash+jq) -> Issue tracker (configurable)
```

**Improvements:**
- Zero external dependencies (bash + jq)
- Config-driven issue tracker (Linear / GitHub / none)
- Generic and portable (git submodule)
- Auto-analyze gate in `/coco.tasks`
- Autonomous execution loop (`/coco.loop`) with circuit breaker
- Consolidated command surface (15 commands, 2 skills, 2 agents)
- Two-tier PR workflow with AI code review (`code-reviewer` agent)
- Issues resolve at PR merge, not at commit (proper PR-driven lifecycle)

---

## Gap Analysis

| # | Gap | Impact | Difficulty |
|---|-----|--------|------------|
| ~~G1~~ | ~~No PR automation~~ | **RESOLVED** -- Two-tier PR workflow with AI code review | -- |
| G2 | One-way issue sync | Tracker -> issue tracker only; manual changes not reflected back | Medium |
| G3 | No phase-level analytics | No burndown or velocity metrics | Low |
| G4 | No automated conflict detection | File ownership is self-declared | Low |

## Improvement Recommendations

### High Priority

**1. Bidirectional Sync**
Extend `/coco.sync` to pull issue tracker changes back to the tracker.

### Medium Priority

**2. Phase Velocity Metrics**
New `/coco.metrics` command aggregating tracker timestamps, git log, and issue tracker data.

### Low Priority

**3. Automated Conflict Detection**
Enforce file ownership checking automatically rather than relying on agent self-declaration.

**4. Notification Integration**
Webhook or Slack integration for key pipeline events.
