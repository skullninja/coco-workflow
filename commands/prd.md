---
argument-hint: [product description | "audit" | "derive /path/to/source/prd.md"]
description: Create, audit, or derive a Product Requirements Document. Use "derive" for satellite repos in multi-repo projects.
allowed-tools: AskUserQuestion, Read, Write, Glob, Grep, Bash
---

## User Input

```text
$ARGUMENTS
```

## Setup

1. Read `.coco/config.yaml` for `discovery.prd_path` (default: `docs/prd.md`).
2. Load PRD template from `.coco/templates/prd-template.md` if it exists, otherwise use `${CLAUDE_PLUGIN_ROOT}/templates/prd-template.md`.
3. Determine mode:
   - If `$ARGUMENTS` starts with "derive" -> **Derive mode** (satellite repo)
   - If `$ARGUMENTS` contains "audit" -> **Audit mode**
   - Otherwise -> **Greenfield mode** (use `$ARGUMENTS` as initial product description if non-empty)

## Mode 1: Greenfield (Default)

Guided interview producing a PRD from scratch.

### 1. Product Vision & Problem Statement

If `$ARGUMENTS` provides a product description, use it as context. Otherwise ask:

Use `AskUserQuestion` to gather:
- What is the product? (1-2 sentence vision)
- What problem does it solve? Who has this problem?

### 2. Target Users

Use `AskUserQuestion` to identify 1-3 user personas:
- Role/name for each persona
- Context (when/where they encounter the problem)
- Pain points (current frustrations)
- Goals (what they want to achieve)

### 3. Product Goals

Use `AskUserQuestion` to define measurable goals:
- 3-5 product goals
- Success metric for each
- Priority (P1/P2/P3)

### 4. Scope Boundaries

Use `AskUserQuestion` to establish scope:
- What is explicitly in scope?
- What is explicitly out of scope?

### 5. Constraints

Use `AskUserQuestion` to identify constraints:
- Technical (platform, language, infrastructure)
- Business (timeline, budget, regulatory)
- Design (UX principles, accessibility)

### 6. Feature Candidates

Use `AskUserQuestion` to brainstorm features:
- List candidate features (name + brief description)
- Map each to product goals
- Assign initial priority (P1/P2/P3)

Present the feature table and ask for additions or changes.

### 7. Open Questions

Identify unresolved questions that emerged during the interview. These are candidates for analysis documents.

### 8. Write PRD

Fill the PRD template with all gathered information. Ensure the directory exists:

```bash
mkdir -p "{parent directory of discovery.prd_path}"
```

Write to `{discovery.prd_path}`.

### 9. Report

Output:
- Path to the PRD
- Summary: product vision, number of goals, number of feature candidates
- Suggested next steps:
  - "Create analysis docs for open questions (save to `{discovery.analysis_dir}/`)"
  - "Run `/coco:roadmap {release-name}` to build a prioritized roadmap"

---

## Mode 2: Audit (Existing Project)

Generate a PRD from an existing codebase.

### 1. Scan the Project

Gather information from all available sources:

**Project metadata:**
- Read `README.md` (if exists)
- Read `package.json`, `Cargo.toml`, `pyproject.toml`, or equivalent (if exists)
- Read `.coco/config.yaml` (if exists)

**Existing specifications:**
- Glob `{specs_dir}/*/design.md` (with `{specs_dir}/*/spec.md` as legacy fallback) and read each
- Summarize features already designed

**Source code structure:**
- Glob for key patterns (e.g., `src/**`, `app/**`, `lib/**`)
- Identify major modules and their purposes

**Documentation:**
- Glob `docs/**/*.md` and scan for product/feature documentation
- Check for existing PRD, roadmap, or analysis docs

**Tracker history:**
```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh" list --json 2>/dev/null || true
```

**Issue tracker** (if configured):
Based on `issue_tracker.provider`:
- **linear**: List recent projects and issues for the team
- **github**: List milestones and recent issues. If `github.use_projects` is true, also list projects via `gh project list --owner {github.owner}` to capture board-based tracking state.
- **none**: Skip

### 2. Synthesize PRD

Fill the PRD template using discovered information:
- Infer product vision from README and project metadata
- Infer target users from code patterns and documentation
- Infer goals from existing features and specs
- List existing features in the Feature Candidates table
- Mark inferred sections with `[INFERRED]` tag

### 3. Validate with User

Present the synthesized PRD to the user section by section using `AskUserQuestion`:
- Product vision -- correct?
- Target users -- missing anyone?
- Goals -- priorities right?
- Feature candidates -- anything missing or mischaracterized?
- Scope -- boundaries correct?

Update based on feedback.

### 4. Write PRD

```bash
mkdir -p "{parent directory of discovery.prd_path}"
```

Write to `{discovery.prd_path}`.

### 5. Report

