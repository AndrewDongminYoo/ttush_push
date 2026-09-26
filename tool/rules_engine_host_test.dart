import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/board/board_definition.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;
import 'package:ttush_push/src/rust/frb_generated.dart';

import '../test/support/rules_engine_parity.dart';

const _expectedPlayableCellsById = <String, List<(int, int)>>{
  'baseline': [
    (0, 0),
    (0, 1),
    (0, 2),
    (0, 3),
    (0, 4),
    (1, 0),
    (1, 1),
    (1, 2),
    (1, 3),
    (1, 4),
    (2, 0),
    (2, 1),
    (2, 2),
    (2, 3),
    (2, 4),
    (3, 0),
    (3, 1),
    (3, 2),
    (3, 3),
    (3, 4),
    (4, 0),
    (4, 1),
    (4, 2),
    (4, 3),
    (4, 4),
  ],
  'large': _largePlayableCells,
  'large-holes': _largePlayableCells,
  'clipped-corners': [
    (0, 1),
    (0, 2),
    (0, 3),
    (1, 0),
    (1, 1),
    (1, 2),
    (1, 3),
    (1, 4),
    (2, 0),
    (2, 1),
    (2, 2),
    (2, 3),
    (2, 4),
    (3, 0),
    (3, 1),
    (3, 2),
    (3, 3),
    (3, 4),
    (4, 1),
    (4, 2),
    (4, 3),
  ],
};

const _largePlayableCells = <(int, int)>[
  (0, 0),
  (0, 1),
  (0, 2),
  (0, 3),
  (0, 4),
  (0, 5),
  (0, 6),
  (1, 0),
  (1, 1),
  (1, 2),
  (1, 3),
  (1, 4),
  (1, 5),
  (1, 6),
  (2, 0),
  (2, 1),
  (2, 2),
  (2, 3),
  (2, 4),
  (2, 5),
  (2, 6),
  (3, 0),
  (3, 1),
  (3, 2),
  (3, 3),
  (3, 4),
  (3, 5),
  (3, 6),
  (4, 0),
  (4, 1),
  (4, 2),
  (4, 3),
  (4, 4),
  (4, 5),
  (4, 6),
  (5, 0),
  (5, 1),
  (5, 2),
  (5, 3),
  (5, 4),
  (5, 5),
  (5, 6),
  (6, 0),
  (6, 1),
  (6, 2),
  (6, 3),
  (6, 4),
  (6, 5),
  (6, 6),
];

const _largeStartingPieces = <rust.GamePiece>[
  rust.GamePiece(id: 0, owner: rust.GamePlayer.first, x: 1, y: 1),
  rust.GamePiece(id: 1, owner: rust.GamePlayer.first, x: 3, y: 1),
  rust.GamePiece(id: 2, owner: rust.GamePlayer.first, x: 5, y: 1),
  rust.GamePiece(id: 3, owner: rust.GamePlayer.second, x: 1, y: 5),
  rust.GamePiece(id: 4, owner: rust.GamePlayer.second, x: 3, y: 5),
  rust.GamePiece(id: 5, owner: rust.GamePlayer.second, x: 5, y: 5),
];

const _expectedStartingPieces = <rust.GamePiece>[
  rust.GamePiece(id: 0, owner: rust.GamePlayer.first, x: 1, y: 0),
  rust.GamePiece(id: 1, owner: rust.GamePlayer.first, x: 3, y: 0),
  rust.GamePiece(id: 2, owner: rust.GamePlayer.second, x: 1, y: 4),
  rust.GamePiece(id: 3, owner: rust.GamePlayer.second, x: 3, y: 4),
];

