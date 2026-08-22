import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/round/round_controller.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/api.dart';

void main() {
  group(RoundController, () {
    test('initializes from RulesEngine and exposes only its legal moves', () {
      const initialSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [
          GameTile(x: 0, y: 0, kind: GameTileKind.normal),
          GameTile(x: 0, y: 1, kind: GameTileKind.normal),
        ],
        pieces: [
          GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0),
          GamePiece(id: 2, owner: GamePlayer.second, x: 0, y: 1),
        ],
        snapshotHash: 'initial',
      );
      const legalMoves = [
        GameMove(pieceId: 0, direction: GameDirection.down),
      ];
      final controller = RoundController(
        _FakeRulesEngine(
          initialSnapshot: initialSnapshot,
          legalMoves: legalMoves,
        ),
      )..initialize();

      expect(controller.status, RoundStatus.ready);
      expect(controller.snapshot, initialSnapshot);
      expect(controller.legalMoves, legalMoves);
      expect(controller.error, isNull);
    });

    test(
      'rejects a snapshot with only one terminal field as a bridge error',
      () {
        const invalidSnapshot = GameSnapshot(
          currentPlayer: GamePlayer.first,
          tiles: [],
          pieces: [],
          winner: GamePlayer.first,
          snapshotHash: 'invalid-terminal-fields',
        );
        final controller = RoundController(
          _FakeRulesEngine(
            initialSnapshot: invalidSnapshot,
            legalMoves: const [],
          ),
        )..initialize();

        expect(controller.status, RoundStatus.initializationError);
        expect(controller.snapshot, isNull);
        expect(controller.error, isA<FormatException>());
      },
    );

    test('maps a selected legal move to its adjacent destination', () {
      const initialSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [
          GameTile(x: 0, y: 0, kind: GameTileKind.normal),
          GameTile(x: 0, y: 1, kind: GameTileKind.normal),
        ],
        pieces: [
          GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0),
          GamePiece(id: 2, owner: GamePlayer.second, x: 0, y: 1),
        ],
        snapshotHash: 'initial',
      );
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final controller =
          RoundController(
              _FakeRulesEngine(
                initialSnapshot: initialSnapshot,
                legalMoves: [move],
              ),
            )
            ..initialize()
            ..selectPiece(0);

      expect(controller.selectedPieceId, 0);
      expect(controller.moveForTappedDestination(0, 1), move);
      expect(controller.moveForTappedDestination(1, 0), isNull);

      controller.clearSelection();

      expect(controller.selectedPieceId, isNull);

      controller.selectPiece(2);

      expect(controller.selectedPieceId, isNull);
    });

    test('maps selected horizontal legal moves to distinct destinations', () {
      const initialSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [],
        pieces: [
          GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        ],
        snapshotHash: 'horizontal-moves',
      );
      const left = GameMove(pieceId: 0, direction: GameDirection.left);
      const right = GameMove(pieceId: 0, direction: GameDirection.right);
      final controller =
          RoundController(
              _FakeRulesEngine(
                initialSnapshot: initialSnapshot,
                legalMoves: const [left, right],
              ),
            )
            ..initialize()
            ..selectPiece(0);

      expect(controller.moveForTappedDestination(1, 2), left);
      expect(controller.moveForTappedDestination(3, 2), right);
    });

    test('restart initializes a controller without a current snapshot', () {
      const initialSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [],
        pieces: [],
        snapshotHash: 'restart-from-initializing',
      );
      final controller = RoundController(
        _FakeRulesEngine(
          initialSnapshot: initialSnapshot,
          legalMoves: const [],
        ),
      )..restart();

      expect(controller.status, RoundStatus.ready);
      expect(controller.snapshot, initialSnapshot);
    });

    test(
      'replaces the snapshot only with the result returned by applyMove',
      () {
        const initialSnapshot = GameSnapshot(
          currentPlayer: GamePlayer.first,
          tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.normal)],
          pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
          snapshotHash: 'initial',
        );
        const terminalSnapshot = GameSnapshot(
          currentPlayer: GamePlayer.second,
          tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.hole)],
          pieces: [],
          winner: GamePlayer.first,
          winReason: GameWinReason.knockout,
          snapshotHash: 'terminal',
        );
        const move = GameMove(pieceId: 0, direction: GameDirection.down);
        final engine = _FakeRulesEngine(
          initialSnapshot: initialSnapshot,
          legalMoves: [move],
          nextSnapshot: terminalSnapshot,
        );
        final controller = RoundController(engine)
          ..initialize()
          ..selectPiece(0)
          ..applyMove(move);

        expect(engine.appliedMoves, [move]);
        expect(controller.snapshot, terminalSnapshot);
        expect(controller.legalMoves, isEmpty);
        expect(controller.selectedPieceId, isNull);
      },
    );

    test('retries initialization after a bridge failure', () {
      const snapshot = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [],
        pieces: [],
        snapshotHash: 'ready-after-retry',
      );
      final controller = RoundController(
        _SequencedInitialStateRulesEngine([
          StateError('bridge unavailable'),
          snapshot,
        ]),
      )..initialize();

      expect(controller.status, RoundStatus.initializationError);
      expect(controller.snapshot, isNull);
      expect(controller.error, isA<StateError>());

      final retry = controller.retry;
      retry();

      expect(controller.status, RoundStatus.ready);
      expect(controller.snapshot, snapshot);
      expect(controller.error, isNull);
    });

    test('keeps a terminal snapshot visible when restart fails', () {
      const terminalSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.second,
        tiles: [],
        pieces: [],
        winner: GamePlayer.first,
        winReason: GameWinReason.immobilization,
        snapshotHash: 'terminal',
      );
      const restartedSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [],
        pieces: [],
        snapshotHash: 'restarted',
      );
      final controller =
          RoundController(
              _SequencedInitialStateRulesEngine([
                terminalSnapshot,
                StateError('bridge unavailable'),
                restartedSnapshot,
              ]),
            )
            ..initialize()
            ..restart();

      expect(controller.status, RoundStatus.ready);
      expect(controller.snapshot, terminalSnapshot);
      expect(controller.error, isA<StateError>());

      controller.retry();

      expect(controller.snapshot, restartedSnapshot);
      expect(controller.error, isNull);
    });

    test('keeps the valid snapshot when applying a move fails', () {
      const initialSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.normal)],
        pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
        snapshotHash: 'initial',
      );
      const terminalSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.second,
        tiles: [],
        pieces: [],
        winner: GamePlayer.first,
        winReason: GameWinReason.knockout,
        snapshotHash: 'terminal',
      );
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final controller =
          RoundController(
              _SequencedMoveRulesEngine(
                initialSnapshot: initialSnapshot,
                legalMoves: [move],
                moveResults: [
                  StateError('bridge unavailable'),
                  terminalSnapshot,
                ],
              ),
            )
            ..initialize()
            ..applyMove(move);

      expect(controller.snapshot, initialSnapshot);
      expect(controller.error, isA<StateError>());

      controller.retry();

      expect(controller.snapshot, terminalSnapshot);
      expect(controller.error, isNull);
    });

    test('keeps the snapshot atomic when legal move refresh fails', () {
      const initialSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [],
        pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
        snapshotHash: 'before-legal-move-refresh',
      );
      const nextSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.second,
        tiles: [],
        pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
        snapshotHash: 'after-legal-move-refresh',
      );
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final controller =
          RoundController(
              const _LegalMoveRefreshFailureEngine(
                initialSnapshot: initialSnapshot,
                nextSnapshot: nextSnapshot,
                move: move,
              ),
            )
            ..initialize()
            ..selectPiece(0)
            ..applyMove(move);

      expect(controller.snapshot, initialSnapshot);
      expect(controller.legalMoves, [move]);
      expect(controller.selectedPieceId, 0);
      expect(controller.error, isA<StateError>());
    });

    test('does not expose or apply moves from a terminal snapshot', () {
      const terminalSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.second,
        tiles: [],
        pieces: [],
        winner: GamePlayer.first,
        winReason: GameWinReason.knockout,
        snapshotHash: 'terminal',
      );
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final engine = _FakeRulesEngine(
        initialSnapshot: terminalSnapshot,
        legalMoves: [move],
        nextSnapshot: terminalSnapshot,
      );
      final controller = RoundController(engine)
        ..initialize()
        ..applyMove(move);

      expect(controller.legalMoves, isEmpty);
      expect(engine.appliedMoves, isEmpty);
    });
  });
}

