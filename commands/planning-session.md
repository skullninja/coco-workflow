---
description: Start a planning session (strategic, tactical, operational, or triage). Guides you through the structured process for the selected type.
---

# Planning Session

Guide the user through a structured planning session.

## Determine Session Type

$ARGUMENTS may specify the type. If not, ask using AskUserQuestion.

**Types:**
- **strategic** -- Roadmap review and prioritization
- **tactical** -- Plan a specific feature (spec -> plan -> tasks -> import)
- **operational** -- Status check and task prioritization
- **triage** -- Quick-score a bug, feature request, or feedback item

## Process

### Strategic
1. Review project goals and metrics
2. Audit existing roadmap/feature list
3. Prioritize features by impact
4. Update roadmap and issue tracker projects
5. Save notes to `docs/planning-sessions/YYYY-QN.md`
6. For each analysis topic discussed, offer to save it as a standalone analysis doc:
   - Read `discovery.analysis_dir` from `.coco/config.yaml` (default: `docs/analysis`)
   - Load analysis template from `.coco/templates/analysis-template.md` if it exists, otherwise use `${CLAUDE_PLUGIN_ROOT}/templates/analysis-template.md`
   - Fill in findings, implications, and recommendations from the session discussion
   - Write to `{discovery.analysis_dir}/{topic-slug}.md`
   - These analysis docs are discoverable by `/coco.roadmap` for roadmap generation

### Tactical

**Step 1: Determine Complexity Tier**

Before running the pipeline, classify the feature scope:

| Tier | Signal | Pipeline |
|------|--------|----------|
| **Trivial** | User says "small", "quick", "hotfix"; single file mentioned; bug fix | `coco-hotfix` skill (no epic) |
| **Light** | 1-3 files, single user story, no internal dependencies | `coco-spec` (light mode) -> `coco-import` (spec-only) |
| **Standard** | Multi-file, multiple stories, dependencies between components | `coco-spec` -> `coco-plan` -> `coco-tasks` -> `coco-import` |

Ask the user using AskUserQuestion: "How complex is this feature?" with options:
- **Quick fix** -- Single issue, 1 file (routes to Trivial)
- **Small feature** -- 1-3 files, straightforward (routes to Light)
- **Full feature** -- Multiple files, dependencies, needs detailed planning (routes to Standard)

If the user already described the scope clearly, infer the tier without asking.

**Step 2: Execute Pipeline**

- **Trivial**: Use the `coco-hotfix` skill. Done.
- **Light**: Use `coco-spec` skill (light mode) -> `coco-import` skill (spec-only mode). Skips plan and tasks generation.
- **Standard**: Run full pipeline: `coco-spec` -> `coco-plan` -> `coco-tasks` -> `coco-import`

**Step 3: Verify and Save**
1. Verify import and pre-execution gate
2. Save notes to `docs/planning-sessions/YYYY-MM-DD-{feature}.md`

### Operational
1. Check current tracker state:
   ```bash
   source "${CLAUDE_PLUGIN_ROOT}/lib/tracker.sh"
   coco_tracker epic-status
   ```
2. Run `/coco.sync` to reconcile with issue tracker
3. Reprioritize and unblock tasks
4. Plan the week's work

### Triage
1. Score the item using the impact framework (see `/planning-triage`)
2. Disposition based on score (immediate/backlog/defer)
3. Create issue if appropriate
4. Save notes

## Output

At the end of each session, summarize:
- What was decided
- What actions were taken (issues created, priorities changed)
- What the next steps are
