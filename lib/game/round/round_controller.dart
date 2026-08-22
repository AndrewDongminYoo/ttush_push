import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

enum RoundStatus { initializing, ready, initializationError }

final class RoundController {
  RoundController(this._engine);

  final RulesEngine _engine;
  GameSnapshot? _snapshot;
  List<GameMove> _legalMoves = const [];
  int? _selectedPieceId;
  Object? _error;
  void Function()? _retryAction;
  RoundStatus _status = RoundStatus.initializing;

  GameSnapshot? get snapshot => _snapshot;
  List<GameMove> get legalMoves => _legalMoves;
  int? get selectedPieceId => _selectedPieceId;
  Object? get error => _error;
  RoundStatus get status => _status;

  void initialize() {
    _snapshot = null;
    _legalMoves = const [];
    _selectedPieceId = null;
    _error = null;
    _status = RoundStatus.initializing;

    try {
      final snapshot = _engine.initialState();
      _validateTerminalFields(snapshot);
      _snapshot = snapshot;
      _legalMoves = snapshot.winner == null
          ? _engine.legalMoves(snapshot)
          : const [];
      _status = RoundStatus.ready;
      _retryAction = null;
    } on Object catch (error) {
      _snapshot = null;
      _legalMoves = const [];
      _selectedPieceId = null;
      _error = error;
      _retryAction = initialize;
      _status = RoundStatus.initializationError;
    }
  }

  void retry() {
    _retryAction?.call();
  }

  void restart() {
    final previousSnapshot = _snapshot;
    final previousLegalMoves = _legalMoves;
    final previousSelection = _selectedPieceId;
    if (previousSnapshot == null) {
      initialize();
      return;
    }

    try {
      final snapshot = _engine.initialState();
      _validateTerminalFields(snapshot);
      _snapshot = snapshot;
      _legalMoves = snapshot.winner == null
          ? _engine.legalMoves(snapshot)
          : const [];
      _selectedPieceId = null;
      _error = null;
      _retryAction = null;
      _status = RoundStatus.ready;
    } on Object catch (error) {
      _snapshot = previousSnapshot;
      _legalMoves = previousLegalMoves;
      _selectedPieceId = previousSelection;
      _error = error;
      _retryAction = restart;
      _status = RoundStatus.ready;
    }
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
    final snapshot = _snapshot;
    final selectedPieceId = _selectedPieceId;
    if (snapshot == null || selectedPieceId == null) {
      return null;
    }

    final selectedPieceIndex = snapshot.pieces.indexWhere(
      (piece) => piece.id == selectedPieceId,
    );
    if (selectedPieceIndex == -1) {
      return null;
    }
    final selectedPiece = snapshot.pieces[selectedPieceIndex];

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
    if (snapshot == null ||
        snapshot.winner != null ||
        !_legalMoves.contains(move)) {
      return;
    }

    try {
      final nextSnapshot = _engine.applyMove(snapshot, move);
      _validateTerminalFields(nextSnapshot);
      _snapshot = nextSnapshot;
      _legalMoves = nextSnapshot.winner == null
          ? _engine.legalMoves(nextSnapshot)
          : const [];
      _selectedPieceId = null;
      _error = null;
      _retryAction = null;
      _status = RoundStatus.ready;
    } on Object catch (error) {
      _error = error;
      _retryAction = () => applyMove(move);
    }
  }

  void _validateTerminalFields(GameSnapshot snapshot) {
    if ((snapshot.winner == null) != (snapshot.winReason == null)) {
      throw const FormatException(
        'snapshot winner and win reason must either both be present or absent',
      );
    }
  }
}
