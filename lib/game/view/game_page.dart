import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ttush_push/game/round/round_controller.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

const _surfaceColor = Color(0xFF0B0D12);
const _panelColor = Color(0xFF161A22);
const _mutedTextColor = Color(0xFF8A93A6);
const _firstPlayerColor = Color(0xFF2A48DF);
const _secondPlayerColor = Color(0xFFE14B4B);

class GamePage extends StatefulWidget {
  const GamePage({super.key, RulesEngine? rulesEngine})
    : _rulesEngine = rulesEngine ?? const FrbRulesEngine();

  final RulesEngine _rulesEngine;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final RoundController _controller;

  /// How the move awaiting application should be felt.
  ///
  /// A move can be applied by a tap or by retrying one the bridge rejected,
  /// and both must feel the same, so the classification outlives the tap that
  /// produced it until the move actually lands.
  bool? _pendingMoveIsPush;

  @override
  void initState() {
    super.initState();
    _controller = RoundController(widget._rulesEngine)..initialize();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _controller.snapshot;
    if (snapshot == null) {
      return Scaffold(
        backgroundColor: _surfaceColor,
        body: Center(
          child: _controller.status == RoundStatus.initializationError
              ? _InitialError(onRetry: _retry)
              : const CircularProgressIndicator(),
        ),
      );
    }

    final winner = snapshot.winner;
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            _PlayerPanel(
              player: rust.GamePlayer.first,
              isActive:
                  winner == null &&
                  snapshot.currentPlayer == rust.GamePlayer.first,
            ),
            if (_controller.error != null)
              _ActionError(onRetry: _retry, error: _controller.error!),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RoundBoard(
                      snapshot: snapshot,
                      legalMoves: _controller.legalMoves,
                      selectedPieceId: _controller.selectedPieceId,
                      onCellTap: (x, y) => _onCellTap(snapshot, x, y),
                    ),
                  ),
                  if (winner != null)
                    Positioned.fill(
                      child: _ResultOverlay(
                        winner: winner,
                        reason: snapshot.winReason!,
                        onPlayAgain: _restart,
                      ),
                    ),
                ],
              ),
            ),
            _PlayerPanel(
              player: rust.GamePlayer.second,
              isActive:
                  winner == null &&
                  snapshot.currentPlayer == rust.GamePlayer.second,
            ),
          ],
        ),
      ),
    );
  }

  void _onCellTap(GameSnapshot snapshot, int x, int y) {
    // Destination resolution precedes selection, so tapping an opposing
    // piece that is also a legal push destination pushes it.
    final move = _controller.moveForTappedDestination(x, y);
    if (move != null) {
      // Read before the move is applied: a destination someone stands on is
      // a push. This is the same read the board's markers use.
      final isPush = snapshot.pieces.any(
        (piece) => piece.x == x && piece.y == y,
      );
      _pendingMoveIsPush = isPush;
      setState(() => _controller.applyMove(move));
      _feedbackForAppliedMove();
      return;
    }

    final pieceIndex = snapshot.pieces.indexWhere(
      (piece) =>
          piece.x == x && piece.y == y && piece.owner == snapshot.currentPlayer,
    );
    if (pieceIndex == -1) {
      setState(_controller.clearSelection);
      return;
    }

    final previousSelection = _controller.selectedPieceId;
    setState(() => _controller.selectPiece(snapshot.pieces[pieceIndex].id));
    final selection = _controller.selectedPieceId;
    // Re-tapping the piece already selected changes nothing.
    if (selection != null && selection != previousSelection) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  /// Fires once the pending move has actually been applied.
  ///
  /// A won round outranks how the move was made, so it is felt as one event
  /// rather than two.
  void _feedbackForAppliedMove() {
    final isPush = _pendingMoveIsPush;
    if (isPush == null || _controller.error != null) {
      return;
    }
    _pendingMoveIsPush = null;

    if (_controller.snapshot?.winner != null) {
      unawaited(HapticFeedback.heavyImpact());
      return;
    }
    unawaited(
      isPush ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact(),
    );
  }

  void _restart() {
    _pendingMoveIsPush = null;
    setState(_controller.restart);
  }

  void _retry() {
    setState(_controller.retry);
    _feedbackForAppliedMove();
  }
}

String _playerLabel(rust.GamePlayer player) {
  return switch (player) {
    rust.GamePlayer.first => 'Player 1',
    rust.GamePlayer.second => 'Player 2',
  };
}

Color _playerColor(rust.GamePlayer player) {
  return switch (player) {
    rust.GamePlayer.first => _firstPlayerColor,
    rust.GamePlayer.second => _secondPlayerColor,
  };
}

/// One player's side of the screen.
///
/// The active side is filled with that player's color rather than only
/// labeled, so whose turn it is survives a glance from across the device.
class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.player, required this.isActive});

  final rust.GamePlayer player;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = _playerColor(player);
    return Container(
      key: Key('player-panel-${player.name}'),
      width: double.infinity,
      color: isActive ? color : _panelColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          _PlayerMark(player: player, isActive: isActive),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _playerLabel(player),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : _mutedTextColor,
              ),
            ),
          ),
          if (isActive)
            const Text(
              'Your turn',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

/// Echoes the piece silhouette used on the board, so a panel and the pieces
/// it stands for are recognizable as the same side.
class _PlayerMark extends StatelessWidget {
  const _PlayerMark({required this.player, required this.isActive});

  final rust.GamePlayer player;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : _playerColor(player),
        shape: player == rust.GamePlayer.first
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: player == rust.GamePlayer.first
            ? null
            : BorderRadius.circular(6),
      ),
    );
  }
}

/// Sits above the final board rather than replacing it, so the position that
/// ended the round stays readable while the result is read.
class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.winner,
    required this.reason,
    required this.onPlayAgain,
  });

  final rust.GamePlayer winner;
  final rust.GameWinReason reason;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _surfaceColor.withValues(alpha: 0.78),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlayerMark(player: winner, isActive: false),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      '${_playerLabel(winner)} wins',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                switch (reason) {
                  rust.GameWinReason.knockout => 'by knockout',
                  rust.GameWinReason.immobilization => 'by immobilization',
                },
                style: const TextStyle(fontSize: 16, color: _mutedTextColor),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onPlayAgain,
                child: const Text('Play Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialError extends StatelessWidget {
  const _InitialError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Unable to start round',
          style: TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _ActionError extends StatelessWidget {
  const _ActionError({required this.onRetry, required this.error});

  final VoidCallback onRetry;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Unable to update round: $error',
              style: const TextStyle(color: _mutedTextColor),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
