# Centered Fall Playback Interview Ledger

## Sources

- GitHub Issue #26 reports that a displaced explorer travels beyond an adjacent hole before disappearing.
- `RoundBoard` currently derives a fall target at 1.3 cell widths from the displaced explorer's source and keeps painting the explorer through the end of playback.
- Rust already supplies the displaced piece, exit direction, final snapshot, and event order through `MoveResolution`.
- The existing board paint test checks intermediate movement in every exit direction, but it does not check the final visible position or disappearance.
- The existing production sprite scene exercises a Push to another foothold, so its native screenshots cannot verify a fall into a hole.
- Oracle returned `[no precedent found]` for the fall endpoint, visibility boundary, and reduced-motion behavior in Issue #26.
- Codex review found that hiding immediately after progress 0.8 could skip the centered frame when an animation tick crossed that exact boundary.

## Decisions

- Keep the existing Push timing landmarks.
- Move a falling explorer by exactly one cell, which places its center over the adjacent hole.
- Hold the explorer at that endpoint through the remaining playback frames, then let the final Rust snapshot remove it.
- Apply the same endpoint and hold behavior to standard and reduced-motion playback.
- Reuse the existing production sprite scene by making its displaced explorer fall into an adjacent hole.
- Treat pixel-position tests as path evidence and native screenshots as renderer evidence.

## Open Questions

None.
