---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which remaining implementation item should run first?

Answer: Implement the confirmed `BoardDefinition` milestone before optional animation work or manual accessibility evidence collection.

Decision: The BoardDefinition milestone is the first implementation scope in this session.

Source: Operator request on 2026-08-30 and current repository review.

### L2

Status: current

Question: Should the first implementation load a runtime configuration file or use a built-in typed definition?

Recommended Answer:

- Use one built-in typed definition.
- Keep the existing baseline board and background behavior.
- Do not add a JSON parser, a board picker, a new package, or persisted board selection.

Answer: The operator did not select a configuration format directly.

Operator instruction: "좋습니다. 앞으로 2시간 동안 우선순위를 차례대로 진행해주세요. 스펙과 계획은 어드바이저와 오라클을 통해 협의하세요."

Decision: Use one built-in typed BoardDefinition for this milestone.

Reason: One board exists today. A runtime-loaded format would add parsing, startup, and validation behavior without a current product need.

Source: Advisor and Oracle consultation on 2026-08-30, under the operator instruction above.

### L3

Status: current

Question: Which layer owns each BoardDefinition field?

Answer: Rust validates playable cells and starting pieces. Flutter owns background presentation metadata.

Decision: The generated Rust input type must not contain a background asset field. The Dart BoardDefinition keeps the background asset path beside the Rust input value.

Reason: Board topology and starting pieces are balance configuration, but a bundled image is presentation-only metadata.

Source: Advisor review and Oracle lookup on 2026-08-30.

### L4

Status: current

Question: How should an invalid board definition fail?

Answer: Rust must validate the incoming cells and pieces before it constructs a match. The existing MatchController initialization error state handles an initial-match failure after Rust has initialized.

Decision: `initial_match` returns a recoverable bridge error for an invalid BoardDefinition. This milestone does not add a retry surface for `RustLib.init()` itself.

Reason: Bootstrap initializes Rust before it creates the Flutter widget tree. Retrying native-library initialization requires a separate startup ownership design.

Source: Oracle lookup on 2026-08-30.

### L5

Status: current

Question: What evidence proves that the new input crosses the bridge safely?

Answer: Direct Rust validation tests, a host bridge test, and the existing Android and iOS parity integration test must exercise the BoardDefinition input.

Decision: Add an irregular-board regression that reaches Rust through the generated bridge. Keep the baseline snapshot hash stable. Run mobile parity on one Android runtime and one iOS Simulator when available. Do not write to the daily iPhone.

Reason: A host bridge test does not prove Android or iOS packaging. A fixture must produce the irregular board it claims to test.

Source: Advisor review, Oracle lookup, and project bridge guidance on 2026-08-30.
