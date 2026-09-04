import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/board/board_definition.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/frb_generated.dart';

import '../test/support/rules_engine_parity.dart';

void main() {
  test('loads the host bridge and returns the parity fixture', () async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(_hostLibraryPath),
    );
    addTearDown(RustLib.dispose);

    await expectRulesEngineParity(const FrbRulesEngine());
  });

  test('keeps an Expert turn under the host limit', () async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(_hostLibraryPath),
    );
    addTearDown(RustLib.dispose);
    const rulesEngine = FrbRulesEngine();
    final snapshot = rulesEngine.initialMatch(baselineBoardDefinition.rules);
    GameMove? chosen;
    final stopwatch = Stopwatch()..start();

    await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 450)),
      rulesEngine
          .chooseBotMove(snapshot, BotPolicy.strategic)
          .then<void>((move) => chosen = move),
    ]);
    stopwatch.stop();

    stderr.writeln('Expert host turn: ${stopwatch.elapsed}');
    expect(chosen, isNotNull);
    expect(rulesEngine.legalMoves(snapshot), contains(chosen));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test(
    'accepts an irregular board definition through the host bridge',
    () async {
      await RustLib.init(
        externalLibrary: ExternalLibrary.open(_hostLibraryPath),
      );
      addTearDown(RustLib.dispose);

      expectIrregularBoardDefinition(const FrbRulesEngine());
    },
  );

  test('rejects an invalid board definition through the host bridge', () async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(_hostLibraryPath),
    );
    addTearDown(RustLib.dispose);

    expectInvalidBoardDefinitionIsRejected(const FrbRulesEngine());
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
