import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ttush_push/game/feedback/round_feedback.dart';
import 'package:ttush_push/game/match/match_controller.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

const _surfaceColor = Color(0xFF0B0D12);
const _panelColor = Color(0xFF161A22);
const _mutedTextColor = Color(0xFF8A93A6);
const _firstPlayerColor = Color(0xFF2A48DF);
const _secondPlayerColor = Color(0xFFE14B4B);

class GamePage extends StatefulWidget {
  const GamePage({super.key, RulesEngine? rulesEngine, this._feedback})
    : _rulesEngine = rulesEngine ?? const FrbRulesEngine();

  final RulesEngine _rulesEngine;
  final RoundFeedback? _feedback;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final MatchController _controller;

  /// How the move awaiting application should be felt.
  ///
  /// A move can be applied by a tap or by retrying one the bridge rejected,
  /// and both must feel the same, so the classification outlives the tap that
  /// produced it until the move actually lands.
  bool? _pendingMoveIsPush;
  late final RoundFeedback _feedback;
  PlatformRoundFeedback? _ownedFeedback;

  @override
  void initState() {
    super.initState();
    _controller = MatchController(widget._rulesEngine)..initialize();
    final injected = widget._feedback;
    if (injected != null) {
      _feedback = injected;
    } else {
      _feedback = _ownedFeedback = PlatformRoundFeedback();
    }
  }

  @override
  void dispose() {
    unawaited(_ownedFeedback?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _controller.snapshot;
    if (snapshot == null) {
      return Scaffold(
        backgroundColor: _surfaceColor,
        body: Center(
          child: _controller.status == MatchStatus.initializationError
              ? _InitialError(onRetry: _retry)
              : const CircularProgressIndicator(),
        ),
      );
    }

    final round = snapshot.round;
    final playing = _controller.isPlaying;
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            _PlayerPanel(
              player: rust.GamePlayer.first,
              wins: snapshot.firstPlayerWins,
              isActive: playing && round.currentPlayer == rust.GamePlayer.first,
            ),
            if (_controller.error != null)
              _ActionError(onRetry: _retry, error: _controller.error!),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RoundBoard(
                      snapshot: round,
                      legalMoves: _controller.legalMoves,
                      selectedPieceId: _controller.selectedPieceId,
                      onCellTap: (x, y) => _onCellTap(round, x, y),
                    ),
                  ),
                  if (!playing)
                    Positioned.fill(
                      child: _ResultOverlay(
                        snapshot: snapshot,
                        onContinue: _controller.isMatchOver
                            ? _restart
                            : _advanceRound,
                      ),
                    ),
                ],
              ),
            ),
            _PlayerPanel(
              player: rust.GamePlayer.second,
              wins: snapshot.secondPlayerWins,
              isActive:
                  playing && round.currentPlayer == rust.GamePlayer.second,
            ),
          ],
        ),
      ),
    );
  }

  void _advanceRound() {
    setState(_controller.advanceRound);
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
      _feedback.pieceSelected();
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

    if (!_controller.isPlaying) {
      _feedback.roundWon();
      return;
    }
    if (isPush) {
      _feedback.pushApplied();
    } else {
      _feedback.moveApplied();
    }
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
  const _PlayerPanel({
    required this.player,
    required this.wins,
    required this.isActive,
  });

  final rust.GamePlayer player;
  final int wins;
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
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Text(
                'Your turn',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          _RoundWins(player: player, wins: wins, isActive: isActive),
        ],
      ),
    );
  }
}

/// The rounds a player has taken, as pips rather than a number, so the score
/// is legible at a glance from across the device.
class _RoundWins extends StatelessWidget {
  const _RoundWins({
    required this.player,
    required this.wins,
    required this.isActive,
  });

  static const _roundsToWin = 2;

  final rust.GamePlayer player;
  final int wins;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('round-wins-${player.name}-$wins'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var round = 0; round < _roundsToWin; round++)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: round < wins
                    ? (isActive ? Colors.white : _mutedTextColor)
                    : Colors.transparent,
                border: Border.all(
                  color: isActive ? Colors.white : _mutedTextColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
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
      key: Key('player-mark-${player.name}'),
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
  const _ResultOverlay({required this.snapshot, required this.onContinue});

  final MatchSnapshot snapshot;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final winner = snapshot.roundWinner!;
    final matchWinner = snapshot.matchWinner;
    return ColoredBox(
      color: _surfaceColor.withValues(alpha: 0.78),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          // A short screen scales the result down rather than clipping it,
          // for the same reason the board shrinks instead of being cut.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              key: const Key('result-overlay'),
              mainAxisSize: MainAxisSize.min,
              children: [
                // Who won and what they won are separate lines. On one line
                // the sentence runs past a phone's width and ellipsis eats
                // exactly the half that says what happened.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PlayerMark(player: winner, isActive: false),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _playerLabel(winner),
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
                const SizedBox(height: 4),
                Text(
                  matchWinner == null ? 'takes the round' : 'wins the match',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  switch (snapshot.roundWinReason!) {
                    rust.GameWinReason.knockout => 'by knockout',
                    rust.GameWinReason.immobilization => 'by immobilization',
                  },
                  style: const TextStyle(fontSize: 16, color: _mutedTextColor),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.firstPlayerWins} - ${snapshot.secondPlayerWins}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _mutedTextColor,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onContinue,
                  child: Text(
                    matchWinner == null ? 'Next Round' : 'New Match',
                  ),
                ),
              ],
            ),
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
