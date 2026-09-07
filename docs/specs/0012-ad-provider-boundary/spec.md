# Spec: Ad Provider Boundary

## Status

Approved for implementation by the operator on 2026-09-06.
The approved scope is the seam alone: no ad SDK, no new dependency, and no network call.

## Problem

The operator's AdMob account was suspended on another personal project, and an AppLovin MAX account is pending there.
A suspension removes the SDK and the account, not one demand source, so a mediation dashboard cannot absorb it: the app itself has to change.

ttush_push ships no ads today.
If ads arrive later with the SDK called from the match screen, a forced provider change edits game code under the time pressure of a suspended account.
Placing the seam while nothing depends on it costs almost nothing; placing it during a suspension costs a release.

## Goal

Adopting or replacing an ad provider touches the flavor entry point and one adapter, never the match screen.
Today's binary stays exactly as it is: no SDK, no dependency, no network request, no new permission, and no privacy declaration.

## Product Contract

1. The game exposes exactly one ad-bearing moment: the player finished a match and asked for a new one.
2. No ad call occurs during a round, during move resolution, or while the round-complete screen is up.
3. The shipped default performs no work and shows nothing.
4. Provider selection is a build-time choice made in the flavor entry points.
5. The player-visible behavior of the current release does not change.

## Interface

`lib/game/ads/ad_gateway.dart` holds the whole boundary.

```dart
abstract interface class AdGateway {
  Future<void> matchDecided();

  Future<void> beforeNewMatch();
}
```

The two members are two moments on the game's timeline rather than two SDK operations.
`matchDecided` is the earliest point at which the next interruption can be prepared, and `beforeNewMatch` is the only point at which one may be shown.
Splitting them is what keeps a player from waiting on a load; joining them would put the load in front of the player.

The interface carries no provider vocabulary.
It names no ad format, no ad unit, no mediation, and no consent step, so a provider adapts to the game rather than the game to a provider.
This follows `RoundFeedback`, whose comment states the same rule for haptics and sound: the page reports the event, and the layer below alone decides how it is felt.

`NoAdGateway` is a `const` implementation whose members complete immediately.
It is what ships until a provider is chosen.

Disposal stays off the interface.
`RoundFeedback` keeps disposal on the concrete `PlatformRoundFeedback` rather than on the interface, and a provider adapter does the same, disposed by whoever constructs it.

## Wiring

The gateway is threaded the way `rulesEngine` already is: `App` to `AppView` to `StartPage` to `GamePage`, nullable at each step.
`GamePage` applies the default once, as it does for its coach store and feedback dependencies, which resolve the same way.

The flavor entry points `lib/main_development.dart`, `lib/main_staging.dart`, and `lib/main_production.dart` are the build-time swap point.
They pass nothing today, so every flavor runs `NoAdGateway`.
Adopting a provider changes one line in each entry point that should carry it.

## Call Sites

`matchDecided()` is called, unawaited, from a post-frame callback the page schedules where the controller first reports the match is over, so the call lands after the frame that paints the result rather than inside the replay listener Flutter is waiting on to build and paint it.
An ad provider must never delay the result the player is waiting to read, and leaving the future unawaited alone does not achieve that: an adapter is free to do synchronous setup before it returns a future, and that work would run wherever the call is made.
The call is deliberately not guarded on `mounted` or on controller identity, unlike the deferred calls that go on to mutate the page, because it reports a match that was already decided and mutates nothing — a decided match owes exactly one call whether or not the page survives the frame.

`beforeNewMatch()` is awaited inside `_restart()` before the controller restarts.
The state check after the await follows the page's existing mounted and generation pattern, so a page disposed during an interruption does not restart a dead state.

The point was chosen over the result screen itself so that an interruption never covers the outcome the player just earned.
Moving it to the moment the result appears is a one-line change if the operator prefers that later.

Leaving a decided match and starting again from the start screen reaches a new match without a `beforeNewMatch()` call, which is consistent with Product Contract item 1 but will make a future frequency policy undercount, so the first adapter should expect it.

## Test Strategy

A recording fake stands in for a provider, because the assertions are about when the game calls out, not about what a provider does.

