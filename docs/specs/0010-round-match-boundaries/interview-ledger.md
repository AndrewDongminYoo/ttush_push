---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What currently makes a round result too easy to confuse with the overall match result?

Answer: Both outcomes use the same overlay structure, while the difference is carried only by the secondary sentence and the continuation button.

Decision: Add a prominent completion-scope badge before the winner, and name the following action as the start of the next round or a new match.

Source: Operator report and current `_ResultOverlay` inspection on 2026-09-01.

### L2

Status: current

Question: Does the boundary need a new screen or timed transition?

Answer: The final board must remain readable beneath the result, and the existing match specification intentionally excludes transition animation.

Decision: Keep one static overlay and strengthen its hierarchy instead of adding a route, timer, modal, or animation.

Source: `docs/specs/2026-08-22-best-of-three-match.md` and current result behavior on 2026-09-01.

### L3

Status: current

Question: Which state decides whether the completed scope is a round or the match?

Answer: The Rust-authored `MatchSnapshot.matchWinner` already distinguishes `RoundOver` from `MatchOver` through the existing controller projection.

Decision: Read only that existing presentation field, keep `advanceRound` and `restart` unchanged, and add no Dart score or phase calculation.

Source: Current `GamePage`, `MatchController`, and best-of-three match contract on 2026-09-01.

### L4

Status: current

Question: How should the distinction remain usable with assistive technology and large text?

Answer: Round and match live announcements are already distinct, and the result copy already scales inside a bounded region while its primary action keeps a full touch target.

Decision: Keep the current announcements and layout strategy, add visible localized scope text, and retain the existing large-text result coverage.

Source: `docs/specs/2026-08-24-accessible-first-play-match-flow.md`, `lib/game/view/game_page.dart`, and widget tests on 2026-09-01.

### L5

Status: current

Question: Does the project have an applicable precedent for presenting round and match lifecycle boundaries?

Answer: `[no precedent found]`

Decision: This static scope-and-action hierarchy becomes the first project precedent for this lifecycle distinction.

Source: Personal-account Oracle lookup for `ttush_push` on 2026-09-01.
