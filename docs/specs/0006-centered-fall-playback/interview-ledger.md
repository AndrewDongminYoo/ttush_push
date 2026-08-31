# Centered Fall Playback Interview Ledger

## Sources

- GitHub Issue #26 reports that a displaced explorer travels beyond an adjacent hole before disappearing.
- `RoundBoard` currently derives a fall target at 1.3 cell widths from the displaced explorer's source and keeps painting the explorer through the end of playback.
- Rust already supplies the displaced piece, exit direction, final snapshot, and event order through `MoveResolution`.
- The existing board paint test checks intermediate movement in every exit direction, but it does not check the final visible position or disappearance.
- The existing production sprite scene exercises a Push to another foothold, so its native screenshots cannot verify a fall into a hole.
- Oracle returned `[no precedent found]` for the fall endpoint, visibility boundary, and reduced-motion behavior in Issue #26.

## Decisions

- Keep the existing Push timing landmarks.
- Move a falling explorer by exactly one cell, which places its center over the adjacent hole.
- Paint the explorer at that endpoint through the displacement boundary, then omit it from later playback frames.
- Apply the same endpoint and visibility boundary to standard and reduced-motion playback.
- Reuse the existing production sprite scene by making its displaced explorer fall into an adjacent hole.
- Treat pixel-position tests as path evidence and native screenshots as renderer evidence.

## Open Questions

None.
