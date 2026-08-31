# Directional Explorer Sprites Interview Ledger

## Sources

- GitHub Issue #27 requires four static directions for each team, opposing initial facings, presentation-only lifecycle updates, source preservation, asset contract tests, and native captures.
- The operator-supplied 3-by-3 Azure turnaround is preserved at `assets/images/reference/directional-explorer-sprites-v1/azure_turnaround_reference.png` with SHA-256 `5101ee7a93afc4596cc41dcb2359c3803960fb5e4e598ebaf08bc2b6f05f4c65`.
- `ProductionSpriteSet` currently loads one neutral explorer image per team.
- `RoundBoard` currently selects an explorer image only by team.
- `GamePage` owns replay, round advance, restart, and runtime board replacement lifecycle.
- Painted rows invert Rust y coordinates, and the existing direction labels already map Rust `up` to visual down and Rust `down` to visual up.
- Oracle confirms that Rust owns topology, Push resolution, round and match rules, and snapshot integrity while Flutter owns presentation.
- Oracle found no precedent for the exact facing lifecycle, asset contract, source preservation, or three-state native capture matrix.

## Decisions

- Define facing as a visual `ExplorerFacing` value with `up`, `down`, `left`, and `right`.
- Default Azure to visual up and Ember to visual down so the starting teams face one another.
- Keep only non-authoritative facing overrides in `GamePage` and pass them into `RoundBoard`.
- Derive movement facing from Rust-authored travel coordinates and displaced-piece facts.
- Update both the mover and a displaced explorer before Push playback starts.
- Preserve the last facing for every surviving explorer after playback commits.
- Reset facing overrides after a successful round advance, restart, or runtime board replacement.
- Keep the existing static fallback shapes unchanged when production sprites are unavailable.
- Generate eight separate transparent production exports with one canvas size and one foot-anchor contract.
- Defer foot movement and add no animation dependency.

## Open Questions

None.
