---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which text is difficult to read?

Answer: The operator reports that text on the opponent-selection screen uses a color that is too similar to its background.

Decision: Treat the bottom-sheet heading and all opponent option labels as the affected text.

Source: Operator request in this session and the current `_OpponentSelectionSheet` implementation on 2026-09-01.

### L2

Status: current

Question: What causes the low contrast?

Answer: `showModalBottomSheet` sets `_panelColor` as a dark background, while `_OpponentSelectionSheet` inherits text colors from the app's light `ColorScheme`.

Decision: Set a local high-contrast foreground color for the sheet heading and option labels.

Source: `lib/game/view/game_page.dart` and `lib/app/view/app.dart` on 2026-09-01.

### L3

Status: current

Question: How much of the theme should change?

Answer: The reported problem is limited to one existing bottom sheet.

Decision: Keep the app theme, sheet background, selection flow, and radio controls unchanged.
Change only the text foreground in `_OpponentSelectionSheet`.

Source: The operator's minimal-scope rules and current project structure.

### L4

Status: current

Question: What evidence will prove that the text is readable?

Answer: The widget test can read the actual `BottomSheet` background and each label's resolved `RenderParagraph` color.

Decision: Require at least a 4.5-to-1 contrast ratio for the heading and every selected or unselected option label.

Source: The existing opponent-sheet widget-test seam in `test/game/view/game_page_test.dart`.

### L5

Status: current

Question: Does the project have an applicable precedent for this contrast fix?

Answer: `[no precedent found]`

Decision: The rendered-color regression becomes the first project precedent for opponent-sheet text contrast.

Source: Personal-account Oracle lookup for `ttush_push` on 2026-09-01.