1. A round in progress produces no call at all.
2. A decided match produces exactly one `matchDecided` call.
3. The board does not reset while `beforeNewMatch` is pending: a fake holding an incomplete future holds the restart, and completing it lets the restart run.
4. The existing `GamePage` widget tests pass unchanged under the default gateway, which is what proves the shipped behavior did not move.
5. An interruption that outlives the restart budget does not strand the page: a fake whose future never completes lets the budget elapse, and the new match then starts while that abandoned call is still outstanding, which is the page behavior that constraint 8 below turns into an obligation on the adapter.

The third assertion is the one that earns this work before any SDK exists, because it fixes the ordering that a provider would otherwise be free to break.

## Expected Source Scope

- New: `lib/game/ads/ad_gateway.dart`.
- New: a gateway test under `test/game/ads/`, plus the ordering assertions in the existing `GamePage` widget test.
- Edited: `lib/game/view/game_page.dart`, `lib/game/start/start_page.dart`, `lib/app/view/app.dart`.
- Unchanged: `engine/`, `lib/src/rust/`, `pubspec.yaml`, `android/`, and `ios/`.

## Non-goals

- Any ad SDK, including AppLovin MAX and AdMob.
- Any new package dependency or network call.
- Consent collection, a CMP, and the iOS App Tracking Transparency prompt.
- A privacy policy, App Privacy answers, and the Play Data Safety declaration.
- The Android `INTERNET` permission.
- Banner and rewarded placements.
- Runtime or remote provider switching.
- Any change to the rules engine, the bridge, or match presentation beyond the two call sites.

## Deferred Store and Privacy Consequences

These are recorded here so the next step is not rediscovered, and none of them belongs to this work.

The moment a real SDK lands, all of the following move together: item 4 of `docs/notes/app-review-information.md`, which currently tells App Review that the app uses no advertising network and makes no network request; the App Privacy answers in App Store Connect; the iOS App Tracking Transparency prompt; the Play Data Safety declaration; a published privacy policy; and the Android `INTERNET` permission, which the release manifest does not currently carry.
The tracking prompt is not separate work in the AdMob shape: the consent flow presents it, and adding a tracking package on top of that duplicates it.
Issue #42 reached the same conclusion for an analytics SDK and deferred it for the same reason.

The store listing is the part that is easy to miss.
Both `fastlane/metadata/android/en-US/full_description.txt` and its Korean counterpart tell the reader the game has no ads.
quest-keeper recorded the same sentence in its own listing and classed breaking it as a promise to the player rather than a copy edit, so shipping ads here starts with changing that copy and accepting the listing review that follows.

An App Store review round is open at the time of writing, and the answers sent to Apple stay true only while no SDK is present.

## Constraints on the First Real Adapter

None of this is built now.
It is written here because the Prism Defense session was asked what it would do differently, and these are its answers plus the incident that produced them.

1. **Test-traffic separation is a design item of the first integration, not a step in a checklist afterwards.** The suspension came from live inventory reaching the operator's own phone, and the cause was a test-device identifier held in the build.
2. **The identifier that shape depends on is per-installation, so a build-time list decays every reinstall.** One phone produced three different values in four weeks. Whatever the provider, the exemption belongs in the provider's console, which survives a reinstall and needs no build.
3. **Register that exemption before the first live ad, because a suspended account cannot reach the console settings that would fix it.** It is not repairable after the incident it prevents.
4. **The proof of exemption is the provider's own log line, never a value the app reports about itself.** The app printed a configured test-device count while no device matched, and that false green is what the release shipped on. Read it with an unfiltered device log: a process filter dropped a whole launch, and the macOS console hides informational messages by default, so its silence proves nothing.
5. **Wrap the provider call one layer deeper than the gateway, so the adapter's own logic is testable.** In prism_defense the SDK-touching class has no test seam and sits outside the coverage floor, which leaves review as its only gate.
6. **Frequency policy belongs behind the gateway, not in the game.** `beforeNewMatch` asks; whether anything shows is the gateway's decision, so a cap changes no game code and needs no interface change.
7. **The two stores are two provider apps with different unit ids, and the app id is read from the manifest and the plist rather than passed in.** A silent mismatch there produces no fill and no error.
8. **An operation the restart budget abandons must not present afterwards.** `_restart()` bounds how long it waits on `beforeNewMatch()` and starts the new match once that bound elapses, because a future that never completes would otherwise leave the new-match button dead for the life of the page. The bound ends the waiting only; it does not cancel the provider's work, so an interruption that resumes later would appear over a match already in progress. Keeping that from happening is the adapter's obligation, because the interface carries no cancellation and adding one is the signature change the Known Risk already covers: once its own `beforeNewMatch()` has been abandoned, the adapter drops the presentation rather than showing it late.

