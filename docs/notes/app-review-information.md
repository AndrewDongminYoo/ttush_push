# App Review Information

Answers to App Store Review's Guideline 2.1 information request, written once and reused for every submission.
Every claim below is checked against this repository, and the table under "Where each claim was verified" names the file that carries each check, so a later submission can re-verify a claim instead of trusting this file.

## How to send this

Paste the canonical block into two places.

1. **Resolution Center reply**: the preamble under "Reply preamble", then the canonical block.
2. **App Store Connect → App Review Information → Notes**: the canonical block alone, with no preamble.
   Since 2026-09-19 `deliver` fills that field from `fastlane/metadata/ios/review_information/notes.txt`, which is generated from this file rather than edited: after changing the canonical block, regenerate it with the command below and commit both.
   The block pulled from App Store Connect that day was the 2026-09-06 wording, five sentences behind this file, which is what the regeneration exists to prevent.

   ````sh
   awk '/^## Canonical block$/{s=1} s&&/^```plaintext$/{f=1;next} f&&/^```$/{exit} f' docs/notes/app-review-information.md > fastlane/metadata/ios/review_information/notes.txt
   ````

The canonical block carries no build number and no dates, so it stays correct across submissions.
Anything submission-specific belongs in the preamble.

A Resolution Center reply is capped at 4,000 characters, and the preamble and the canonical block are sized to fit that cap together, so the canonical block on its own is shorter still.
Measure both blocks before pasting, because an edit that reads short can still cross the cap.

````sh
awk '/^```plaintext$/{f=1;next} /^```$/{f=0} f' docs/notes/app-review-information.md | wc -m
````

## Reply preamble

```plaintext
Thank you for the review. A screen recording captured on a physical iPhone running the current iOS release has been uploaded; it begins with launching the app from the Home Screen. The answers below are also in the Notes field of App Review Information.
```

## Canonical block

```plaintext
1. DEMONSTRATION AND ABSENT FLOWS

The app has no accounts, no login, and therefore no account deletion flow. It has no user-generated content and no user-to-user interaction, so no content reporting or blocking mechanism applies. The screen recording provided was captured on a physical iPhone and shows the full flow.

2. PURPOSE AND TARGET AUDIENCE

Ttush Push is a single-device, turn-based tactics game. Two expeditions face each other on a board of floating ruins. On a turn a player moves one explorer or Pushes a rival explorer into the space behind it, and a foothold collapses once explorers have moved off it twice on their own turn, so the board shrinks as the round runs. A round is won by pushing one rival explorer into a collapsed foothold or off the board, or by leaving the rival with no legal move, and the match by taking two rounds.

It is entertainment for players who enjoy short abstract strategy: a five-minute duel that needs no connection and no account, where one phone serves two people across a table and four AI difficulty levels stand in when playing alone.

3. SETUP AND ACCESS TO MAIN FEATURES

No setup is required: no login, no demo account, no credential, no sample file, and no in-app purchase.

- Launch the app; the New Match screen appears. Choose "2 Players" for two people on one device, or "Play vs AI" and a difficulty of Easy, Normal, Hard, or Expert. Tap "Start Match".
- Tap one of your explorers. A filled dot marks a legal move; a ring around a rival explorer marks a legal Push. Tap a marker to act.
- The first match shows a three-step guide covering selection, moves and Pushes, and collapsing footholds. The help icon in the player panel replays it from the first step during play.

The only value stored is whether the guide was completed, kept in local device preferences.

4. EXTERNAL SERVICES, TOOLS, AND PLATFORMS

None. The app delivers its core functionality entirely on the device and makes no network request. There is no data provider, authentication service, payment processor, AI service, advertising network, analytics, or crash reporting, no backend, and no third-party SDK that contacts one. The runtime dependencies are Flutter, flutter_rust_bridge, audioplayers, shared_preferences, and intl, and none of them opens a connection here. ITSAppUsesNonExemptEncryption is false, and the Android build of the same codebase declares no INTERNET permission.

5. REGIONAL DIFFERENCES

None. Every feature, board, AI difficulty level, and rule is identical in all regions. The interface is localized in English and Korean and follows the device language setting; any other language sees English, which is a device preference rather than a regional difference in features or content.

6. REGULATED INDUSTRY AND THIRD-PARTY MATERIAL

The app operates in no regulated industry: no gambling or simulated gambling, no real-money or virtual currency, no health or financial function, and no collection of personal data.

The app contains no licensed or restricted third-party content: no asset pack, no stock library, no character, no brand, and no trademark. The explorer and foothold sprites and the background were generated with an image generation tool at the developer's direction and processed by the developer, and the sound effects are synthesized by a script kept in the project source. What the app does ship from others is standard open source software, each item under its own license: the Poppins typeface under the SIL Open Font License 1.1, bundled with its license text; the Material Icons font that the Flutter framework bundles, under Creative Commons Attribution 4.0; and the framework itself with the packages listed in item 4.
```

## Where each claim was verified

