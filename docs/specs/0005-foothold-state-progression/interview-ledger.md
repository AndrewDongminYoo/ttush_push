# Foothold State Progression Interview Ledger

## Sources

- GitHub Issue #25 reports that the damaged foothold has too few visible fractures at native board scale and that the three foothold states repeat one uniform stone treatment.
- The completed match visual cohesion Spec and sprite provenance define one active 512-by-512 transparent sprite per foothold state, a shared orthographic square camera, matched alpha footprints, and unbundled reference artwork.
- Direct inspection of the current native screenshots shows one dominant fracture on the damaged foothold, while the intact and collapsed states already provide readable endpoints.
- The existing production sprite test guards dimensions, transparency, hole connectivity, and matched square footprints, but it does not prove that damage reads clearly at board scale.
- The existing production sprite scene fixture can show intact, damaged, and collapsed footholds on both native renderers without adding a new runtime path.
- Oracle returned `[no precedent found]` for Issue #25, so this work establishes a new project precedent within the issue's approved boundaries.

## Decisions

- Replace only the active damaged foothold sprite.
- Keep one active sprite per state and do not add runtime variants.
- Use the intact sprite as the composition anchor and the collapsed sprite as the severity ceiling.
- Require several bold branching fractures and modest edge chips while keeping every major slab connected and the center visibly solid.
- Preserve at least one unselected generated candidate under an unbundled reference directory.
- Treat automated image checks as mechanical guards and native screenshots as the evidence for state readability.

## Open Questions

None.
