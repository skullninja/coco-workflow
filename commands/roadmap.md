---
argument-hint: [release name, e.g., "v1.0" or "MVP"]
description: Generate or update a per-release roadmap from the PRD and analysis documents. Triages features, groups into phases, and produces a structured roadmap.
allowed-tools: AskUserQuestion, Read, Write, Glob, Grep
---

## User Input

```text
$ARGUMENTS
```

## Setup

1. Read `.coco/config.yaml` for:
   - `discovery.prd_path` (default: `docs/prd.md`)
   - `discovery.analysis_dir` (default: `docs/analysis`)
   - `discovery.roadmap_dir` (default: `docs/roadmap`)
   - `project.specs_dir` (default: `specs`)
   - `issue_tracker.provider`
2. `$ARGUMENTS` specifies the release name (e.g., "v1.0", "MVP"). If empty, use `AskUserQuestion` to ask for the release name.
3. Check if a roadmap already exists at `{roadmap_dir}/{release}.md`:
   - If yes, enter **update mode** (load existing roadmap)
   - If no, enter **create mode**

## Execution

### 1. Load Context

**PRD** (required):
Read `{discovery.prd_path}`. If the file does not exist, ERROR: "No PRD found at `{discovery.prd_path}`. Run `/coco:prd` first."

**Analysis docs** (optional):
Glob `{discovery.analysis_dir}/*.md` and read all found documents. Extract:
- Key findings from each
- "Implications for Roadmap" sections

**Constitution** (optional):
Read `.coco/memory/constitution.md` if it exists. Use project principles to inform prioritization.

**Existing specs** (optional):
Glob `{specs_dir}/*/spec.md`. These represent features already specified -- they should appear in the roadmap as already-scoped items.

**Existing roadmap** (update mode only):
Load `{roadmap_dir}/{release}.md`. Preserve Change Log and completed feature statuses.

### 2. Extract Feature Candidates

Build a consolidated feature list from all sources:

| Source | How |
|--------|-----|
| PRD "Feature Candidates" table | Parse rows: name, description, goal(s), priority |
| Analysis "Implications for Roadmap" sections | Extract referenced features and adjustments |
| Existing `specs/` directories | Add as already-specced features |

Deduplicate by name/description similarity. Present the consolidated list to the user:

```
Feature Candidates for {release}
================================
| # | Feature | Source | Already Specced | Notes |
|---|---------|--------|-----------------|-------|
```

Use `AskUserQuestion` to confirm the list:
- Add missing features?
- Remove any?
- Correct descriptions?

### 3. Batch Triage

Score each feature using the Impact/Urgency/Effort framework (from `/planning-triage`):

```
Score = (Impact + Urgency) / Effort
```

| Factor | 1 | 2 | 3 | 4 | 5 |
|--------|---|---|---|---|---|
| **Impact** | No effect on users | Minor convenience | Moderate engagement | Significant daily value | Critical for adoption/retention |
| **Urgency** | Someday/nice-to-have | Next quarter | This month | This week | Today/blocking |
| **Effort** | Multi-week project | ~1 week | ~2-3 days | ~hours | ~minutes |

Use context from:
- PRD goals and priorities to inform Impact
- Analysis findings to adjust Urgency
- Existing spec complexity and code audit to estimate Effort

Present the scored table to the user via `AskUserQuestion`:

```
Feature Triage for {release}
============================
| # | Feature | Impact | Urgency | Effort | Score | Priority |
|---|---------|--------|---------|--------|-------|----------|
```

Allow the user to adjust individual scores or accept the batch.

### 4. Phase Grouping

Analyze inter-feature dependencies:
- Which features require others to be built first? (e.g., auth before user profiles)
- Which features share infrastructure? (group together)
- Which features are independent? (can run in any phase)

Group into phases based on:
1. **Dependencies first** -- features that others depend on go in earlier phases
2. **Priority score** -- higher-scored features go in earlier phases
3. **Phase size** -- aim for 3-5 features per phase (manageable scope)

