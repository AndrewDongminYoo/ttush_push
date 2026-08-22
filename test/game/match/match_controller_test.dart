import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/match/match_controller.dart';
import 'package:ttush_push/src/rust/api.dart';

import '../../support/match_fixtures.dart';

void main() {
  const board = [
    GameTile(x: 0, y: 0, kind: GameTileKind.normal),
    GameTile(x: 0, y: 1, kind: GameTileKind.normal),
    GameTile(x: 1, y: 0, kind: GameTileKind.normal),
  ];
  const onePiece = [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)];
  const centre = [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2)];

  GameSnapshot round({
    List<GamePiece> pieces = onePiece,
    GamePlayer current = GamePlayer.first,
    GamePlayer? winner,
    GameWinReason? reason,
    String hash = 'round',
  }) {
    return GameSnapshot(
      currentPlayer: current,
      tiles: board,
      pieces: pieces,
      winner: winner,
      winReason: reason,
      snapshotHash: hash,
    );
  }

  group(MatchController, () {
    test('initializes from RulesEngine and exposes only its legal moves', () {
      const moves = [GameMove(pieceId: 0, direction: GameDirection.down)];
      final controller = MatchController(
        FakeRulesEngine.playing(
          initial: matchOf(round()),
          legalMoves: moves,
        ),
      )..initialize();

      expect(controller.status, MatchStatus.ready);
      expect(controller.round, round());
      expect(controller.legalMoves, moves);
      expect(controller.isPlaying, isTrue);
      expect(controller.isRoundOver, isFalse);
      expect(controller.isMatchOver, isFalse);
    });

    test('rejects a snapshot with only one terminal field', () {
      final controller = MatchController(
        FakeRulesEngine(
          initial: [
            matchOf(round(), roundWinner: GamePlayer.first),
          ],
        ),
      )..initialize();

      expect(controller.status, MatchStatus.initializationError);
      expect(controller.error, isA<FormatException>());
      expect(controller.snapshot, isNull);
    });

    test('rejects a match winner without a round winner', () {
      final controller = MatchController(
        FakeRulesEngine(
          initial: [
            matchOf(
              round(),
              phase: GameMatchPhase.matchOver,
              firstWins: 2,
              matchWinner: GamePlayer.first,
            ),
          ],
        ),
      )..initialize();

      expect(controller.status, MatchStatus.initializationError);
      expect(controller.error, isA<FormatException>());
    });

    test('rejects a match winner who has not won two rounds', () {
      final controller = MatchController(
        FakeRulesEngine(
          initial: [
            matchOf(
              round(),
              phase: GameMatchPhase.matchOver,
              firstWins: 1,
              roundWinner: GamePlayer.first,
              roundWinReason: GameWinReason.knockout,
              matchWinner: GamePlayer.first,
            ),
          ],
        ),
      )..initialize();

      expect(controller.status, MatchStatus.initializationError);
      expect(controller.error, isA<FormatException>());
    });

    test('maps a selected legal move to its adjacent destination', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final controller = MatchController(
        FakeRulesEngine.playing(
          initial: matchOf(round()),
          legalMoves: const [move],
        ),
      )..initialize();

      expect(controller.moveForTappedDestination(0, 1), isNull);

      controller.selectPiece(0);

      expect(controller.selectedPieceId, 0);
      expect(controller.moveForTappedDestination(0, 1), move);
      expect(controller.moveForTappedDestination(1, 0), isNull);

      controller.clearSelection();

      expect(controller.moveForTappedDestination(0, 1), isNull);
    });

    test('maps selected horizontal legal moves to distinct destinations', () {
      const left = GameMove(pieceId: 0, direction: GameDirection.left);
      const right = GameMove(pieceId: 0, direction: GameDirection.right);
      const up = GameMove(pieceId: 0, direction: GameDirection.up);
      final controller =
          MatchController(
              FakeRulesEngine.playing(
                initial: matchOf(round(pieces: centre)),
                legalMoves: const [left, right, up],
              ),
            )
            ..initialize()
            ..selectPiece(0);

      expect(controller.moveForTappedDestination(1, 2), left);
      expect(controller.moveForTappedDestination(3, 2), right);
      expect(controller.moveForTappedDestination(2, 1), up);
    });

    test('ignores a selection that has no legal move', () {
      final controller =
          MatchController(
              FakeRulesEngine.playing(initial: matchOf(round())),
            )
            ..initialize()
            ..selectPiece(0);

      expect(controller.selectedPieceId, isNull);
    });

    test('replaces the snapshot only with what applyMove returned', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final next = matchOf(
        round(current: GamePlayer.second, hash: 'moved'),
        hash: 'moved-match',
      );
      final engine = FakeRulesEngine.playing(
        initial: matchOf(round()),
        next: next,
        legalMoves: const [move],
      );
      final controller = MatchController(engine)
        ..initialize()
        // A move absent from the cache never reaches the engine.
        ..applyMove(const GameMove(pieceId: 9, direction: GameDirection.up));

      expect(engine.appliedMoves, isEmpty);

      controller
        ..selectPiece(0)
        ..applyMove(move);

      expect(engine.appliedMoves, [move]);
      expect(controller.snapshot, next);
      expect(controller.selectedPieceId, isNull);
      expect(controller.legalMoves, isEmpty);
    });

    test('restart initializes a controller without a current snapshot', () {
      final controller = MatchController(
        FakeRulesEngine(initial: [StateError('bridge unavailable')]),
      )..restart();

      expect(controller.status, MatchStatus.initializationError);
    });

    test('retries initialization after a bridge failure', () {
      final ready = matchOf(round());
      final controller = MatchController(
        FakeRulesEngine(initial: [StateError('bridge unavailable'), ready]),
      )..initialize();

      expect(controller.status, MatchStatus.initializationError);

      controller.retry();

      expect(controller.status, MatchStatus.ready);
      expect(controller.snapshot, ready);
    });

    test('keeps the finished match visible when restart fails', () {
      final finished = matchOverMatch(round(), winner: GamePlayer.first);
      final controller =
          MatchController(
              FakeRulesEngine(
                initial: [finished, StateError('bridge unavailable')],
              ),
            )
            ..initialize()
            ..restart();

      expect(controller.status, MatchStatus.ready);
      expect(controller.snapshot, finished);
      expect(controller.error, isA<StateError>());
    });

    test('keeps the valid snapshot when applying a move fails', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final initial = matchOf(round());
      final next = matchOf(
        round(current: GamePlayer.second, hash: 'moved'),
        hash: 'moved-match',
      );
      final engine = FakeRulesEngine(
        initial: [initial],
        moveResults: [StateError('bridge unavailable'), next],
        legalMovesFor: (state) => state.snapshotHash == initial.snapshotHash
            ? const [move]
            : const [],
      );
      final controller = MatchController(engine)
        ..initialize()
        ..selectPiece(0)
        ..applyMove(move);

      expect(controller.snapshot, initial);
      expect(controller.error, isA<StateError>());
      expect(controller.selectedPieceId, 0);

      controller.retry();

      expect(controller.snapshot, next);
      expect(controller.error, isNull);
    });

    test('keeps the snapshot atomic when the legal move refresh fails', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final initial = matchOf(round());
      final engine = FakeRulesEngine(
        initial: [initial],
        moveResults: [matchOf(round(hash: 'moved'), hash: 'moved-match')],
        legalMovesFor: (state) {
          if (state.snapshotHash == initial.snapshotHash) {
            return const [move];
          }
          throw StateError('bridge unavailable');
        },
      );
      final controller = MatchController(engine)
        ..initialize()
        ..selectPiece(0)
        ..applyMove(move);

      // The snapshot and its legal moves stay consistent with each other.
      expect(controller.snapshot, initial);
      expect(controller.legalMoves, [move]);
      expect(controller.error, isA<StateError>());
    });

    test('refuses moves once the round is over', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final engine = FakeRulesEngine(
        initial: [
          roundOverMatch(round(), winner: GamePlayer.first),
        ],
        legalMovesFor: (_) => const [move],
      );
      final controller = MatchController(engine)..initialize();

      expect(controller.isRoundOver, isTrue);
      // Legal moves are not even fetched for a phase that cannot move.
      expect(controller.legalMoves, isEmpty);

      controller
        ..selectPiece(0)
        ..applyMove(move);

      expect(engine.appliedMoves, isEmpty);
      expect(controller.selectedPieceId, isNull);
    });

    test('advances only from a finished round', () {
      final roundOver = roundOverMatch(round(), winner: GamePlayer.first);
      final nextRound = matchOf(
        round(current: GamePlayer.second, hash: 'next'),
        firstWins: 1,
        hash: 'next-match',
      );
      final engine = FakeRulesEngine(
        initial: [roundOver],
        advanceResults: [nextRound],
      );
      final controller = MatchController(engine)..advanceRound();

      // Nothing to advance before initialization.
      expect(engine.advanceCount, 0);

      controller
        ..initialize()
        ..advanceRound();

      expect(engine.advanceCount, 1);
      expect(controller.snapshot, nextRound);
      expect(controller.isPlaying, isTrue);

      controller.advanceRound();

      expect(engine.advanceCount, 1);
    });

    test('refuses to advance a won match', () {
      final engine = FakeRulesEngine(
        initial: [matchOverMatch(round(), winner: GamePlayer.first)],
      );
      final controller = MatchController(engine)
        ..initialize()
        ..advanceRound();

      expect(engine.advanceCount, 0);
      expect(controller.isMatchOver, isTrue);
    });

    test('keeps the finished round visible when advancing fails', () {
      final roundOver = roundOverMatch(round(), winner: GamePlayer.first);
      final nextRound = matchOf(round(hash: 'next'), hash: 'next-match');
      final engine = FakeRulesEngine(
        initial: [roundOver],
        advanceResults: [StateError('bridge unavailable'), nextRound],
      );
      final controller = MatchController(engine)
        ..initialize()
        ..advanceRound();

      expect(controller.snapshot, roundOver);
      expect(controller.error, isA<StateError>());

      controller.retry();

      expect(controller.snapshot, nextRound);
      expect(controller.error, isNull);
    });
  });
}
