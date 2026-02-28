---
name: interview
description: Pre-design discovery interview that gathers deep user intent through structured questioning. Produces a discovery brief (discovery.md) consumed by the design skill.
---

# Coco Interview Skill

Conduct a structured pre-design interview to gather deep user intent, constraints, and context before generating a feature design. Produces a discovery brief that feeds directly into the `design` skill.

## When to Use

- Pre-design discovery for **Standard-tier** features (before invoking the `design` skill)
- Deep-dive during any planning session (strategic, tactical, operational, triage)
- Natural language requests ("interview me about this feature", "let's discuss requirements")
- When `/coco:phase` or `/coco:planning-session tactical` routes to Standard tier

**Do NOT use for:**
- Trivial-tier features (use `hotfix` skill directly)
- Light-tier features (skip interview, use `design` in light mode)
- Features where the user has already provided exhaustive requirements

## Setup

1. Read `.coco/config.yaml` for `project.specs_dir` (default: `specs`).
2. Determine the feature from conversation context:
   - If a feature name or description was provided, use it
   - If on a `feature/*` git branch, extract the feature name
   - If none of the above, ask the user what feature to discuss
3. Determine the feature directory: `{specs_dir}/{feature-name}/`
4. Load the discovery template from `.coco/templates/discovery-template.md` if it exists, otherwise use `${CLAUDE_PLUGIN_ROOT}/templates/discovery-template.md`.
5. Check if `{specs_dir}/{feature-name}/discovery.md` already exists:
   - If yes, enter **refinement mode** (see below)
   - If no, proceed with fresh interview

## Execution

### Category Progression

The interview covers these categories in order, adapting based on what the user has already provided:

1. **Problem & Motivation** -- What problem does this solve? Who feels the pain? Why now?
2. **Users & Personas** -- Who are the target users? What are their goals and skill levels?
3. **Scope & Boundaries** -- What's explicitly in scope? What's out of scope? MVP vs future?
4. **Functional Requirements** -- What are the core behaviors? What are the key user flows?
5. **Technical Context** -- What existing systems does this interact with? Any constraints?
6. **UX & Interaction** -- What does the user experience look like? Key screens/flows?
7. **Non-Functional Requirements** -- Performance, security, accessibility, scalability?

### Question Strategy

Before asking any questions, analyze the user's initial feature description and any context from the current conversation. Determine which categories already have sufficient detail.

**Rules:**
- Use AskUserQuestion with recommended answers where possible (concrete options help users think faster)
- Skip categories where the initial description already provides sufficient detail
- **Maximum 10 questions total** across all categories
- Accept "done" or "skip" from the user to terminate early
- After each answer, reassess remaining coverage gaps
- Stop when all critical categories (Problem, Scope, Functional) are covered, even if other categories have gaps
- Prioritize questions by: scope-defining > ambiguity-resolving > nice-to-have
- Ask 1-3 questions at a time (not all 10 upfront)

**Question format guidelines:**
- Multiple-choice: Provide 2-4 concrete options with a recommended choice. Include descriptions explaining tradeoffs.
- Open-ended: Only when the space of answers is too broad for options. Keep the question specific and bounded.
- Never ask obvious questions -- demonstrate understanding of the domain by making informed assumptions and asking about the non-obvious aspects.

### Output

After the interview completes (all critical categories covered, user says "done", or 10 questions reached):

1. Create the feature directory if it doesn't exist:
   ```bash
   mkdir -p {specs_dir}/{feature-name}
   ```

2. Fill the discovery template with structured findings from the interview.

3. Write to `{specs_dir}/{feature-name}/discovery.md`.

4. Report:
   - Discovery file path
   - Categories covered vs skipped
   - Key decisions captured
   - Open questions remaining (if any)
   - Suggested next step: tell the user to ask Claude to "design this feature" (this triggers the `design` skill automatically -- skills are NOT slash commands, so never suggest `/coco:design`)

### Planning Session Context

When invoked during a planning session (strategic, operational, triage) rather than the standard pre-design flow:

- Output the discovery brief inline into session notes instead of (or in addition to) writing `discovery.md`
- Adapt category progression to the session context:
  - **Strategic**: Focus on Problem & Motivation, Scope & Boundaries, Technical Context
  - **Operational**: Focus on the specific blocker -- narrow to relevant categories only
  - **Triage**: Focus on Problem & Motivation, Scope & Boundaries (enough to score)

## Refinement Mode

When `discovery.md` already exists:

1. Load and display a summary of the existing discovery brief
2. Ask the user what has changed or what gaps they want to address
3. Focus questions on:
   - Categories marked with open questions in the existing brief
   - New information or changed requirements
   - Areas the user specifically wants to revisit
4. Update `discovery.md` in place (preserve existing content, add/modify sections)
5. Append to the Change Log at the bottom: `{date} | Refinement | {summary of changes}`

## Guidelines

- Keep the interview conversational but structured -- don't make it feel like a form
- Make informed assumptions based on context and industry standards; verify only non-obvious choices
- Every answer should move the understanding forward -- don't ask for information you can infer
- The discovery brief is a living document -- it can be refined as understanding deepens
- Do NOT generate design.md -- that is the `design` skill
- Do NOT generate tasks.md -- that is the `tasks` skill
- Never modify files outside the feature's spec directory
