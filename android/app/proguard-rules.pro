# Project rules for R8. This file is intentionally empty of rules.
#
# It exists because `build.gradle.kts` names it in `proguardFiles` and a
# missing file is skipped in silence: the merged configuration under
# `build/app/outputs/mapping/productionRelease/configuration.txt` simply did
# not list it, so "R8 has no project rules" and "R8 lost the project rules"
# looked the same from the outside. With the file present that section appears,
# and its emptiness is a statement rather than an accident.
#
# Nothing needs a rule here today, measured rather than assumed:
#
#   - Every dependency that must survive shrinking ships its own consumer
#     rules. The merged configuration carries about thirty such sections,
#     among them `jni`, `jni_flutter`, `androidx.preference`, `okio` and the
#     coroutines pair.
#   - Flutter contributes `flutter_proguard_rules.pro`, which keeps every
#     implementation of `FlutterPlugin`.
#   - `MainActivity` is kept by the aapt-generated rules, because the manifest
#     names it. It appears in `seeds.txt`.
#   - The Rust engine is loaded through dart:ffi: the generated bridge takes an
#     `ExternalLibrary`, so no Java symbol stands between the app and
#     `libengine.so` for R8 to remove. The `jni` rules above belong to a
#     transitive plugin dependency, not to the bridge.
#
# Two rules that look obviously right here are wrong, and both were measured
# on this app before being dropped:
#
#   - `-keepattributes LineNumberTable` is a ProGuard-era requirement. R8
#     already retains line information: the release DEX built without it held
#     292,603 line entries.
#   - `-renamesourcefileattribute SourceFile` actively costs something. R8
#     stamps each class's source file with `r8-map-id-<hash>`, which is what
#     lets a crash reporter match a stack trace to the right `mapping.txt`.
#     Adding the rename replaced that identifier with the literal
#     `SourceFile` across all 2,275 classes, discarding the correlation.
#
# So before adding a rule: reproduce the failure, then read
# `configuration.txt` to confirm nothing already covers it, and
# `build-tools/*/dexdump -d` on the release DEX to confirm the symbol is
# actually gone. A blanket `-keep` on this app's package would switch
# shrinking off for code that measurably does not need it.
