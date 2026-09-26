# Match setup UI review and verification

## Scope

Full review of the match selector on Android and iOS, followed by the operator-authorized implementation in PR92.
The existing air-ruins match, explorer sprites, stone terrain, opaque panels, and restrained team colors are the design reference.
The work changes presentation and Korean board descriptions; rules and bridge APIs remain unchanged.

## Coverage

Review covers local and AI selection, all four difficulties and board choices, selected indicators, preview topology and orientation, retained configuration, match entry/back navigation, English/Korean labels, compact screens, large text, and keyboard activation.
The preview reads catalog data directly, including sparse damaged and hole overrides; it does not synthesize engine snapshots.

## Findings

The initial review found two MEDIUM presentation issues: text-only choices hid board differences, and the plain selector lacked continuity with the existing match artwork.
A LOW Korean large-text issue wrapped a counter onto its own line.
The implementation replaces the text-only selector with preview cards, reuses the current background and characters, shortens the large-board descriptions, and pins Start below the scrolling options.
A runtime semantics check exposed separate label and selected-state nodes; each card now merges them into one accessible control.

## Evidence gaps

No physical phone, VoiceOver/TalkBack session, accessibility contrast tool, or frame profile was run.
Widget semantics checks establish labels, flags, and keyboard actions; they do not establish a screen reader's spoken output.
Native captures establish only their actual locales, scales, viewport sizes, and states.
No motion or performance improvement is claimed.

## Considered but rejected

New ornamental frames, glass panels, generated artwork, and animations would conflict with the current visual-cohesion contract and add unnecessary scope.
Existing sprites and terrain already communicate the game's theme and board topology.

## Verification

The pinned-Start regression failed against the previous scrolling footer before implementation and passed after the footer moved outside the scroll view.
Focused tests inspect preview terrain, six pieces, orientation, missing corners, damaged overrides, actual configuration forwarding, Enter activation, and merged selected semantics.
`flutter test test/game/start` passed 20 tests after the final spacing correction.
`flutter analyze` and scoped Markdown spelling passed.

Android Pixel 10 (1080 × 2424) passed four real-engine scenarios: English and Korean at text scales 1 and 2.
Each scenario selected AI Expert, exercised all four board choices, tapped the pinned Start button, verified 49 initial tiles, six pieces and three holes, then returned to setup.
The driver exited 0 and produced 12 fresh PNGs under `build/screenshots/setup-refresh-android/`.
The first capture pass exposed excess intrinsic height below board descriptions; an explicit square preview constraint removed it, and the complete Android setup pass was repeated successfully.
The initial command without the required flavor stopped before installation; the verified runs used `--flavor production`.
The emulator was shut down after the final pass.

The first iPad Pro 11 M5 / iPadOS 26.5 run passed all four scenarios and produced 12 PNGs at 1668 × 2420.
Its first English capture preceded image decoding; subsequent states showed the complete assets.
That incomplete capture is not accepted as visual evidence.
The harness now waits until every rendered `RawImage` has a decoded image before saving a screenshot, with a bounded failure path.
The corrected iOS driver exited 0 with all four scenarios passing and 12 fresh captures.
The first English screen now shows the decoded background, explorers, and all four previews.
The final Android pass with the same readiness guard also exited 0 with all four scenarios passing.
Both platforms retain 12 final PNGs each.
The [provenance manifest](2026-09-26-match-setup-provenance.json) records source hashes, artifact hashes, and dimensions.
Its read-back validation rejected a deliberately changed source hash and a missing capture before accepting the real manifest.
Selected normal, AI, and large-text captures were inspected directly on both platforms; all final captures enforce decoded imagery before capture.
Only task-owned runtimes were used and both were shut down; the physical phone was untouched.
`CARGO_BUILD_JOBS=2 merry run check` exited 0 after the added mode-switch regression: 217 Flutter tests at the configured 100% coverage threshold, 88 Rust tests, six loaded host bridge tests, analysis, formatting, clippy, version guard, and Trunk.
The aggregate native parity step explicitly skipped because runtimes were stopped; separate native setup runs above provide this change's packaging and interaction evidence.
Markdown spelling checked the four changed Markdown documents with zero findings.
Trunk formatting did not change the hashed product or capture-harness sources.

The first aggregate gate passed 216 Flutter tests but reported 99.94% coverage against the required 100%.
The missing path was switching from AI back to local play; a regression now verifies hidden difficulty choices and the actual Human opponent after Start.

Minimum focused verification:

```bash
flutter test test/game/start
flutter analyze
```

Native setup verification, run sequentially for each target:

```bash
CARGO_BUILD_JOBS=2 flutter drive --driver=test_driver/ios_gameplay_flow_driver.dart --target=integration_test/start_page_flow_test.dart -d <runtime-id> --flavor production
```

## Verdict

Initial: Needs changes.
Final: Approve within the observed setup scope; no actionable Flutter UI/UX findings remain.
This review verdict does not replace the operator's visual approval before merge.

## Precedent

Oracle returned `wiki/entities/ttush-push.md` and `raw/sources/ttush_push/CLAUDE.md` at source revision `c1681868ac634e4b2414874716bb75a7864113c4` for presentation ownership and deferred complex motion.
This confirmed the Flutter-only scope and use of existing controls without new animation infrastructure.
The older artwork reference was not used as authority over the current repository's visual-cohesion specification.
No specific setup-layout precedent was found; wiki freshness was not independently verified.