Output:
- Path to the PRD
- Summary of what was inferred vs. confirmed
- Sections marked `[INFERRED]` that may need refinement
- Suggested next steps (same as greenfield mode)

## Mode 3: Derive (Satellite Repo)

Generate a derived PRD from a source PRD in another repository. Used for multi-repo projects where a primary repo holds the canonical PRD and satellite repos (web frontend, iOS app, API gateway, etc.) derive platform-specific PRDs from it.

### 1. Read Source PRD

Parse `$ARGUMENTS` after "derive" for the source PRD path and optional phase name in quotes.

Examples:
- `derive ../backend/docs/prd.md`
- `derive ../backend/docs/prd.md "Phase 2: iOS App"`

If no path is provided, check `discovery.source_prd` in `.coco/config.yaml`. If that's also empty, use `AskUserQuestion` to ask the user for the path.

Read the source PRD file. Validate it contains a `## Feature Candidates` table. Extract the product name from the `# Product Requirements Document: [NAME]` heading.

### 2. Read Source Roadmap (if phase specified)

If a phase name was provided:
1. Infer the roadmap directory from the source PRD path -- look for a sibling `roadmap/` directory (same parent as the PRD file, e.g., if source PRD is `../backend/docs/prd.md`, check `../backend/docs/roadmap/`)
2. Glob `*.md` in that directory
3. Read each roadmap file and find the matching phase by looking for `### Phase N: {name}` headers (fuzzy match on the name portion)
4. Extract feature slugs from the phase's feature table

If the roadmap directory doesn't exist or the phase isn't found, warn the user and continue with manual feature selection in step 4.

### 3. Identify Platform

Use `AskUserQuestion`:
- **Question**: "What platform or component does this repo own?"
- **Options**: Web Frontend, Mobile (iOS), Mobile (Android), API/Microservice (with Other as automatic fallback)

### 4. Select Features

Present the source PRD's Feature Candidates table as a multiSelect `AskUserQuestion`:
- **Question**: "Which features should be included in this repo's PRD?"
- List all features from the source PRD's Feature Candidates table
- If a phase was matched in step 2, pre-select features from that phase (note the phase name in each pre-selected option's description)

The user confirms or adjusts the selection.

### 5. Cross-Repo Dependencies

Use `AskUserQuestion`:
- **Question**: "What does this platform depend on from other repos? (e.g., REST APIs, shared services, data from other repos)"

The user describes the dependencies in free text.

### 6. Platform Constraints

Use `AskUserQuestion`:
- **Question**: "What are the technical constraints for this platform? (language, framework, deployment target)"

The user provides platform-specific constraints.

### 7. Detect Update Mode

Check if a PRD already exists at `{discovery.prd_path}`:
- If it exists and contains a `## Source PRD` section, this is a **re-derive** (update mode):
  - Preserve the existing Change Log entries
  - Show new features from source that aren't in the current derived PRD
  - Let the user add/remove features
- If it doesn't exist, this is a fresh derive

### 8. Generate Derived PRD

Fill the PRD template with:
- **Source PRD section**: source path, source product name, platform name, current date, phase name (if used)
- **Cross-Repo Dependencies table**: parsed from the user's dependency description in step 5
- **Product Vision**: scoped to this platform (e.g., "Deliver the iOS experience for [product]")
- **Target Users**: inherited from source PRD
- **Product Goals**: inherited from source PRD, filtered to goals relevant to selected features
- **Feature Candidates**: only the selected features, keeping original F-numbers for traceability
- **Scope**: platform-specific scope derived from the selected features + constraints
- **Constraints**: platform-specific constraints from step 6
- **Open Questions**: any cross-repo coordination questions that emerged
- **Change Log**: fresh entry for the derive, or preserved entries in update mode

### 9. Save Config

Update `.coco/config.yaml` to set `discovery.source_prd` to the source PRD path (for future re-derive).

If `.coco/config.yaml` doesn't exist yet, note the path for the user to configure after running `/coco:setup` (or `setup.sh` for submodule installs).

### 10. Write PRD

```bash
mkdir -p "{parent directory of discovery.prd_path}"
```

Write to `{discovery.prd_path}`.

### 11. Report

Output:
- Path to the derived PRD
- Source PRD: path and product name
- Platform: selected platform
- Features: count of selected features (with F-numbers)
- Phase filter: which phase was used (if any)
- Cross-repo dependencies: count
- Suggested next steps:
  - "Run `/coco:roadmap {release-name}` to build a prioritized roadmap for this platform"
  - "To refresh from the source PRD later, run `/coco:prd derive` again"

---

## Notes

- The PRD is a living document -- it can be updated by running `/coco:prd` again
- If the PRD already exists, load it and present options: overwrite, update specific sections, or cancel
- Feature candidates in the PRD feed directly into `/coco:roadmap` for prioritization
- Open questions are candidates for standalone analysis docs in `{discovery.analysis_dir}/`
