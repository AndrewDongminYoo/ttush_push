import 'package:ttush_push/game/board/board_definition.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

enum MatchStatus { initializing, ready, initializationError }

/// Who plays the second seat.
///
/// The first seat is always the person; this choice assigns only the second
/// seat.
enum Opponent {
  human,
  random,
  greedy,
  minimax;

  Opponent get next => Opponent.values[(index + 1) % Opponent.values.length];

  /// The engine policy this stands for, or null when a person plays.
  rust.BotPolicy? get policy => switch (this) {
    Opponent.human => null,
    Opponent.random => rust.BotPolicy.random,
    Opponent.greedy => rust.BotPolicy.greedy,
    Opponent.minimax => rust.BotPolicy.minimax,
  };
}

/// Holds the match a screen is showing, and nothing about how it is drawn.
///
/// It owns selection, the legal-move cache, and recoverable bridge errors. It
/// counts nothing: the score, the phase, and who starts the next round all
/// arrive from Rust inside the snapshot.
final class MatchController {
  MatchController(this._engine, {rust.GameBoardDefinition? boardDefinition})
    : _boardDefinition = boardDefinition ?? baselineBoardDefinition.rules;

  final RulesEngine _engine;
  final rust.GameBoardDefinition _boardDefinition;
  MatchSnapshot? _snapshot;
  List<GameMove> _legalMoves = const [];
  int? _selectedPieceId;
  Object? _error;
  void Function()? _retryAction;
  MatchStatus _status = MatchStatus.initializing;
  Opponent _opponent = Opponent.human;
  _PendingMove? _pendingMove;
  bool _hasAppliedMove = false;

  MatchSnapshot? get snapshot => _snapshot;
  GameSnapshot? get round => _snapshot?.round;
  List<GameMove> get legalMoves => _legalMoves;
  int? get selectedPieceId => _selectedPieceId;
  Object? get error => _error;
  MatchStatus get status => _status;
  rust.MoveResolution? get pendingResolution => _pendingMove?.result.resolution;
  bool get hasPendingMove => _pendingMove != null;

  /// Whether the current phase accepts a move.
  bool get isPlaying => _snapshot?.phase == rust.GameMatchPhase.playing;

  /// Whether a finished round is waiting to be advanced past.
  bool get isRoundOver => _snapshot?.phase == rust.GameMatchPhase.roundOver;

  bool get isMatchOver => _snapshot?.phase == rust.GameMatchPhase.matchOver;

  Opponent get opponent => _opponent;

  /// Whether the second seat can still be selected for this fresh match.
  bool get canChangeOpponent => !hasPendingMove && !_hasAppliedMove;

  /// Whether the second seat is waiting on a policy rather than a person.
  ///
  /// A policy carries nothing between moves; selection itself remains locked
  /// after the match's first committed move.
  bool get isBotTurn =>
      !hasPendingMove &&
      _opponent.policy != null &&
      isPlaying &&
      _snapshot?.round.currentPlayer == rust.GamePlayer.second;

  /// Hands the second seat to the next opponent while selection is unlocked.
  ///
  /// A standing error is dropped with it: the action waiting behind Retry
  /// belonged to the seat as it was, and a bot-move retry left in place after
  /// the seat turns human does nothing at all, stranding the banner. A fault
  /// that is still there resurfaces on the next move.
  void cycleOpponent() {
    selectOpponent(_opponent.next);
  }

  /// Assigns the second seat before this match's first committed move.
  void selectOpponent(Opponent opponent) {
    if (!canChangeOpponent) {
      return;
    }
    _opponent = opponent;
    _selectedPieceId = null;
    _error = null;
    _retryAction = null;
  }

  /// Plays the move the policy chose. Does nothing when it is not its turn.
  void playBotMove() {
    if (prepareBotMove()) {
      commitPendingMove();
    } else if (_error != null) {
      _retryAction = playBotMove;
    }
  }

