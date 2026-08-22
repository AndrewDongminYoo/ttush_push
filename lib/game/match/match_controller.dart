import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

enum MatchStatus { initializing, ready, initializationError }

/// Holds the match a screen is showing, and nothing about how it is drawn.
///
/// It owns selection, the legal-move cache, and recoverable bridge errors. It
/// counts nothing: the score, the phase, and who starts the next round all
/// arrive from Rust inside the snapshot.
final class MatchController {
  MatchController(this._engine);

  final RulesEngine _engine;
  MatchSnapshot? _snapshot;
  List<GameMove> _legalMoves = const [];
  int? _selectedPieceId;
  Object? _error;
  void Function()? _retryAction;
  MatchStatus _status = MatchStatus.initializing;

  MatchSnapshot? get snapshot => _snapshot;
  GameSnapshot? get round => _snapshot?.round;
  List<GameMove> get legalMoves => _legalMoves;
  int? get selectedPieceId => _selectedPieceId;
  Object? get error => _error;
  MatchStatus get status => _status;

  /// Whether the current phase accepts a move.
  bool get isPlaying => _snapshot?.phase == rust.GameMatchPhase.playing;

  /// Whether a finished round is waiting to be advanced past.
  bool get isRoundOver => _snapshot?.phase == rust.GameMatchPhase.roundOver;

  bool get isMatchOver => _snapshot?.phase == rust.GameMatchPhase.matchOver;

  void initialize() {
    _snapshot = null;
    _legalMoves = const [];
    _selectedPieceId = null;
    _error = null;
    _status = MatchStatus.initializing;

    try {
      _adopt(_engine.initialMatch());
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

  void retry() {
    _retryAction?.call();
  }

  /// Starts a fresh match, keeping the current one visible if that fails.
  void restart() {
    final previousSnapshot = _snapshot;
    final previousLegalMoves = _legalMoves;
    final previousSelection = _selectedPieceId;
    if (previousSnapshot == null) {
      initialize();
      return;
    }

    try {
      _adopt(_engine.initialMatch());
      _selectedPieceId = null;
      _error = null;
      _retryAction = null;
      _status = MatchStatus.ready;
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
    if (snapshot == null || !isRoundOver) {
      return;
    }

    _mutate(() => _engine.advanceRound(snapshot), onFailure: advanceRound);
  }

  void selectPiece(int pieceId) {
    _selectedPieceId = _legalMoves.any((move) => move.pieceId == pieceId)
        ? pieceId
        : null;
  }

  void clearSelection() {
    _selectedPieceId = null;
  }

  GameMove? moveForTappedDestination(int x, int y) {
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

  void applyMove(GameMove move) {
    final snapshot = _snapshot;
    if (snapshot == null || !isPlaying || !_legalMoves.contains(move)) {
      return;
    }

    _mutate(
      () => _engine.applyMove(snapshot, move),
      onFailure: () => applyMove(move),
    );
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
  /// game state, so it is treated as an error rather than displayed.
  void _validateContract(MatchSnapshot snapshot) {
    if ((snapshot.roundWinner == null) != (snapshot.roundWinReason == null)) {
      throw const FormatException(
        'snapshot round winner and reason must either both be present '
        'or absent',
      );
    }

    final matchWinner = snapshot.matchWinner;
    if (matchWinner == null) {
      return;
    }
    if (snapshot.roundWinner == null) {
      throw const FormatException(
        'a match can only be won by a round ending, so a match winner '
        'requires a round winner',
      );
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
