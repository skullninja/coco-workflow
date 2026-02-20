---
description: Quick-score an enhancement, bug, or feedback item using the impact-first triage framework. Creates an issue if approved.
---

# Planning Triage

Quick-score an item and determine its disposition.

## Input

```text
$ARGUMENTS
```

The item to triage (bug report, feature request, user feedback, competitor feature).

## Process

### 1. Understand the Item

Parse the input to identify:
- **Type**: Bug, Feature, Enhancement, Competitive Response
- **Description**: What is being requested or reported
- **Context**: Why it matters (user impact, competitive pressure, etc.)

### 2. Score

Apply the impact-first scoring framework:

```
Score = (Impact + Urgency) / Effort
```

| Factor | 1 | 2 | 3 | 4 | 5 |
|--------|---|---|---|---|---|
| **Impact** | No effect on users | Minor convenience | Moderate engagement | Significant daily value | Critical for adoption/retention |
| **Urgency** | Someday/nice-to-have | Next quarter | This month | This week | Today/blocking |
| **Effort** | Multi-week project | ~1 week | ~2-3 days | ~hours | ~minutes |

### 3. Rate Each Factor

For each factor, provide the score (1-5) and brief justification.

### 4. Calculate and Interpret

```
Score = (Impact + Urgency) / Effort

>= 3.0 -> IMMEDIATE ACTION
1.5-3.0 -> BACKLOG
< 1.5  -> DEFER
```

### 5. Disposition

**If IMMEDIATE (>= 3.0):**
- Create issue with High/Urgent priority (based on issue_tracker.provider in config)
- If feature: recommend `/planning-session tactical`
- If bug: recommend creating hotfix branch

**If BACKLOG (1.5-3.0):**
- Create issue with Normal priority
- Tag for next operational planning session

**If DEFER (< 1.5):**
- Document the rationale
- Do NOT create an issue
- Note for quarterly strategic review

### 6. Output

```
## Triage: {item title}

**Type:** {Bug/Feature/Enhancement}
**Score:** {X.X}

| Factor | Score | Rationale |
|--------|-------|-----------|
| Impact | {N} | {reason} |
| Urgency | {N} | {reason} |
| Effort | {N} | {reason} |

**Disposition:** {IMMEDIATE / BACKLOG / DEFER}
**Action:** {what was done}
```
