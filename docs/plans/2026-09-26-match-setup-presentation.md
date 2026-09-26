# Match setup presentation plan

## Scope and ownership

Continue PR92 in the existing clean task branch and workspace.
The root owns product edits, tests, native verification, Git, and PR updates.
Oracle and review agents are read-only and may not delegate.

## Steps

1. Review the existing setup, theme, game assets, and relevant captures; record confirmed findings and evidence limits.
2. Add a failing pinned-Start regression, then replace the setup composition and add a catalog-driven board preview.
3. Preserve configuration and navigation behavior; verify semantics, keyboard input, compact layouts, and large text with targeted widget tests.
4. Capture the rendered selector and exercise choices and match entry on Android and iOS sequentially.
5. Review the bounded Flutter change, run the local gate, and update PR92 with a coherent UI commit.
6. Complete current-head CI and hosted review, then request operator approval of the new screenshots and merge.

## Expected files

Product edits are limited to `lib/game/start/`, the existing board descriptions in the two ARB files, and their generated localization output through `flutter gen-l10n`.
Update the setup tests and add a focused native setup harness using the existing capture driver.
Keep the spec, plan, and validation record under the standard documentation directories.

## Risks and checks

The preview must display catalog data without fabricating engine snapshots or interpreting legality.
Selection controls must retain visible and semantic state after replacing radios.
The pinned footer must not cover the final scrollable choice.
Use rendered captures for layout and targeted interactions for reachability; static assertions alone do not prove either.
