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

    test('rejects result fields that contradict the phase', () {
      MatchController controllerFor(MatchSnapshot snapshot) {
        return MatchController(FakeRulesEngine(initial: [snapshot]))
          ..initialize();
      }

      // A finished round with nothing to say about who took it would reach
      // the result overlay and crash on the missing winner.
      expect(
        controllerFor(matchOf(round(), phase: GameMatchPhase.roundOver)).error,
        isA<FormatException>(),
      );
      expect(
        controllerFor(
          matchOf(round(), phase: GameMatchPhase.matchOver, firstWins: 2),
        ).error,
        isA<FormatException>(),
      );
      // A match that is over must name its winner.
      expect(
        controllerFor(
          matchOf(
            round(),
            phase: GameMatchPhase.matchOver,
            firstWins: 2,
            roundWinner: GamePlayer.first,
            roundWinReason: GameWinReason.knockout,
          ),
        ).error,
        isA<FormatException>(),
      );
      // A round still being played has no result to carry.
      expect(
        controllerFor(
          matchOf(
            round(),
            roundWinner: GamePlayer.first,
            roundWinReason: GameWinReason.knockout,
          ),
        ).error,
        isA<FormatException>(),
      );
      // Nor can a round result claim the match while a round is unfinished.
      expect(
        controllerFor(
          matchOf(
            round(),
            phase: GameMatchPhase.roundOver,
            firstWins: 1,
            roundWinner: GamePlayer.first,
            roundWinReason: GameWinReason.knockout,
            matchWinner: GamePlayer.first,
          ),
        ).error,
        isA<FormatException>(),
      );
    });

    test('cycles the opponent and reports whose turn a bot has', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final controller = MatchController(
        FakeRulesEngine.playing(
          initial: matchOf(round(current: GamePlayer.second)),
          legalMoves: const [move],
        ),
      )..initialize();

      expect(controller.opponent, Opponent.human);
      expect(controller.isBotTurn, isFalse);

      controller.cycleOpponent();

      expect(controller.opponent, Opponent.random);
      // It is the second seat's turn, and a policy now sits in it.
      expect(controller.isBotTurn, isTrue);

      controller
        ..cycleOpponent()
        ..cycleOpponent();

      expect(controller.opponent, Opponent.minimax);

      controller.cycleOpponent();

      expect(controller.opponent, Opponent.human);
      expect(controller.isBotTurn, isFalse);
    });

    test('changes the opponent before the first move', () {
      final controller =
          MatchController(
              FakeRulesEngine.playing(initial: matchOf(round())),
            )
            ..initialize()
            ..selectOpponent(Opponent.greedy);

      expect(controller.opponent, Opponent.greedy);
      expect(controller.canChangeOpponent, isTrue);
    });

    test('locks opponent selection after the first applied move', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final initial = matchOf(round(), hash: 'initial-match');
      final afterMove = matchOf(
        round(current: GamePlayer.second, hash: 'after-move-round'),
        hash: 'after-move-match',
      );
      final freshMatch = matchOf(
        round(hash: 'fresh-round'),
        hash: 'fresh-match',
      );
      final controller =
          MatchController(
              FakeRulesEngine(
                initial: [initial, freshMatch],
                moveResults: [
                  moveResultOf(next: afterMove, resolution: testMoveResolution),
                ],
                legalMovesFor: (state) => state.snapshotHash == 'initial-match'
                    ? const [move]
                    : const [],
              ),
            )
            ..initialize()
            ..selectOpponent(Opponent.greedy)
            ..selectPiece(move.pieceId);

      expect(controller.prepareHumanMove(move), isTrue);
      controller.commitPendingMove();

      expect(controller.canChangeOpponent, isFalse);
      controller.selectOpponent(Opponent.human);
      expect(controller.opponent, Opponent.greedy);

      controller.restart();

      expect(controller.canChangeOpponent, isTrue);
      controller.selectOpponent(Opponent.human);
      expect(controller.opponent, Opponent.human);
    });

    test(
      'does not read a bot turn from the first seat or a finished round',
      () {
        final playing = MatchController(
          FakeRulesEngine.playing(initial: matchOf(round())),
        )..initialize();
        final finished = MatchController(
          FakeRulesEngine(
            initial: [roundOverMatch(round(), winner: GamePlayer.first)],
          ),
        )..initialize();

        playing.cycleOpponent();
        finished.cycleOpponent();

        // The person always plays first, so their turn is never the bot's.
        expect(playing.isBotTurn, isFalse);
        // And a phase that refuses moves refuses the bot's too.
        expect(finished.isBotTurn, isFalse);
      },
    );

    test('plays the move the engine chose for the policy', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final next = matchOf(round(hash: 'after-bot'), hash: 'after-bot-match');
      final engine = FakeRulesEngine(
        initial: [matchOf(round(current: GamePlayer.second))],
        moveResults: [
          moveResultOf(next: next, resolution: testMoveResolution),
        ],
        legalMovesFor: (_) => const [move],
        botMove: (_, _) => move,
      );
      final controller = MatchController(engine)
        ..initialize()
        ..cycleOpponent()
        ..cycleOpponent()
        ..playBotMove();

      expect(engine.botRequests, [BotPolicy.greedy]);
      expect(engine.appliedMoves, [move]);
      expect(controller.snapshot, next);
    });

    test("refuses a move applied on the bot's behalf", () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final engine = FakeRulesEngine(
        initial: [matchOf(round(current: GamePlayer.second))],
        moveResults: [
          moveResultOf(
            next: matchOf(round(hash: 'unused'), hash: 'unused-match'),
            resolution: testMoveResolution,
          ),
        ],
        legalMovesFor: (_) => const [move],
        botMove: (_, _) => move,
      );
      final controller = MatchController(engine)
        ..initialize()
        ..cycleOpponent()
        ..selectPiece(move.pieceId)
        ..applyMove(move);

      // The move is the seat's own legal move, so only turn ownership can
      // refuse it.
      expect(controller.selectedPieceId, isNull);
      expect(engine.appliedMoves, isEmpty);
      expect(controller.error, isNull);
    });

    test("ignores a bot move outside the bot's turn", () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final engine = FakeRulesEngine(
        initial: [matchOf(round())],
        legalMovesFor: (_) => const [move],
        botMove: (_, _) => move,
      );
      final controller = MatchController(engine)
        ..initialize()
        // No policy in the seat yet.
        ..playBotMove()
        // A policy, but the person is to move.
        ..cycleOpponent()
        ..playBotMove();

      expect(engine.botRequests, isEmpty);
      expect(engine.appliedMoves, isEmpty);
      expect(controller.error, isNull);
    });

    test('treats a policy with no move on a playing round as a fault', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final engine = FakeRulesEngine(
        initial: [matchOf(round(current: GamePlayer.second))],
        legalMovesFor: (_) => const [move],
        botMove: (_, _) => null,
      );
      final controller = MatchController(engine)
        ..initialize()
        ..cycleOpponent()
        ..playBotMove();

      // The phase says the round is being played, so the engine offering no
      // move is a disagreement rather than a state.
      expect(controller.error, isA<FormatException>());
      expect(engine.appliedMoves, isEmpty);
    });

    test('keeps the board and retries when a bot move fails', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final initial = matchOf(round(current: GamePlayer.second));
      final next = matchOf(round(hash: 'recovered'), hash: 'recovered-match');
      final engine = FakeRulesEngine(
        initial: [initial],
        moveResults: [
          StateError('bridge unavailable'),
          moveResultOf(next: next, resolution: testMoveResolution),
        ],
        legalMovesFor: (_) => const [move],
        botMove: (_, _) => move,
      );
      final controller = MatchController(engine)
        ..initialize()
        ..cycleOpponent()
        ..playBotMove();

      expect(controller.snapshot, initial);
      expect(controller.error, isA<StateError>());

      controller.retry();

      expect(controller.snapshot, next);
      expect(controller.error, isNull);
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

    test('prepares a move without publishing its snapshot', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      const nextMove = GameMove(pieceId: 0, direction: GameDirection.up);
      final initial = matchOf(round(), hash: 'initial-match');
      final next = matchOf(
        round(current: GamePlayer.second, hash: 'next-round'),
        hash: 'next-match',
      );
      final engine = FakeRulesEngine(
        initial: [initial],
        moveResults: [
          moveResultOf(next: next, resolution: testMoveResolution),
        ],
        legalMovesFor: (state) => switch (state.snapshotHash) {
          'initial-match' => const [move],
          'next-match' => const [nextMove],
          _ => const [],
        },
      );
      final controller = MatchController(engine)
        ..initialize()
        ..selectPiece(move.pieceId);

      expect(controller.prepareHumanMove(move), isTrue);
      expect(controller.snapshot, initial);
      expect(controller.pendingResolution, testMoveResolution);
      expect(controller.legalMoves, const [move]);

      controller.commitPendingMove();

      expect(controller.snapshot, next);
      expect(controller.legalMoves, const [nextMove]);
      expect(controller.pendingResolution, isNull);
    });

    test('prepares a bot move without publishing its snapshot', () {
      const move = GameMove(pieceId: 2, direction: GameDirection.up);
      final initial = matchOf(
        round(current: GamePlayer.second),
        hash: 'bot-initial-match',
      );
      final next = matchOf(
        round(hash: 'bot-next-round'),
        hash: 'bot-next-match',
      );
      final engine = FakeRulesEngine(
        initial: [initial],
        moveResults: [
          moveResultOf(next: next, resolution: testMoveResolution),
        ],
        legalMovesFor: (_) => const [move],
        botMove: (_, _) => move,
      );
      final controller = MatchController(engine)
        ..initialize()
        ..cycleOpponent()
        ..cycleOpponent();

      expect(controller.prepareBotMove(), isTrue);
      expect(controller.snapshot, initial);
      expect(controller.pendingResolution, testMoveResolution);
      expect(engine.appliedMoves, [move]);

      controller.commitPendingMove();

      expect(controller.snapshot, next);
      expect(controller.pendingResolution, isNull);
    });

    test('rejects controls while a move is pending', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final initial = matchOf(round(), hash: 'initial-match');
      final next = matchOf(
        round(current: GamePlayer.second, hash: 'next-round'),
        hash: 'next-match',
      );
      final engine = FakeRulesEngine(
        initial: [initial],
        moveResults: [
          moveResultOf(next: next, resolution: testMoveResolution),
        ],
        legalMovesFor: (_) => const [move],
      );
      final controller = MatchController(engine)
        ..initialize()
        ..selectPiece(move.pieceId);

      expect(controller.prepareHumanMove(move), isTrue);

      controller
        ..selectPiece(99)
        ..clearSelection()
        ..cycleOpponent()
        ..restart()
        ..advanceRound();

      expect(controller.selectedPieceId, move.pieceId);
      expect(controller.opponent, Opponent.human);
      expect(engine.initialCount, 1);
      expect(engine.advanceCount, 0);
      expect(controller.prepareHumanMove(move), isFalse);
      expect(controller.prepareBotMove(), isFalse);
    });

    test('retries a failed preparation without changing the visible match', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final initial = matchOf(round(), hash: 'initial-match');
      final next = matchOf(
        round(current: GamePlayer.second, hash: 'next-round'),
        hash: 'next-match',
      );
      final engine = FakeRulesEngine(
        initial: [initial],
        moveResults: [
          StateError('bridge unavailable'),
          moveResultOf(next: next, resolution: testMoveResolution),
        ],
        legalMovesFor: (state) =>
            state.snapshotHash == 'initial-match' ? const [move] : const [],
      );
      final controller = MatchController(engine)
        ..initialize()
        ..selectPiece(move.pieceId);

      expect(controller.prepareHumanMove(move), isFalse);
      expect(controller.snapshot, initial);
      expect(controller.pendingResolution, isNull);
      expect(controller.selectedPieceId, move.pieceId);
      expect(controller.error, isA<StateError>());

      expect(controller.retry(), isTrue);
      expect(controller.snapshot, initial);
      expect(controller.pendingResolution, testMoveResolution);
      expect(controller.error, isNull);

      controller.commitPendingMove();

      expect(controller.snapshot, next);
    });

    test('retries a failed pending legal-move refresh before committing', () {
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      const nextMove = GameMove(pieceId: 0, direction: GameDirection.up);
      var nextLegalMoveReads = 0;
      final initial = matchOf(round(), hash: 'initial-match');
      final next = matchOf(
        round(current: GamePlayer.second, hash: 'next-round'),
        hash: 'next-match',
      );
      final engine = FakeRulesEngine(
        initial: [initial],
        moveResults: [
          moveResultOf(next: next, resolution: testMoveResolution),
        ],
        legalMovesFor: (state) => switch (state.snapshotHash) {
          'initial-match' => const [move],
          'next-match' when nextLegalMoveReads++ == 0 => throw StateError(
            'bridge unavailable',
          ),
          'next-match' => const [nextMove],
          _ => const [],
        },
      );
      final controller = MatchController(engine)
        ..initialize()
        ..selectPiece(move.pieceId);

      expect(controller.prepareHumanMove(move), isFalse);
      expect(controller.snapshot, initial);
      expect(controller.legalMoves, const [move]);
      expect(controller.pendingResolution, isNull);
      expect(controller.error, isA<StateError>());

      expect(controller.retry(), isTrue);
      expect(controller.snapshot, initial);
      expect(controller.legalMoves, const [move]);
      expect(controller.pendingResolution, testMoveResolution);

      controller.commitPendingMove();

      expect(controller.snapshot, next);
      expect(controller.legalMoves, const [nextMove]);
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
        moveResults: [
          StateError('bridge unavailable'),
          moveResultOf(next: next, resolution: testMoveResolution),
        ],
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
        moveResults: [
          moveResultOf(
            next: matchOf(round(hash: 'moved'), hash: 'moved-match'),
            resolution: testMoveResolution,
          ),
        ],
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
