# iPad gameplay validation plan

## Contract and ownership

Follow [the specification](../specs/2026-09-25-ipad-gameplay-validation.md) for [#69](https://github.com/AndrewDongminYoo/ttush_push/issues/69).
Base revision: `bb1d366389ee9cd32fb29900e3a09b44eb481e30`.
Use the existing main workspace on the task branch.
The implementation worker owns only `integration_test/ios_gameplay_flow_test.dart` and `test_driver/ios_gameplay_flow_driver.dart`.
The root owns this plan, the specification, the eventual evidence note and release-evidence cross-reference, the production scheme's Flutter-generated LLDB initialization references, native execution, review, staging, and PR publication.
Oracle returned no relevant indexed precedent for iPad gameplay or opening bias.

## Steps and checks

1. Add a bounded real-engine gameplay integration test and a screenshot driver using existing project patterns.
   Verify that the test uses production app routes and native Rust initialization, records actual UI moves, and has explicit turn and wait limits.
   Keep native jobs queued while the one-minute load exceeds the logical core count.
2. Run the reference simulator sequentially after resource availability is confirmed.
   Verify bridge parity and the real-engine gameplay scenarios.
   Make a temporary missing-tap negative control fail at the move assertion before trusting the restored pass.
3. Exercise actual orientation controls and inspect saved screenshots.
   Verify English/Korean, large text, coach/help, results, and leave controls; retain gaps instead of substituting fixture screenshots.
4. Write a dated evidence note and reconcile the release note only to the extent supported by the new observations.
   Verify source/build provenance and local document links.
5. Run the repository checks and an independent review of the complete candidate.
   Verify the local gate, Markdown spelling, and review findings before committing.
6. Publish coherent commits and a PR, then observe current-head CI and hosted code/security reviews.
   Request operator review of rendered evidence and operator merge at the established boundary.

## Constraints

Do not introduce fake game outcomes, production test switches, orientation support changes, dependencies, or unrelated UI improvements.
If a real defect appears, reproduce it before making the smallest source correction.
Report unavailable native execution as pending rather than a pass.
