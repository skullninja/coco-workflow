---
argument-hint: [product description or "audit" for existing projects]
description: Create or update the Product Requirements Document. Use "audit" mode for existing projects.
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
mkdir -p "$(dirname "{discovery.prd_path}")"
```

Write to `{discovery.prd_path}`.

### 9. Report

Output:
- Path to the PRD
- Summary: product vision, number of goals, number of feature candidates
- Suggested next steps:
  - "Create analysis docs for open questions (save to `{discovery.analysis_dir}/`)"
  - "Run `/coco.roadmap {release-name}` to build a prioritized roadmap"

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
- Glob `{specs_dir}/*/spec.md` and read each
- Summarize features already specified

**Source code structure:**
- Glob for key patterns (e.g., `src/**`, `app/**`, `lib/**`)
- Identify major modules and their purposes

**Documentation:**
- Glob `docs/**/*.md` and scan for product/feature documentation
- Check for existing PRD, roadmap, or analysis docs

**Tracker history:**
```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"
coco_tracker list --json 2>/dev/null || true
```

**Issue tracker** (if configured):
Based on `issue_tracker.provider`:
- **linear**: List recent projects and issues for the team
- **github**: List milestones and recent issues
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
mkdir -p "$(dirname "{discovery.prd_path}")"
```

Write to `{discovery.prd_path}`.

### 5. Report

Output:
- Path to the PRD
- Summary of what was inferred vs. confirmed
- Sections marked `[INFERRED]` that may need refinement
- Suggested next steps (same as greenfield mode)

## Notes

- The PRD is a living document -- it can be updated by running `/coco.prd` again
- If the PRD already exists, load it and present options: overwrite, update specific sections, or cancel
- Feature candidates in the PRD feed directly into `/coco.roadmap` for prioritization
- Open questions are candidates for standalone analysis docs in `{discovery.analysis_dir}/`
