# Android release checklist

The steps that produce a signed, installable Android artifact, and the checks that prove the artifact is the one you meant to ship.
First walked end to end on 2026-09-01 against `64e5e39`; every number below was measured on that run.

## Prerequisites

The `release` signing config in `android/app/build.gradle.kts` reads two sources, in this order.
When `ANDROID_KEYSTORE_PATH` is set in the environment it takes the keystore from `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD`, and `ANDROID_KEYSTORE_PASSWORD`.
Otherwise it reads `storeFile`, `storePassword`, `keyAlias`, and `keyPassword` from `android/key.properties`, which is untracked and must never be committed.
Neither source is validated at configuration time, so a missing or wrong keystore does not announce itself in the Gradle output.
That is why the signer check below is not optional.

Rust needs the Android targets installed. Verify with `rustup target list --installed`; the build uses `aarch64-linux-android`, `armv7-linux-androideabi`, and `x86_64-linux-android`.

## Build

```sh
flutter build appbundle --release --flavor production --target lib/main_production.dart
```

The artifact lands at `build/app/outputs/bundle/productionRelease/app-production-release.aab`.
A warm-cache run took 106 seconds and produced a 55.7 MB bundle.

## Verify the artifact

Four checks, in this order. Each one has failed silently in some project, so run all four rather than trusting the exit code.

1. **The Rust engine is packaged for every ABI.** Cargokit builds `libengine.so` per target, and a packaging regression drops it without failing the Gradle task; the app then dies at `RustLib.init` on a real device.

   ```sh
   unzip -l build/app/outputs/bundle/productionRelease/app-production-release.aab \
     | grep 'libengine\.so$'
   ```

   Expect three lines: `arm64-v8a`, `armeabi-v7a`, `x86_64`. Measured sizes were 730 KB, 471 KB, and 773 KB.

2. **The bundle is signed with the release key, not the debug key.**

   ```sh
   keytool -printcert -jarfile build/app/outputs/bundle/productionRelease/app-production-release.aab
   ```

   Expect `O=Donminzzi Lab, CN=Dongmin Yu`, valid until 2051. Any other signer means neither key source was picked up, and Play accepts an upload only from the key registered for this application id.

3. **The release build actually starts and reaches Rust.** Minification runs only in the release build, so a debug run proves nothing about it, and `android/app/proguard-rules.pro` is listed in `proguardFiles` but does not exist, which leaves R8 running on the default rules alone. Install the release APK on any arm64 runtime and look at the first screen.

   ```sh
   flutter build apk --release --flavor production --target lib/main_production.dart
   adb install -r build/app/outputs/flutter-apk/app-production-release.apk
   adb shell monkey -p kr.donminzzi.ttush_push -c android.intent.category.LAUNCHER 1
   adb exec-out screencap -p > /tmp/launch.png
   ```

   A rendered board is the evidence, because the board comes from the snapshot `initial_match` returns; if the bridge had failed there would be nothing to draw. Tapping an explorer and then a marker exercises `match_legal_moves` and `match_apply_move` as well. Verified on 2026-09-01 against `64e5e39` on an arm64-v8a emulator: the board drew, three legal-move markers appeared, the move applied, the vacated tile cracked, and the turn passed. `adb logcat -d` held no `FATAL` and no `UnsatisfiedLinkError`.

4. **The bundle size is what you think it is.** The 55.7 MB figure is not the download size: 25.7 MB of it is `BUNDLE-METADATA/com.android.tools.build.debugsymbols`, which Play strips after using it for crash symbolication. The arm64 split delivered to a device is about 12.9 MB. Do not open a size-reduction task off the raw bundle number.

## Version and build number

`pubspec.yaml` carries `version: <name>+<code>`, currently `1.0.0+1`.

- The build number after `+` increments by one for every artifact uploaded to any track, and is never reused. Play rejects a duplicate `versionCode` outright, and the number is shared across all tracks of one application id.
- The version name before `+` follows semver against user-visible behaviour, not internal refactors. A build that only changes the artifact bumps the build number alone.
- Bump both in `pubspec.yaml` only. The Gradle files read the value from Flutter, so editing `build.gradle.kts` would leave the two out of step.

## Known warnings that are not failures

- `Flutter support for your project's Kotlin version (2.2.20) will soon be dropped ... at least 2.3.20`. The build still succeeds. Upgrading KGP is its own task and touches `android/settings.gradle`.
- `This version only understands SDK XML versions up to 3 but ... version 4 was encountered`. This comes from a command-line tools and Android Studio version skew and does not affect the artifact.
- `1 package has newer versions incompatible with dependency constraints` (`http_parser`). This is a transitive pin, not something this build controls.

## What this checklist does not cover

It stops at a signed local artifact. Uploading it is a separate manual step in Play Console.

That upload has happened once already, outside this checklist: version 1 (1.0.0), version code 1, was published to the internal testing track on 2026-09-01 and is available to the 34-member beta tester list. The next upload therefore needs a build number of 2 or higher, which is the rule above and not a detail.

What remains uncovered is everything a production release needs. The app is still a draft in Play Console, so the store listing, the privacy policy, the data safety form, and the content rating questionnaire are all outstanding. iOS packaging is not covered here at all; no archive has been produced.