void main() {
  test('simulates the exported app boards and replays their traces', () async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(_hostLibraryPath));
    addTearDown(RustLib.dispose);
    final directory = await Directory.systemTemp.createTemp('ttush-boards-');
    addTearDown(() => directory.delete(recursive: true));
    final export = await Process.run('dart', [
      'run',
      'tool/export_simulation_boards.dart',
      directory.path,
    ]);
    expect(export.exitCode, 0, reason: '${export.stderr}');
    const rulesEngine = FrbRulesEngine();

    for (final board in BuiltInBoard.values) {
      var match = rulesEngine.initialMatch(board.definition.rules);
      final process = await Process.run('engine/target/release/simulate', [
        '--games',
        '1',
        '--seed',
        '42',
        '--max-turns',
        '200',
        '--trace-game',
        '0',
        '--board-file',
        '${directory.path}/${board.id}.board',
      ]);
      expect(process.exitCode, 0, reason: '${process.stderr}');
      final report = <String, String>{
        for (final line in (process.stdout as String).trim().split('\n'))
          line.substring(0, line.indexOf('=')): line.substring(
            line.indexOf('=') + 1,
          ),
      };
      expect(report['board'], board.id);
      // Read the CLI's parsed state, not its input file or the exporter helper.
      expect(
        report['initial_tiles']!.split(';'),
        unorderedEquals([
          for (final tile in match.round.tiles)
            '${tile.x},${tile.y},${tile.kind.name}',
        ]),
      );
      expect(
        report['initial_pieces']!.split(';'),
        unorderedEquals([
          for (final piece in match.round.pieces)
            '${piece.id},${piece.owner.name},${piece.x},${piece.y}',
        ]),
      );
      final turns = int.parse(report['trace.turns']!);
      expect(turns, greaterThan(0));
      for (var index = 1; index <= turns; index++) {
        expect(
          report['trace.move.$index.player'],
          match.round.currentPlayer.name,
        );
        final move = rust.GameMove(
          pieceId: int.parse(report['trace.move.$index.piece']!),
          direction: rust.GameDirection.values.byName(
            report['trace.move.$index.direction']!,
          ),
        );
        expect(rulesEngine.legalMoves(match), contains(move));
        match = rulesEngine.applyMove(match, move).snapshot;
      }
      expect(match.phase, rust.GameMatchPhase.roundOver);
      expect(report['trace.winner'], match.roundWinner!.name);
      expect(report['trace.termination'], match.roundWinReason!.name);
      expect(report['turn_limits'], '0');
    }
  });

  test('preserves initial tile states through the host bridge', () async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(_hostLibraryPath));
    addTearDown(RustLib.dispose);

    expectInitialTileStates(const FrbRulesEngine());
  });

  test('loads the host bridge and returns the parity fixture', () async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(_hostLibraryPath));
    addTearDown(RustLib.dispose);

    await expectRulesEngineParity(const FrbRulesEngine());
  });

  test('returns the complete topology for every offered board', () async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(_hostLibraryPath));
    addTearDown(RustLib.dispose);
    const rulesEngine = FrbRulesEngine();

    expect(
      BuiltInBoard.values.map((board) => board.id),
      unorderedEquals(_expectedPlayableCellsById.keys),
    );
    for (final board in BuiltInBoard.values) {
      final match = rulesEngine.initialMatch(board.definition.rules);
      final expectedCells = _expectedPlayableCellsById[board.id]!;
      final expectedPieces = switch (board) {
        BuiltInBoard.large || BuiltInBoard.largeHoles => _largeStartingPieces,
        _ => _expectedStartingPieces,
      };
      final expectedTiles = [
        for (final (x, y) in expectedCells)
          rust.GameTile(
            x: x,
            y: y,
            kind:
                board == BuiltInBoard.largeHoles &&
                    y == 3 &&
                    [1, 3, 5].contains(x)
                ? rust.GameTileKind.hole
                : rust.GameTileKind.normal,
          ),
      ];
      expect(match.round.tiles, unorderedEquals(expectedTiles));
      expect(match.initialTiles, unorderedEquals(expectedTiles));

      expect(
        match.round.tiles.map((tile) => (tile.x, tile.y)),
        unorderedEquals(expectedCells),
        reason: '${board.id} topology returned by the host bridge',
      );
      expect(
        match.round.pieces,
        unorderedEquals(expectedPieces),
        reason: '${board.id} opening pieces returned by the host bridge',
      );
      expect(
        match.startingPieces,
        unorderedEquals(expectedPieces),
        reason: '${board.id} reset pieces returned by the host bridge',
      );
    }
  });

  test('keeps Expert turns for offered boards under the host limit', () async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(_hostLibraryPath));
    addTearDown(RustLib.dispose);
    const rulesEngine = FrbRulesEngine();

    for (final board in BuiltInBoard.values) {
      final snapshot = rulesEngine.initialMatch(board.definition.rules);
      GameMove? chosen;
      final stopwatch = Stopwatch()..start();

      await Future.wait([
        Future<void>.delayed(const Duration(milliseconds: 450)),
        rulesEngine
            .chooseBotMove(snapshot, BotPolicy.strategic)
            .then<void>((move) => chosen = move),
      ]);
      stopwatch.stop();

      stderr.writeln(
        'Expert ${board.id} host response: '
        '${stopwatch.elapsedMilliseconds} ms wall-clock wait, including '
        'the 450 ms pacing delay; this is not a CPU benchmark.',
      );
      expect(chosen, isNotNull);
      expect(rulesEngine.legalMoves(snapshot), contains(chosen));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    }
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
    await RustLib.init(externalLibrary: ExternalLibrary.open(_hostLibraryPath));
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
