# Foothold State Progression V1 Reference Set

OpenAI's built-in `imagegen` tool generated both source outputs on 2026-09-01.
`damaged_candidate_c_selected_source.png` is the source for the active damaged foothold.
`damaged_candidate_b_rejected.png` preserves an alternate that strengthened the fractures but changed the established tile composition too far.
Both files are raw opaque generator outputs and require the alpha processing recorded for the active sprite.
The runtime `ProductionSpriteSet` does not load this directory, and `pubspec.yaml` does not bundle it.
The selected prompt and processing record remain in `assets/images/sprites/README.md`.

## Integrity

| File                                      | SHA-256                                                            |
| ----------------------------------------- | ------------------------------------------------------------------ |
| `damaged_candidate_b_rejected.png`        | `0e242928534ed0d6d13247cbd0dfb99dd1fc81dfc7dae7029a7ec6df77685710` |
| `damaged_candidate_c_selected_source.png` | `388cf0476578ec00b75765874d433a7ced8e2dea7ea9cfffd5fa86203c0b017e` |

The normalized active `foothold_damaged.png` hash is `bb0b05506404908182b55e0c59dd941522f422a89ab591d4ef88ceba24caebeb`.
