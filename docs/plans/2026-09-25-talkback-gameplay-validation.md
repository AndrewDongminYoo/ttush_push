# TalkBack gameplay validation plan

## Scope and ownership

Follow the [specification](../specs/2026-09-25-talkback-gameplay-validation.md) for [#68](https://github.com/AndrewDongminYoo/ttush_push/issues/68).
Base revision: `6704c629506212cdbcb46568d228f7848b470bf6`.
The root owns runtime operations, these documents, the dated evidence note, historical-spec reconciliation, staging, commits, and PR publication.
No application change is planned unless a reproducible blocker requires a scoped fix.
Any implementation worker receives explicit paths after that diagnosis.

## Steps and verification

1. Inspect the installed TalkBack service and original settings, then build the ordinary development app from the recorded source.
   Verify build completion and the running app identity.
2. Enable TalkBack and use its actual navigation and activation gestures for a complete match.
   Verify focus and results from runtime observations; retain screenshots or recordings and any available speech evidence.
3. Check coach, help, round continuation, restart, leave, and playback input locking.
   Inspect an existing error fixture before claiming error/retry coverage.
4. Record the supported observations and remaining limits; reconcile the historical manual criterion without changing old execution checkboxes.
   Restore emulator settings and verify the resulting configuration.
5. Run appropriate tests, analysis, formatting, Markdown checks, and a read-only independent review.
   Publish a scoped PR and verify current-head CI and hosted review before operator visual approval and merge.

## Precedent

Oracle returned no project-specific TalkBack precedent.
The global sources `wiki/entities/flutter-ui-ux-review.md` and `wiki/sources/claude--rules--evidence-basis-discipline.md` confirm that semantics fixtures do not certify screen-reader behavior and that observations must stay within the reader's actual scope.
Their retrieved source commit was `c1681868ac634e4b2414874716bb75a7864113c4`; current-source freshness was unverified.