| Claim                                 | Verified against                                                                                                                                                                                         |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| No network, no third-party service    | `pubspec.yaml` dependency list, `engine/Cargo.toml` (only `flutter_rust_bridge`), no HTTP or socket call under `lib/`                                                                                    |
| Round win and foothold decay          | `engine/src/lib.rs`: one knockout ends a round (`apply_resolved_move` returns on `resolution.knockout`), only the mover's departure tile decays, and `WINS_REQUIRED` is 2                                |
| No INTERNET permission in release     | `uses-permission` appears only in `android/app/src/debug` and `android/app/src/profile` manifests                                                                                                        |
| Encryption declaration                | `ios/Runner/Info.plist`, `ITSAppUsesNonExemptEncryption` = false                                                                                                                                         |
| English and Korean, device-driven     | `ios/Runner/Info.plist` `CFBundleLocalizations`, `AppLocalizations.supportedLocales` in `lib/app/view/app.dart`                                                                                          |
| Guide replay entry point              | `_CoachHelp` in `lib/game/view/game_page.dart`, shown in the player panel while a round is playable                                                                                                      |
| Only stored value is guide completion | `lib/game/coach/first_play_coach_store.dart`, the single `shared_preferences` key                                                                                                                        |
| Artwork provenance                    | `assets/images/sprites/README.md`, and decision L3 in `docs/specs/0001-production-sprite-set/interview-ledger.md`                                                                                        |
| Sound provenance                      | `tool/generate_sfx.dart`, and `docs/specs/2026-08-22-tactile-feedback.md`                                                                                                                                |
| Material Icons license                | `MaterialIcons_LICENSE.txt` in the Flutter SDK's `material_fonts` artifact (Creative Commons Attribution 4.0), with `uses-material-design: true` in `pubspec.yaml` and three `Icons.*` uses under `lib/` |
| Poppins license                       | `assets/licenses/poppins/OFL.txt`, bundled through the `assets/licenses/poppins/` entry in `pubspec.yaml`                                                                                                |
| Opponent options                      | `enum Opponent` in `lib/game/match/match_controller.dart`, labelled Easy, Normal, Hard, Expert in `lib/l10n/arb/app_en.arb`                                                                              |

## Recording checklist

This section is for the developer and is not sent to Apple.

Record the build that is under review, not a local build.
Install it from TestFlight on the physical iPhone, because a development build carries the bundle identifier `kr.donminzzi.ttush-push.dev` and a different display name, and a reviewer who sees that mismatch has a reason to reject again.
Capture with Control Center screen recording on the phone, or with QuickTime Player's movie recording against the phone over USB.

Start the recording on the Home Screen and tap the app icon, because Apple asked for the recording to begin with launching the app.
Aim for two to three minutes.

The play steps below are written as conditions rather than turn counts, because the board decides when each one becomes possible.
The expeditions start four rows apart on a five-by-five board and a move advances one cell, so the earliest legal Push is several turns in, and a foothold only collapses on the second departure from the same cell.

1. Home Screen, tap the Ttush Push icon, and let the launch screen play.
2. New Match screen: leave "2 Players" selected and tap "Start Match".
3. Tap an Azure explorer so its move dots appear, then tap a move dot.
4. Tap the help icon and step through the three guide messages to "Done".
5. Walk the two sides toward each other until a ring appears around a rival explorer, then take that Push and let the resolution play out.
6. Move an explorer off a foothold it has already left once, so the cracked foothold collapses into a hole.
7. Play the round to a win, let ROUND COMPLETE appear, and tap "Start Next Round".
8. Take the second round as well, so MATCH COMPLETE appears and the recording shows a finished match rather than a finished round.
9. Leave the match, choose "Play vs AI" with Expert difficulty, tap "Start Match", and show one AI reply move.

Confirm before uploading that the recording shows the app's display name and icon as they appear in the submission.
Upload the recording first and send the Resolution Center reply after it, because both the preamble and item 1 state that the recording is already provided.

## Decided: iPhone only, iPad deferred (reversed 2026-09-18, see below)

`TARGETED_DEVICE_FAMILY` was set to `"1"` in all nine build configurations of `ios/Runner.xcodeproj/project.pbxproj` on 2026-09-06, so that the app would ship for iPhone alone and App Review would not run it on an iPad.
The decision was taken because the app has never been exercised on an iPad and the listing carries no iPad screenshots; iPad support was deferred rather than ruled out.

Two consequences followed from it.

- The change alters the binary, so the next upload needs a build number above the one already submitted.
- `ios/Runner/Info.plist` still carries `UISupportedInterfaceOrientations~ipad`. It was inert while the family was iPhone-only, and it was left in place for the return.

Bringing iPad back was described as restoring `"1,2"`, running the app on an iPad, fixing whatever the larger layout breaks, and adding iPad screenshots to the listing.

## Reversed: App Store Connect refuses to drop a device family

The 1.1.1 (6) archive built with `"1"` failed its upload on 2026-09-18 at 23:57 with `This bundle does not support one or more of the devices supported by the previous app version. Your app update must continue to support all devices previously supported.`, citing QA1623.
The 1.1.0 (4) build already in App Store Connect declared `"1,2"`, and Apple applies the rule to every later upload of the same app, so the iPhone-only decision cannot be carried out as an update.

`TARGETED_DEVICE_FAMILY` is back to `"1,2"` in all nine configurations, and `xcodebuild -showBuildSettings` for `Release-production` resolves it to `1,2`.
What the 2026-09-06 note listed as the price of bringing iPad back is therefore due before the next submission rather than optional: run the app on an iPad, fix whatever the larger layout breaks, and add iPad screenshots to the listing.
The bugs-and-crashes risk that motivated the decision is unchanged; the only way left to remove it is to test on the device family the app is committed to.

## Outcome: 1.1.1 (6) approved

The universal 1.1.1 (6) archive was submitted on 2026-09-19 and approved by App Review on 2026-09-20, in the operator's words; the verdict itself lives in App Store Connect and his inbox, not in this repository.
The submission carried the Notes field as sent on 2026-09-06, and App Store Connect already held four iPad Pro 12.9-inch screenshots alongside the iPhone set when the listing was pulled on 2026-09-19, so the iPad screenshot obligation above was met before this round closed.
Whether the app was exercised on an iPad before that submission is not recorded here.
The next submission starts from the regenerated `review_information/notes.txt` through `merry run release ios metadata`, and from the same universal device family.
