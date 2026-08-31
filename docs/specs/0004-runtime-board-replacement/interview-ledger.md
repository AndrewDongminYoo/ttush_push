---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What inconsistency must runtime BoardDefinition replacement prevent?

Answer: A retained `GamePage` can render a new background while its existing `MatchController` continues to use the previous board rules and match snapshot.

Decision: A `BoardDefinition` replacement must update the rules input, match state, and background as one lifecycle transition.

Source: GitHub Issue #22 and the current `GamePage` implementation on 2026-09-01.

### L2

Status: current

Question: Should Issue #22 remain a product decision or become the next implemented issue?

Answer: Process the repository issues in order, and create a missing Spec and implementation plan before implementation.

Decision: Implement runtime board replacement as the first issue in this work sequence.

Source: Operator request in this session.

### L3

Status: current

Question: Which match state persists when the BoardDefinition changes?

Answer: Use the smallest safe replacement policy for this reversible product decision.

Decision: Start a fresh match from the new definition.
Discard the active match, score, opponent selection, selected piece, errors, retry action, pending move, bot timer, and replay.
Keep the retained page State, coach state, coach store, and feedback resource.

Source: Operator default-selection rule and the scoped Issue #22 lifecycle requirements.

### L4

Status: current

Question: Which layer owns the replacement behavior?

Answer: `GamePage` owns the bot timer, replay controller, background path, and `MatchController` lifetime.
Rust owns board validation, rules, snapshots, and results.

Decision: Implement the lifecycle transition only in `GamePage`.
Create a fresh `MatchController` with the new generated rules value.
Do not change Rust or the bridge.

Source: `docs/specs/0002-board-definition/spec.md` and current source code.

### L5

Status: current

Question: Does the project have an applicable precedent for this lifecycle policy?

Answer: `[no precedent found]`

Decision: The same-State A-to-B widget regression becomes the first project precedent for runtime board replacement.

Source: Personal-account Oracle lookup for `ttush_push` on 2026-09-01.