final class _FakeRulesEngine implements RulesEngine {
  _FakeRulesEngine({
    required this.initialSnapshot,
    required this._legalMoves,
    this.nextSnapshot,
  });

  final GameSnapshot initialSnapshot;
  final List<GameMove> _legalMoves;
  final GameSnapshot? nextSnapshot;
  final List<GameMove> appliedMoves = [];

  @override
  GameSnapshot applyMove(GameSnapshot state, GameMove move) {
    appliedMoves.add(move);
    return nextSnapshot ??
        (throw UnsupportedError('applyMove is not configured for this test'));
  }

  @override
  GameSnapshot initialState() => initialSnapshot;

  @override
  List<GameMove> legalMoves(GameSnapshot state) => _legalMoves;
}

final class _SequencedInitialStateRulesEngine implements RulesEngine {
  _SequencedInitialStateRulesEngine(this._initialStateResults);

  final List<Object> _initialStateResults;

  @override
  GameSnapshot applyMove(GameSnapshot state, GameMove move) {
    throw UnsupportedError('applyMove is not used by this test');
  }

  @override
  GameSnapshot initialState() {
    final result = _initialStateResults.removeAt(0);
    if (result case final GameSnapshot snapshot) {
      return snapshot;
    }
    if (result case final Error error) {
      throw error;
    }
    throw StateError('initial state result must be a GameSnapshot or Error');
  }

  @override
  List<GameMove> legalMoves(GameSnapshot state) => const [];
}

final class _SequencedMoveRulesEngine implements RulesEngine {
  _SequencedMoveRulesEngine({
    required this.initialSnapshot,
    required this._legalMoves,
    required this._moveResults,
  });

  final GameSnapshot initialSnapshot;
  final List<GameMove> _legalMoves;
  final List<Object> _moveResults;

  @override
  GameSnapshot applyMove(GameSnapshot state, GameMove move) {
    final result = _moveResults.removeAt(0);
    if (result case final GameSnapshot snapshot) {
      return snapshot;
    }
    if (result case final Error error) {
      throw error;
    }
    throw StateError('move result must be a GameSnapshot or Error');
  }

  @override
  GameSnapshot initialState() => initialSnapshot;

  @override
  List<GameMove> legalMoves(GameSnapshot state) => _legalMoves;
}

final class _LegalMoveRefreshFailureEngine implements RulesEngine {
  const _LegalMoveRefreshFailureEngine({
    required this.initialSnapshot,
    required this.nextSnapshot,
    required this.move,
  });

  final GameSnapshot initialSnapshot;
  final GameSnapshot nextSnapshot;
  final GameMove move;

  @override
  GameSnapshot applyMove(GameSnapshot state, GameMove move) => nextSnapshot;

  @override
  GameSnapshot initialState() => initialSnapshot;

  @override
  List<GameMove> legalMoves(GameSnapshot state) {
    if (state == nextSnapshot) {
      throw StateError('legal move refresh failed');
    }
    return [move];
  }
}