  /// Prepares a policy move without replacing the match the screen renders.
  ///
  /// The page owns the short replay between preparation and commit, while the
  /// controller keeps the resulting snapshot and legal moves together.
  bool prepareBotMove() {
    final snapshot = _snapshot;
    final policy = _opponent.policy;
    if (snapshot == null || policy == null || !isBotTurn || hasPendingMove) {
      return false;
    }

    return _prepareMove(
      () {
        final move = _engine.chooseBotMove(snapshot, policy);
        if (move == null) {
          // The engine says the round offers nothing, which the phase should
          // already have said. Treat the disagreement as a bridge fault.
          throw const FormatException(
            'a playing round must offer the policy a move',
          );
        }
        return _engine.applyMove(snapshot, move);
      },
      onFailure: prepareBotMove,
    );
  }

  void initialize() {
    _snapshot = null;
    _legalMoves = const [];
    _selectedPieceId = null;
    _error = null;
    _status = MatchStatus.initializing;
    _pendingMove = null;
    _hasAppliedMove = false;

    try {
      _adopt(_engine.initialMatch(_boardDefinition));
      _status = MatchStatus.ready;
      _retryAction = null;
    } on Object catch (error) {
      _snapshot = null;
      _legalMoves = const [];
      _selectedPieceId = null;
      _error = error;
      _retryAction = initialize;
      _status = MatchStatus.initializationError;
    }
  }

  bool retry() {
    final retryAction = _retryAction;
    if (retryAction == null) {
      return false;
    }
    retryAction();
    return true;
  }

  /// Starts a fresh match, keeping the current one visible if that fails.
  void restart() {
    if (hasPendingMove) {
      return;
    }
    final previousSnapshot = _snapshot;
    final previousLegalMoves = _legalMoves;
    final previousSelection = _selectedPieceId;
    if (previousSnapshot == null) {
      initialize();
      return;
    }

    try {
      _adopt(_engine.initialMatch(_boardDefinition));
      _selectedPieceId = null;
      _error = null;
      _retryAction = null;
      _status = MatchStatus.ready;
      _hasAppliedMove = false;
    } on Object catch (error) {
      _snapshot = previousSnapshot;
      _legalMoves = previousLegalMoves;
      _selectedPieceId = previousSelection;
      _error = error;
      _retryAction = restart;
      _status = MatchStatus.ready;
    }
  }

  /// Starts the next round of the current match.
  void advanceRound() {
    final snapshot = _snapshot;
    if (snapshot == null || hasPendingMove || !isRoundOver) {
      return;
    }

    _mutate(() => _engine.advanceRound(snapshot), onFailure: advanceRound);
  }

  /// Selects a piece for the person holding the turn.
  ///
  /// A seat played by a policy is not selectable. During the pause before a
  /// bot moves it is still that seat's turn and its moves are still the legal
  /// ones, so without this the person could pick up the bot's piece and play
  /// its move for it.
  void selectPiece(int pieceId) {
    if (hasPendingMove) {
      return;
    }
    _selectedPieceId =
        !isBotTurn && _legalMoves.any((move) => move.pieceId == pieceId)
        ? pieceId
        : null;
  }

  void clearSelection() {
    if (hasPendingMove) {
      return;
    }
    _selectedPieceId = null;
  }

  GameMove? moveForTappedDestination(int x, int y) {
    if (hasPendingMove) {
      return null;
    }
    final round = _snapshot?.round;
    final selectedPieceId = _selectedPieceId;
    if (round == null || selectedPieceId == null) {
      return null;
    }

    final selectedPieceIndex = round.pieces.indexWhere(
      (piece) => piece.id == selectedPieceId,
    );
    if (selectedPieceIndex == -1) {
      return null;
    }
    final selectedPiece = round.pieces[selectedPieceIndex];

    for (final move in _legalMoves) {
      if (move.pieceId != selectedPieceId) {
        continue;
      }
      final destination = switch (move.direction) {
        rust.GameDirection.up => (selectedPiece.x, selectedPiece.y - 1),
        rust.GameDirection.down => (selectedPiece.x, selectedPiece.y + 1),
        rust.GameDirection.left => (selectedPiece.x - 1, selectedPiece.y),
        rust.GameDirection.right => (selectedPiece.x + 1, selectedPiece.y),
      };
      if (destination == (x, y)) {
        return move;
      }
    }
    return null;
  }

  /// Plays the move a person chose. A seat held by a policy refuses it; the
  /// policy plays through [playBotMove] instead.
  void applyMove(GameMove move) {
    if (prepareHumanMove(move)) {
      commitPendingMove();
    } else if (_error != null) {
      _retryAction = () {
        applyMove(move);
      };
    }
  }