## Verification

```shell
dart format --output=none --set-exit-if-changed <changed-dart-files>
flutter analyze
flutter test test/game/view/game_page_test.dart test/game/ads/
merry run check
```

## Known Risk

An interface with one no-op implementation is an unvalidated abstraction, and this Spec does not pretend otherwise.
The mitigation is its size and its vocabulary: two members, both named for game events, so the first real provider is expected to adapt to it.
A signature change at the first real integration remains possible, and the seam is still worth having, because the change would then be confined to one file and its adapter.

## Precedent

An oracle lookup over the operator's personal projects returned four findings that shape this Spec.
A direct question to the Prism Defense session is still open at the time of writing, and its answer is recorded here when it arrives.

1. **A Dart-side ad boundary is established practice, not a new idea.** Both apps that ship ads place one in front of the SDK, and both make it a build-time-gated factory rather than a bare interface: prism_defense returns a disabled controller outside Android and iOS and whenever the app id is empty, and bubble_shooter's factory returns real gateways only on Android and iOS and in-repo fakes everywhere else. This Spec follows that shape; the flavor entry point is this project's equivalent of the factory.
2. **The two projects gate the platform differently, and the conflict is recorded rather than resolved here.** bubble_shooter's rule is a runtime check on `defaultTargetPlatform`, never `Platform.isAndroid` and never a conditional-import shim, written after the ad package's `dart:io` import threatened a Web build. prism_defense picks its platform implementation through a conditional import instead. ttush_push has a Web CI job, so whichever shape the first adapter takes, keeping `tool/build_web.sh` green is the requirement that decides it.
3. **The existing boundaries have no headless test seam, and review rather than tests is what catches defects there.** One prism_defense session found thirteen real defects that neither static analysis nor a large suite caught. The seam in this Spec is deliberately placed one level higher, at the game's call ordering, which a fake can assert without a provider present. It does not make a future adapter testable, and this Spec does not claim it does.
4. **The suspension was an invalid-traffic finding caused by a stale build-time test-device identifier, not by the choice of network.** The identifier is per-installation, a prior note had assumed it survives reinstall, and the shipped build therefore matched no test device and served live inventory to the operator's own phone with no error on any surface. The decisions written afterwards all harden the AdMob integration rather than diversify away from it: the build-time define was deleted, and re-adding one is classed as a regression.

The Prism Defense session then answered directly and corrected one premise: that project has **not** migrated to AppLovin MAX and has had no response from AppLovin, so no migration experience exists anywhere to copy.
Its own boundary is four files: the interface with a disabled implementation and a factory, one class that touches the SDK, a non-mobile stand-in, and a frequency policy that is independent of any SDK.
The factory returns the disabled implementation when the app id is empty, which is why its tests and ordinary builds run with no ads and its game logic does not know ads exist.
That is the same shape this Spec approves, arrived at independently.

Two gaps are recorded rather than filled.
No decision about avoiding a single-network dependency exists in any personal project, and no rationale for an AppLovin MAX migration exists as a decision body; the operator stated the pending MAX account directly in the session that approved this Spec, which is the source this Spec relies on.

Finding 4 matters for how this work is justified.
It does not argue against the seam, because a suspension removes the SDK whatever caused it, and the operator asked for the option deliberately.
It does argue against treating a provider swap as imminent, and it says the transferable lesson from that incident is about identifier stability rather than about network choice.