**Phase naming convention**: "Phase N: {descriptive name}" (e.g., "Phase 1: Foundation", "Phase 2: Core Features")

Present proposed phase grouping to the user via `AskUserQuestion`:

```
Proposed Phases for {release}
=============================
Phase 1: {name}
  - {feature} (Score: {X.X}, depends on: {none})
  - {feature} (Score: {X.X}, depends on: {none})

Phase 2: {name}
  - {feature} (Score: {X.X}, depends on: {Phase 1 feature})
  ...

Unscheduled:
  - {feature} (Score: {X.X}, reason: deferred)
```

Allow the user to rearrange features between phases.

### 5. Write Roadmap

Load the roadmap template from `.coco/templates/roadmap-template.md` if it exists, otherwise use `${CLAUDE_PLUGIN_ROOT}/templates/roadmap-template.md`.

Fill in:
- Release name and metadata (product name from PRD, target date if discussed)
- PRD path reference
- Overview paragraph summarizing the release themes
- Phase sections with feature tables:
  - `#` -- sequential number within phase
  - `Feature` -- feature name
  - `Slug` -- kebab-case slug for `specs/{slug}/` directory
  - `Priority` -- P1/P2/P3
  - `Score` -- triage score
  - `Status` -- "Planned" (new), "In Progress", "Complete", or existing status (update mode)
  - `Spec` -- path to spec directory if exists, otherwise `--`
- Cross-feature dependencies for each phase
- Phase acceptance criteria
- Unscheduled features with reasons
- Change Log entry

**Update mode**: When updating an existing roadmap:
- Preserve the Change Log
- Preserve statuses of completed features
- Add new features, update scores for existing ones
- Append to Change Log: "{date} | Roadmap updated | {reason}"

Ensure the directory exists:

```bash
mkdir -p "{roadmap_dir}"
```

Write to `{roadmap_dir}/{release}.md`.

### 6. Issue Tracker Integration

Based on `issue_tracker.provider`:

**linear:**
- Create an initiative for the release (if one doesn't exist): title = "Roadmap: {release}"
- For each phase, create a project: title = "Phase N: {name}"
- Link projects to the initiative

**github:**
- Create a milestone for the release: title = "{release}"
- Set milestone description to the roadmap overview
- If `github.use_projects` is true: create a GitHub Project per phase:
  ```bash
  gh project create --owner {github.owner} --title "Phase N: {name}" --format "BOARD"
  ```
  Cache phase project metadata in `.coco/state/gh-projects.json` under the `phases` key:
  ```json
  {
    "phases": {
      "Phase 1: Foundation": {
        "project_number": 43,
        "project_id": "PVT_..."
      }
    }
  }
  ```

**none:**
- Skip all issue tracker operations

### 7. Report

Output:
- Path to the roadmap file
- Summary: N features across M phases, N unscheduled
- Top-priority phase: "Phase 1: {name}" with feature count
- Suggested next step: "Run `/coco:phase \"Phase 1: {name}\"` to begin execution"

## Parsing Contract

The roadmap file format is designed to be both human-readable and machine-parseable by `/coco:phase`:

- Phase sections are identified by `### Phase N: {Name}` headers
- Feature tables use a consistent 7-column format: `| # | Feature | Slug | Priority | Score | Status | Spec |`
- The `Slug` column maps directly to `specs/{slug}/` directories
- The `Status` column values are: `Planned`, `In Progress`, `Complete`
- `/coco:phase` reads a specific phase section and extracts features from table rows
- `/coco:loop` updates the `Status` column when features complete

## Notes

- Each release gets its own roadmap file -- this allows parallel releases (e.g., v1.0 and v1.1)
- The roadmap is the source of truth for phase composition; `/coco:phase` reads it directly
- Features can be moved between phases by editing the roadmap and re-running `/coco:roadmap`
- Unscheduled features are preserved across updates for future consideration
