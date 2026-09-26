# Match setup presentation

## Intent

The operator rejected the text-only setup in PR92 as visually awkward and requested alignment with the existing game concept.
Use the current air-ruins background, stone terrain, explorer sprites, opaque dark panels, and restrained blue accents.
The current visual-cohesion spec is the design authority; do not add ornamental frames, glass, new assets, dependencies, or custom motion.

## Contract

- Present each existing board with a non-interactive preview derived directly from its catalog cells, starting pieces, and initial tile overrides.
- Keep missing corners distinct from present hole tiles and orient Azure at the bottom, as in the match.
- Give mode, conditional AI difficulty, and board choices distinct visual groups and explicit selected indicators.
- Keep Start visible outside the scrolling choices, including small screens and large text.
- Use adaptive columns and content-driven heights; retain complete English and Korean labels without truncation.
- Preserve defaults, all four difficulties, all four boards, retained setup selections, navigation, and existing stable control keys.
- Expose labels, selected states, button actions, and focus through Flutter controls; exclude decorative imagery from semantics.
- Keep all rules, bridge code, assets, and match behavior unchanged.

## Evidence and precedent

The read-only initial review used `lib/game/start/start_page.dart`, the current match visual-cohesion spec, and existing Android/iPad captures.
It found missing visual continuity and board previews (MEDIUM) and an orphaned Korean counter at text scale2 (LOW).
The initial verdict was Needs changes; no screen-reader session or frame profile was available.
Screenshots established appearance, while the existing interaction suite established selection forwarding and scroll reachability.

Oracle source revision `c1681868ac634e4b2414874716bb75a7864113c4` returned `wiki/entities/ttush-push.md` and `raw/sources/ttush_push/CLAUDE.md` for the Flutter-presentation/Rust-rules boundary and deferred complex motion.
Those precedents confirm a presentation-only change.
Its older artwork reference is not used as visual authority; current repository assets and `docs/specs/0003-match-visual-cohesion/spec.md` are more specific.
No indexed setup-design precedent was found.

## Acceptance

Observe the pinned-Start regression fail before implementation.
Verify configuration forwarding, selection semantics, keyboard activation, preview terrain/piece data, and scrolling at compact English/Korean text scale1 and2.
Inspect real Flutter captures on Android and iOS, with actual selections and match navigation.
Run `flutter analyze`, scoped `dart format`, the full local gate, and current-head CI and review.
Request new operator visual approval for the changed setup.
