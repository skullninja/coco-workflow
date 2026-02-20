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
1. Run coco workflow skills: `coco-spec` -> `coco-plan` -> `coco-tasks` -> `coco-import`
2. Verify import and pre-execution gate
3. Save notes to `docs/planning-sessions/YYYY-MM-DD-{feature}.md`

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
