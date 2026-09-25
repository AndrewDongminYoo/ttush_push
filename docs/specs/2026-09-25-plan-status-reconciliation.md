# Historical plan status reconciliation

## Problem

[Issue #80](https://github.com/AndrewDongminYoo/ttush_push/issues/80) identifies historical checklists that readers can mistake for the current implementation backlog.
Some planned deliverables exist under later designs, while device verification and product decisions remain open.

## Contract

Add dated reconciliation sections to the playable-round, authoritative-resolution, ad-provider, accessibility, and release documents.
Classify affected outcomes as implemented, superseded, verification pending, or deliberately deferred, and link each classification to source evidence.
Preserve historical checkboxes and commands unless a dated correction is needed to prevent an obsolete statement from acting as current guidance.
Current code proves an artifact exists; it does not prove that the original TDD sequence, manual check, commit, or publication occurred.

Use the existing checkbox-drift note as the reader's reconciliation index.
Record current Expert and Korean UI implementation, distinguish the functional MVP from the original blueprint's remaining analysis work, and link the open Web decision.
Use [tracker #81](https://github.com/AndrewDongminYoo/ttush_push/issues/81) as the single entry point for remaining verification and decisions.
Label store approval evidence with its date and recorded source; do not infer current console state from repository files.

## Boundaries and verification

This is a documentation-only change.
Do not change application behavior, dependencies, generated files, product scope, or historical execution records.
Do not claim a completion percentage, rerun native builds for prose, or turn screenshots into evidence of interactive gameplay.
Verify source references, changed Markdown links, whitespace, spelling, and the repository's applicable document checks.
Review the final diff for unsupported completion claims before the commit and hosted review.
