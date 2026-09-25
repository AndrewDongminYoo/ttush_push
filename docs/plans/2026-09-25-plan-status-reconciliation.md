# Plan status reconciliation implementation

## Direction and ownership

Implement [the approved issue scope](https://github.com/AndrewDongminYoo/ttush_push/issues/80) under [the reconciliation contract](../specs/2026-09-25-plan-status-reconciliation.md).
Use the current workspace and base revision `6da4099f4c0371854ca821066fa82c2aa074cbd1`.
The root owns this plan, the specification, the checkbox-drift index, Git changes, final checks, and the PR loop.
One worker owns the three historical implementation plans; another owns the accessibility specification and Android release checklist.
Workers may read supporting sources but may edit only their assigned documents.

## Steps and success criteria

1. Extract affected claims and verify them against code, tests, dated notes, and linked issues.
   Verify: each reconciliation row cites the artifact or evidence that supports its status.
2. Add dated status sections while preserving original unchecked execution steps.
   Verify: the diff distinguishes implemented artifacts, superseded design, pending verification, and deliberate deferral.
3. Update the index with Expert, Korean UI, blueprint analysis limits, and the Web decision.
   Verify: the index links tracker #81 and avoids unsupported totals or completion percentages.
4. Check the documents and review their claims.
   Verify: `git diff --check`, changed-file Trunk checks, Markdown spelling, and local link checks pass; independently review the source-to-claim mapping.
5. Commit one documentation concern, open a PR, and complete hosted CI and review.
   Verify: the reviewed SHA matches the PR head and applicable checks pass before requesting operator merge.

## Evidence limits

This task adds no runtime behavior, so code TDD and new device tests do not establish its correctness.
The checks above inspect documentation; manual accessibility, gameplay, and release-console verification remain separate tracked work.
Oracle release guidance confirms that repository artifacts do not establish store approval or distribution state; dated operator reports retain their attribution.
