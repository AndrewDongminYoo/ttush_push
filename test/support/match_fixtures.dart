import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/api.dart';

/// Builds a match around a round, defaulting to a match in progress.
///
/// The hash is arbitrary here: these snapshots never cross the bridge, so
/// nothing verifies it. What the fakes stand in for is the engine's answers,
/// not its tamper checks, which `engine/tests/bridge_api.rs` covers.
MatchSnapshot matchOf(
  GameSnapshot round, {
  GameMatchPhase phase = GameMatchPhase.playing,
  int firstWins = 0,
  int secondWins = 0,
  GamePlayer? roundWinner,
  GameWinReason? roundWinReason,
  GamePlayer? matchWinner,
  List<GamePiece>? startingPieces,
  String hash = 'match',
}) {
  return MatchSnapshot(
    round: round,
    startingPieces: startingPieces ?? round.pieces,
    firstPlayerWins: firstWins,
    secondPlayerWins: secondWins,
    phase: phase,
    roundWinner: roundWinner,
    roundWinReason: roundWinReason,
    matchWinner: matchWinner,
    snapshotHash: hash,
  );
}

/// A match whose round has ended, with the score it implies.
MatchSnapshot roundOverMatch(
  GameSnapshot round, {
  required GamePlayer winner,
  GameWinReason reason = GameWinReason.knockout,
  int firstWins = 1,
  int secondWins = 0,
  String hash = 'round-over',
}) {
  return matchOf(
    round,
    phase: GameMatchPhase.roundOver,
    firstWins: firstWins,
    secondWins: secondWins,
    roundWinner: winner,
    roundWinReason: reason,
    hash: hash,
  );
}

/// A match that has been won.
MatchSnapshot matchOverMatch(
  GameSnapshot round, {
  required GamePlayer winner,
  GameWinReason reason = GameWinReason.knockout,
  String hash = 'match-over',
}) {
  return matchOf(
    round,
    phase: GameMatchPhase.matchOver,
    firstWins: winner == GamePlayer.first ? 2 : 0,
    secondWins: winner == GamePlayer.second ? 2 : 0,
    roundWinner: winner,
    roundWinReason: reason,
    matchWinner: winner,
    hash: hash,
  );
}

const testMoveResolution = MoveResolution(
  actionKind: MoveActionKind.normal,
  mover: PieceTravel(pieceId: 0, fromX: 0, fromY: 0, toX: 0, toY: 1),
  tileTransition: TileTransition(
    x: 0,
    y: 0,
    from: GameTileKind.normal,
    to: GameTileKind.damaged,
  ),
);

MoveResult moveResultOf({
  required MatchSnapshot next,
  required MoveResolution resolution,
}) {
  return MoveResult(snapshot: next, resolution: resolution);
}

/// One fake for every case the tests need.
///
/// Each list is consumed in order; an entry that is an [Error] is thrown
/// instead of returned, which is how a bridge failure is expressed. A list
/// with a single entry is reused, so the common case needs no repetition.
final class FakeRulesEngine implements RulesEngine {
  FakeRulesEngine({
    required List<Object> initial,
    List<Object> moveResults = const [],
    List<Object> advanceResults = const [],
    this._legalMovesFor,
    this._botMove,
  }) : _initial = List.of(initial),
       _moveResults = List.of(moveResults),
       _advanceResults = List.of(advanceResults);

  /// The common shape: one starting match, one set of legal moves, and each
  /// move returning the same next match.
  factory FakeRulesEngine.playing({
    required MatchSnapshot initial,
    MatchSnapshot? next,
    List<GameMove> legalMoves = const [],
    MoveResolution resolution = testMoveResolution,
  }) {
    return FakeRulesEngine(
      initial: [initial],
      moveResults: next == null
          ? const []
          : [moveResultOf(next: next, resolution: resolution)],
      legalMovesFor: (state) =>
          state.snapshotHash == initial.snapshotHash ? legalMoves : const [],
    );
  }

  final List<Object> _initial;
  final List<Object> _moveResults;
  final List<Object> _advanceResults;
  final List<GameMove> Function(MatchSnapshot state)? _legalMovesFor;
  final GameMove? Function(MatchSnapshot state, BotPolicy policy)? _botMove;

  final List<GameMove> appliedMoves = [];
  final List<BotPolicy> botRequests = [];
  final List<GameBoardDefinition> initialDefinitions = [];
  int initialCount = 0;
  int advanceCount = 0;

  @override
  MatchSnapshot initialMatch(GameBoardDefinition boardDefinition) {
    initialCount++;
    initialDefinitions.add(boardDefinition);
    return _withFixtureTiles(_take(_initial, 'initial match'));
  }

  @override
  List<GameMove> legalMoves(MatchSnapshot state) =>
      _legalMovesFor?.call(state) ?? const [];

  @override
  MoveResult applyMove(MatchSnapshot state, GameMove move) {
    appliedMoves.add(move);
    final result = _takeMoveResult(_moveResults, 'move result');
    return MoveResult(
      snapshot: _withFixtureTiles(result.snapshot),
      resolution: result.resolution,
    );
  }

  @override
  MatchSnapshot advanceRound(MatchSnapshot state) {
    advanceCount++;
    return _withFixtureTiles(_take(_advanceResults, 'advance result'));
  }

  @override
  GameMove? chooseBotMove(MatchSnapshot state, BotPolicy policy) {
    botRequests.add(policy);
    return _botMove?.call(state, policy);
  }

  MatchSnapshot _take(List<Object> results, String what) {
    if (results.isEmpty) {
      throw StateError('no $what was configured');
    }
    final result = results.length == 1 ? results.first : results.removeAt(0);
    if (result case final MatchSnapshot snapshot) {
      return snapshot;
    }
    if (result case final Error error) {
      throw error;
    }
    throw StateError('$what must be a MatchSnapshot or an Error');
  }

  MoveResult _takeMoveResult(List<Object> results, String what) {
    if (results.isEmpty) {
      throw StateError('no $what was configured');
    }
    final result = results.length == 1 ? results.first : results.removeAt(0);
    if (result case final MoveResult moveResult) {
      return moveResult;
    }
    if (result case final Error error) {
      throw error;
    }
    throw StateError('$what must be a MoveResult or an Error');
  }
}

/// Production snapshots name every tile, including holes.
/// Some legacy widget fixtures omit terrain they do not inspect, so make that
/// absence explicit before the board receives the fake engine's answer.
MatchSnapshot _withFixtureTiles(MatchSnapshot snapshot) {
  if (snapshot.round.tiles.isNotEmpty) {
    return snapshot;
  }
  final round = snapshot.round;
  final tiles = [
    for (var x = 0; x < 5; x++)
      for (var y = 0; y < 5; y++) GameTile(x: x, y: y, kind: GameTileKind.hole),
  ];
  return MatchSnapshot(
    round: GameSnapshot(
      currentPlayer: round.currentPlayer,
      tiles: tiles,
      pieces: round.pieces,
      counterPush: round.counterPush,
      winner: round.winner,
      winReason: round.winReason,
      snapshotHash: round.snapshotHash,
    ),
    startingPieces: snapshot.startingPieces,
    firstPlayerWins: snapshot.firstPlayerWins,
    secondPlayerWins: snapshot.secondPlayerWins,
    phase: snapshot.phase,
    roundWinner: snapshot.roundWinner,
    roundWinReason: snapshot.roundWinReason,
    matchWinner: snapshot.matchWinner,
    snapshotHash: snapshot.snapshotHash,
  );
}
