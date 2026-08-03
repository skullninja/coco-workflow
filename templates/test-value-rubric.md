# Test Value Rubric

How to judge whether a test earns its place. Used by the `test-auditor` agent, by `/coco:test-audit`, and by the `code-reviewer` agent when assessing tests in a diff.

Project override: copy to `.coco/templates/test-value-rubric.md` and edit.

## The question

A test suite is not an asset. It is a **trade**: you accept ongoing cost — review time, CI minutes, and friction on every future refactor — in exchange for catching defects before users do.

A test earns its place when that trade is favorable. The question is never "does this test pass?" or "does this increase coverage?" It is:

> **What specific defect would ship if this test did not exist?**

If that question has no concrete answer, the test is costing more than it returns, no matter how green it is.

## Evidence to gather

These are inputs to a judgment, **not terms in a formula**. Cite the ones that drove your verdict. Do not compute a total.

**1. Behavioral anchoring.** Does the test assert observable behavior through a public interface, tied to a stated requirement (`FR-###` in the feature's design)? Or does it assert implementation detail — private state, call ordering, that a collaborator was invoked? Implementation-anchored tests break on refactors that change nothing a user can see, which is the single largest source of test maintenance cost.

**2. Distinct failure mode.** Would deleting this test reduce the suite's ability to catch a real defect? A test that can only fail when another test also fails is redundant regardless of how well written it is. Look for the same failure mode defended at multiple levels — a unit test, an integration test, and an e2e test all covering one happy path is one test's worth of value at three tests' worth of cost.

**3. Maintenance cost.** The one dimension you can read directly off the source: lines of setup, number of mocks, fixture depth, coupling to internals, runtime, and flakiness. A test needing twenty lines of mock scaffolding to assert one boolean is usually testing the scaffolding.

**4. Blast radius.** What actually breaks if this behavior regresses? Data loss, auth bypass, silent corruption, and money movement justify defense that a label's padding does not. Be honest here — most code is not load-bearing, and pretending otherwise is how suites bloat.

## Verdicts

Choose one. Cite the evidence that drove it.

**Keep** — Names a real failure mode of a committed behavior, at the cheapest level that catches it. Record which behavior it defends.

**Keep-rewrite** — The failure mode is real but defended badly: it asserts implementation detail rather than observable behavior, or it would still pass with the bug present. Do **not** delete. Rewrite the assertion to observe the behavior. Deleting loses real coverage; leaving it as-is is worse than having nothing, because it reads as coverage to everyone who comes after.

**Consolidate** — The failure mode is already defended elsewhere at this level or below. Fold this case into the surviving test (or its parametrization) and delete this one. **Name the survivor.** This is the default verdict for the third and subsequent test of the same code path.

**Delete** — Defends no failure mode of any stated behavior, or cannot fail for the reason it claims to test. No replacement needed. **Every Delete must quote the specific assertion that fails the check.**

**Escalate** — Cannot be adjudicated from code alone. Never auto-delete these; surface them to a human with the evidence and stop. Two triggers:
- Sole defender of a security or data-integrity property.
- Introduced by a commit that fixed a shipped bug. Check with `git log -S'{test name}' --format=%s` — a test born in a fix commit is proof the failure mode is real and was once undefended. That is the highest-value test there is.

**Choose the verdict from the questions above and cite the evidence that drove it. There is no score and no threshold — nothing is deleted because a number came out low.**

## Delete on sight

**Precedence**: "Keep on sight" beats "Delete on sight". If a test matches both lists — a regression test whose assertion is also tautological, or a sole security defender that duplicates another test — the verdict is **Escalate**, never Delete. Those are exactly the cases where deleting on a rule is most likely to be wrong, and a human should look. Fixing the bad assertion inside a regression test is `Keep-rewrite`; throwing the test away is not on the table.

Absent a "Keep on sight" match, these fail regardless of other evidence:

- **Tautology** — can only fail if the test framework itself is broken (`assertEqual(2, 2)`, asserting a literal the test just defined).
- **Mock assertion only** — the sole assertion is that a stub was called. No production behavior is observed. This tests that you wrote the code you wrote.
- **Framework test** — exercises a third-party library, the standard library, or a language feature rather than project code. The library has its own suite.
- **Exact duplicate** — identical inputs and assertions to another test at the same level. Name it as `file:line`.
- **Assertion-free** — runs code and asserts nothing, or only that no exception was raised, when the behavior under test has an observable result.

## Keep on sight

- **Regression tests** — born in a bugfix commit (see Escalate). The failure mode is proven real.
- **Sole defender of a security or data-integrity property.**
- **Contract tests at a boundary you do not control** — API shapes, serialization formats, migrations.

## Judgment cautions

**Design drift.** A feature's `## Test Strategy` may list something under **Not worth testing** that has since become important. Nothing rewrites design.md after execution, so treat a stale strategy as *evidence*, not authority: it penalizes behavioral anchoring, but it is never sufficient grounds to delete on its own. (Inside the feature's own PR, where the design is fresh, the code reviewer does treat it as a blocking finding — that is the right place for it.)

**Low coverage is not evidence of over-testing.** These are independent questions. A thin suite full of tautologies still has tautologies worth deleting.

**Do not confuse verbose with worthless.** An ugly test defending a real failure mode is `Keep-rewrite`, never `Delete`. Deleting is for tests that defend nothing.

**Absence of a rubric hit is not a Keep.** If you cannot state what defect a test prevents, that is a finding, not a pass.
