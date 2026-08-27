import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/frb_generated.dart';

import '../test/support/rules_engine_parity.dart';

void main() {
  test('loads the host bridge and returns the parity fixture', () async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(_hostLibraryPath),
    );
    addTearDown(RustLib.dispose);

    expectRulesEngineParity(const FrbRulesEngine());
  });
}

String get _hostLibraryPath {
  if (Platform.isMacOS) {
    return 'engine/target/release/libengine.dylib';
  }
  if (Platform.isLinux) {
    return 'engine/target/release/libengine.so';
  }
  throw UnsupportedError(
    'The host bridge test supports macOS and Linux, not '
    '${Platform.operatingSystem}.',
  );
}
