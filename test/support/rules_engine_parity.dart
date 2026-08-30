import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/board/board_definition.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/api.dart';

void expectRulesEngineParity(RulesEngine rulesEngine) {
  var match = rulesEngine.initialMatch(baselineBoardDefinition.rules);
  const fixtureMoves = [
    GameMove(pieceId: 0, direction: GameDirection.down),
    GameMove(pieceId: 2, direction: GameDirection.up),
    GameMove(pieceId: 0, direction: GameDirection.down),
    GameMove(pieceId: 2, direction: GameDirection.up),
  ];

  for (final (index, move) in fixtureMoves.indexed) {
    expect(rulesEngine.legalMoves(match), contains(move));
    final result = rulesEngine.applyMove(match, move);
    if (index == 0) {
      expect(result.resolution.actionKind, MoveActionKind.normal);
      expect(result.resolution.mover.pieceId, move.pieceId);
      expect(result.resolution.mover.fromX, 1);
      expect(result.resolution.mover.fromY, 0);
      expect(result.resolution.mover.toX, 1);
      expect(result.resolution.mover.toY, 1);
      expect(result.resolution.displaced, isNull);
      expect(result.resolution.tileTransition.from, GameTileKind.normal);
      expect(result.resolution.tileTransition.to, GameTileKind.damaged);
    }
    if (index == fixtureMoves.length - 1) {
      expect(result.resolution.actionKind, MoveActionKind.push);
      expect(result.resolution.mover.pieceId, move.pieceId);
      expect(result.resolution.displaced?.pieceId, 0);
      expect(result.resolution.displaced?.fromX, 1);
      expect(result.resolution.displaced?.fromY, 2);
      expect(result.resolution.displaced?.toX, 1);
      expect(result.resolution.displaced?.toY, 1);
      expect(result.resolution.displaced?.exitDirection, isNull);
    }
    match = result.snapshot;
  }

  // The round hash is the parity evidence: both native runtimes must derive
  // the same canonical state from the same moves.
  expect(match.round.snapshotHash, '7044880ea390e9a8');
  expect(match.phase, GameMatchPhase.playing);
  expect(
    rulesEngine.legalMoves(match),
    isNot(
      contains(
        const GameMove(pieceId: 0, direction: GameDirection.down),
      ),
    ),
  );

  // The bot seeds itself from the round's own hash, so an agreed hash ought
  // to imply an agreed move. That is an argument, not a measurement: the seed
  // still has to survive both runtimes' integer width and the policies still
  // have to walk the position the same way. These are the moves
  // `value_api_pins_the_parity_fixture_bot_moves` fixes on the host.
  const expectedByPolicy = {
    BotPolicy.random: GameMove(pieceId: 1, direction: GameDirection.down),
    BotPolicy.greedy: GameMove(pieceId: 1, direction: GameDirection.down),
    BotPolicy.minimax: GameMove(pieceId: 0, direction: GameDirection.right),
  };
  for (final entry in expectedByPolicy.entries) {
    expect(
      rulesEngine.chooseBotMove(match, entry.key),
      entry.value,
      reason: '${entry.key} chose a different move on this runtime',
    );
  }
}

const irregularBoardRules = GameBoardDefinition(
  playableCells: [
    GameBoardCell(x: 4, y: 7),
    GameBoardCell(x: 5, y: 7),
    GameBoardCell(x: 5, y: 8),
  ],
  startingPieces: [
    GamePiece(id: 7, owner: GamePlayer.first, x: 4, y: 7),
    GamePiece(id: 9, owner: GamePlayer.second, x: 5, y: 8),
  ],
);

void expectIrregularBoardDefinition(RulesEngine rulesEngine) {
  final match = rulesEngine.initialMatch(irregularBoardRules);

  expect(
    match.round.tiles.map((tile) => (tile.x, tile.y)),
    unorderedEquals(const [(4, 7), (5, 7), (5, 8)]),
  );
  expect(
    match.startingPieces,
    const [
      GamePiece(id: 7, owner: GamePlayer.first, x: 4, y: 7),
      GamePiece(id: 9, owner: GamePlayer.second, x: 5, y: 8),
    ],
  );
}
