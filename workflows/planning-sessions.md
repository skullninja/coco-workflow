# Planning Sessions

Structured planning processes for different cadences and scopes.

## Session Types

| Type | Cadence | Duration | Output |
|------|---------|----------|--------|
| **Strategic** | Quarterly | ~2hr | Updated roadmap, issue tracker projects |
| **Tactical** | Per-feature | ~1hr | Spec artifacts, tracker epic |
| **Operational** | Weekly | ~15min | Updated priorities |
| **Triage** | Ad-hoc | ~15min | Scored disposition |

## Strategic Planning Session

### When
- Start of each quarter
- After major pivot or market shift
- When current roadmap phases complete

### Process
1. **Review metrics** -- Compare actual vs target
2. **Competitive scan** -- What have competitors shipped?
3. **Roadmap audit** -- What shipped? What slipped? What's obsolete?
4. **Prioritize** -- Rank features by impact
5. **Update roadmap** -- Revise feature list
6. **Create/update projects** in issue tracker (if configured)
7. **Document** -- Save session notes

### Output
- Updated roadmap
- Issue tracker projects for next quarter
- Session notes

---

## Tactical Planning Session

### When
- Starting a new feature from the roadmap

### Process
1. **Specify** -- `/coco.spec` to create spec.md
2. **Clarify** -- `/coco.clarify` to resolve ambiguities
3. **Plan** -- `/coco.plan` to create plan.md
4. **Tasks** -- `/coco.tasks` to create tasks.md (includes auto-analyze)
5. **Import** -- `/coco.import` to create tracker epic + issues
6. **Document** -- Save session notes

### Output
- Complete spec artifacts in `specs/{feature}/`
- Tracker epic with tasks and dependencies
- Issue tracker project (if configured)

---

## Operational Planning Session

### When
- Start of each work week
- After completing a major phase
- When blockers arise

### Process
1. **Status check** -- `coco_tracker epic-status`
2. **Sync** -- `/coco.sync` to reconcile with issue tracker
3. **Reprioritize** -- Move urgent items up, defer low-priority
4. **Unblock** -- Identify and resolve blocked tasks
5. **Plan week** -- Identify which tasks to tackle

### Output
- Updated task priorities
- Clear plan for the week
- Documented blockers

---

## Triage Session

### When
- New bug report or feature request
- User feedback suggests an issue
- Competitor ships something relevant

### Process

Use `/planning-triage` to score and disposition the item:

```
Score = (Impact + Urgency) / Effort
```

| Score | Disposition |
|-------|------------|
| >= 3.0 | **Immediate** -- Create issue, start work |
| 1.5-3.0 | **Backlog** -- Create issue, prioritize later |
| < 1.5 | **Defer** -- Document, revisit next quarter |
