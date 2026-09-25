# TalkBack gameplay validation

## Purpose

[Issue #68](https://github.com/AndrewDongminYoo/ttush_push/issues/68) tracks actual Android screen-reader gameplay that widget semantics tests and the earlier VoiceOver record cannot establish.
Use the existing Pixel_10 Android 17 emulator and installed TalkBack service.
Retain the production game rules and accessibility architecture.

## Acceptance

1. Record exact application source, flavor/build, runtime, TalkBack version, and changed accessibility settings.
2. With TalkBack enabled, select an explorer, activate a normal destination and a Push, continue rounds, and reach an earned match result.
3. Observe focus, coach/help, playback input lock, result continuation, and announcements through the actual screen reader.
   Record any speech or timing property that the available reader cannot verify as a gap.
4. Exercise accessible error/retry behavior only with an existing fixture that produces the error.
   A fixture result must not be described as a production failure or a complete gameplay pass.
5. Reproduce blockers before making minimal fixes and add meaningful regression coverage for changed behavior.
6. Preserve rendered/runtime evidence, reconcile the historical specification, run applicable repository checks, and obtain independent review.

## Boundaries

Use one native job at a time and make no physical-phone or store writes.
Do not replace actual TalkBack interaction with direct Flutter semantic callbacks or coordinate-only play while the service is disabled.
Restore changed emulator accessibility settings after verification.
Keep unobserved acceptance criteria open rather than inventing a pass.
