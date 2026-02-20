# Discovery Phase Workflow

The Discovery Phase provides structured pre-implementation workflow for defining the product, conducting analysis, and building a prioritized roadmap before any feature specification begins.

## When to Use

Use the Discovery Phase when:
- Starting a new product or major release
- Onboarding an existing project into coco-workflow for the first time
- Transitioning from ad-hoc feature development to structured roadmap execution
- Needing to align stakeholders on priorities before writing specs

Skip it when:
- Working on a single known feature (start with `/coco.spec`)
- Applying a hotfix (use the coco-hotfix skill)
- The roadmap already exists and is current

## Artifact Structure

```
docs/
  prd.md                              # Product Requirements Document
  analysis/                           # Analysis docs (one per topic)
    market-analysis.md
    technical-feasibility.md
    ...
  roadmap/                            # Per-release roadmap docs
    v1.0.md
    v1.1.md
    ...
  planning-sessions/                  # Session notes (existing)
    YYYY-QN.md
```

All paths are configurable via the `discovery:` section in `.coco/config.yaml`:

```yaml
discovery:
  prd_path: "docs/prd.md"
  analysis_dir: "docs/analysis"
  roadmap_dir: "docs/roadmap"
```

## Step-by-Step Walkthrough

### 1. Create the PRD

```
/coco.prd "Brief product description"
```

For an existing project:
```
/coco.prd audit
```

The PRD command interviews you through each section (vision, users, goals, scope, constraints, feature candidates) and writes a structured PRD. For existing projects, it scans the codebase and infers what it can, then validates with you.

**Output**: `docs/prd.md` with feature candidates and open questions.

### 2. Create Analysis Documents

For each open question or topic that needs investigation, create an analysis doc. Two approaches:

**Via planning session** (recommended for complex topics):
```
/planning-session strategic
```
Strategic sessions now offer to save analysis topics as standalone docs in `docs/analysis/`.

**Manually** (for quick analyses):
Use the analysis template at `templates/analysis-template.md`. Each analysis doc should include:
- Key findings with evidence
- Implications for the roadmap (which features are affected and how)
- Concrete recommendations

Analysis docs are automatically discovered by `/coco.roadmap`.

### 3. Build the Roadmap

```
/coco.roadmap v1.0
```

The roadmap command:
1. Reads the PRD and all analysis docs
2. Extracts and deduplicates feature candidates
3. Scores each feature: `Score = (Impact + Urgency) / Effort`
4. Groups features into dependency-ordered phases
5. Writes a structured roadmap with machine-parseable phase tables

**Output**: `docs/roadmap/v1.0.md` with phases, scored features, and acceptance criteria.

If an issue tracker is configured, it also creates:
- **Linear**: Initiative + project per phase
- **GitHub**: Milestone for the release

### 4. Execute Phases

```
/coco.phase "Phase 1: Foundation"
```

`/coco.phase` reads the roadmap table directly, extracting features with their slugs, priorities, and dependencies. It then orchestrates the full per-feature pipeline (spec -> plan -> tasks -> import -> execute).

## Roadmap Sync

The roadmap is automatically updated as work progresses:

| Event | Update |
|-------|--------|
| Feature completed (`/coco.loop` epic done) | Feature row Status -> "Complete", Spec column filled |
| Phase completed (`/coco.phase` all features merged) | Phase Status -> "Complete", Change Log entry added |

This keeps the roadmap as a live dashboard of release progress.

## Integration with Existing Workflows

The Discovery Phase sits before the existing planning pipeline:

```
Discovery Phase (NEW)
  /coco.prd              Create/audit Product Requirements Document
  /planning-session      Analysis docs via strategic sessions
  /coco.roadmap          Synthesize PRD + analysis into per-release roadmap

Planning Phase (existing)
  /coco.phase            Reads roadmap, orchestrates features
  /coco.spec             Per-feature specification
  /coco.plan             Implementation plan
  /coco.tasks            Task decomposition

Execution Phase (existing)
  /coco.import           Import to tracker + issue tracker
  /coco.loop             Autonomous TDD + PR + review
  /coco.execute          Manual step-by-step
```

Projects without discovery docs work exactly as before -- all roadmap lookups gracefully fall back to the existing behavior (scanning README/docs/specs).

## Multiple Releases

Each release gets its own roadmap file (e.g., `docs/roadmap/v1.0.md`, `docs/roadmap/v1.1.md`). This supports:
- Parallel release planning
- Deferring features to future releases
- Tracking completion across releases independently