  /// Prepares a person's selected move without replacing the visible board.
  bool prepareHumanMove(GameMove move) {
    final snapshot = _snapshot;
    if (snapshot == null ||
        hasPendingMove ||
        isBotTurn ||
        !isPlaying ||
        !_legalMoves.contains(move)) {
      return false;
    }

    return _prepareMove(
      () => _engine.applyMove(snapshot, move),
      onFailure: () {
        prepareHumanMove(move);
      },
    );
  }

  /// Publishes the fully validated result that a page has finished replaying.
  void commitPendingMove() {
    final pendingMove = _pendingMove;
    if (pendingMove == null) {
      return;
    }

    _snapshot = pendingMove.result.snapshot;
    _legalMoves = pendingMove.legalMoves;
    _pendingMove = null;
    _hasAppliedMove = true;
    _selectedPieceId = null;
    _error = null;
    _retryAction = null;
    _status = MatchStatus.ready;
  }

  /// Replaces the snapshot only once its legal moves have also been read, so
  /// a mid-sequence bridge failure leaves the two consistent with each other.
  void _mutate(
    MatchSnapshot Function() produce, {
    required void Function() onFailure,
  }) {
    try {
      _adopt(produce());
      _selectedPieceId = null;
      _error = null;
      _retryAction = null;
      _status = MatchStatus.ready;
    } on Object catch (error) {
      _error = error;
      _retryAction = onFailure;
    }
  }

  bool _prepareMove(
    rust.MoveResult Function() produce, {
    required void Function() onFailure,
  }) {
    try {
      final result = produce();
      _validateContract(result.snapshot);
      final legalMoves = result.snapshot.phase == rust.GameMatchPhase.playing
          ? _engine.legalMoves(result.snapshot)
          : const <GameMove>[];
      _pendingMove = _PendingMove(result, legalMoves);
      _error = null;
      _retryAction = null;
      _status = MatchStatus.ready;
      return true;
    } on Object catch (error) {
      _error = error;
      _retryAction = onFailure;
      return false;
    }
  }

  void _adopt(MatchSnapshot snapshot) {
    _validateContract(snapshot);
    final legalMoves = snapshot.phase == rust.GameMatchPhase.playing
        ? _engine.legalMoves(snapshot)
        : const <GameMove>[];
    _snapshot = snapshot;
    _legalMoves = legalMoves;
  }

  /// Checks the shape of what the bridge returned, not the rules behind it.
  ///
  /// A snapshot that breaks one of these is a bridge or schema fault, not a
  /// game state, so it is treated as an error rather than displayed. The
  /// phase decides which result fields must be present, because the screen
  /// reads them on the strength of the phase alone.
  void _validateContract(MatchSnapshot snapshot) {
    final roundWinner = snapshot.roundWinner;
    final matchWinner = snapshot.matchWinner;
    if ((roundWinner == null) != (snapshot.roundWinReason == null)) {
      throw const FormatException(
        'snapshot round winner and reason must either both be present '
        'or absent',
      );
    }

    switch (snapshot.phase) {
      case rust.GameMatchPhase.playing:
        if (roundWinner != null || matchWinner != null) {
          throw const FormatException(
            'a round still being played carries no result',
          );
        }
      case rust.GameMatchPhase.roundOver:
        if (roundWinner == null) {
          throw const FormatException(
            'a finished round must name who took it and how',
          );
        }
        if (matchWinner != null) {
          throw const FormatException(
            'a match winner ends the match, so the phase cannot be roundOver',
          );
        }
      case rust.GameMatchPhase.matchOver:
        if (roundWinner == null) {
          throw const FormatException(
            'a match ends by a round ending, so it must name that round',
          );
        }
        if (matchWinner == null) {
          throw const FormatException('a finished match must name its winner');
        }
        final wins = switch (matchWinner) {
          rust.GamePlayer.first => snapshot.firstPlayerWins,
          rust.GamePlayer.second => snapshot.secondPlayerWins,
        };
        if (wins != 2) {
          throw const FormatException(
            'a match winner must hold the round wins that ended the match',
          );
        }
    }
  }
}

final class _PendingMove {
  const _PendingMove(this.result, this.legalMoves);

  final rust.MoveResult result;
  final List<GameMove> legalMoves;
}
