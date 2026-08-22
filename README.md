# Ttush Push

Ttush Push is a Flutter game project with a Rust rules engine that owns every gameplay rule, so both players see a position that neither client can bypass.

## Prerequisites

- Flutter 3.44 or later
- Dart 3.12 or later
- Rust toolchain
- iOS 15.0 or later for iOS builds
- [merry](https://pub.dev/packages/merry) as the script runner: `dart pub global activate merry`

## Run the App

```sh
flutter pub get
merry run dev
```

That runs the development flavor. Use the matching `staging` or `production` flavor and entrypoint when required.

## Verify Changes

```sh
merry run check
```

`merry ls` lists every script, including the individual Dart and Rust gates that `check` composes.

## Rules Engine

The Rust engine under `engine/` is the sole rules authority and stays independent from Flutter.
Run `merry run rust test` for its test suite, and `merry run rust simulate` to replay a fixed seed when comparing balance changes across runs.

## Documentation

- [Rules-engine checkpoint](docs/specs/2026-08-21-rust-engine-checkpoint.md)
- [Implementation plan](docs/plans/2026-08-21-rust-engine-checkpoint.md)
- [Playable round specification](docs/specs/2026-08-22-playable-round-vertical-slice.md)
- [Playable round plan](docs/plans/2026-08-22-playable-round-vertical-slice.md)
