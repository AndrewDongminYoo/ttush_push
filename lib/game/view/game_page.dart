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

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  late final MatchController _controller;
  Timer? _botTimer;
  late final AnimationController _replayController;
  rust.MoveResolution? _replayResolution;
  bool _reducedMotion = false;
  int _replayGeneration = 0;

  /// Long enough that the board does not change while the person is still
  /// reading it. This delays a move the engine has already chosen; it does
  /// not interpolate between two states.
  static const _botPause = Duration(milliseconds: 450);
  static const _normalReplayDuration = Duration(milliseconds: 540);
  static const _reducedReplayDuration = Duration(milliseconds: 120);
  late final RoundFeedback _feedback;
  PlatformRoundFeedback? _ownedFeedback;

  @override
  void initState() {
    super.initState();
    _controller = MatchController(widget._rulesEngine)..initialize();
    _replayController = AnimationController(vsync: this)
      ..addListener(() {
        if (mounted && _controller.hasPendingMove) {
          setState(() {});
        }
      });
    final injected = widget._feedback;
    if (injected != null) {
      _feedback = injected;
    } else {
      _feedback = _ownedFeedback = PlatformRoundFeedback();
    }
  }

  @override
  void dispose() {
    _replayGeneration++;
    _botTimer?.cancel();
    _replayController.dispose();
    unawaited(_ownedFeedback?.dispose());
    super.dispose();
  }

  /// Schedules the opponent's move when it is their turn.
  ///
  /// Called after every rebuild, so a bot answers a human move, its own
  /// advance into a new round, and a change of opponent alike.
  ///
  /// A standing error stops the schedule. A failed bot move leaves the round
  /// untouched, so it is still the bot's turn and rescheduling would repeat
  /// the same failing call every [_botPause] behind the error screen. The
  /// human tap path already refuses to act while an error stands, and the
  /// Retry button is the one way past it.
  void _scheduleBotMove() {
    if (!_controller.isBotTurn ||
        _controller.hasPendingMove ||
        _controller.error != null ||
        (_botTimer?.isActive ?? false)) {
      return;
    }

    _botTimer = Timer(_botPause, () {
      if (!mounted || !_controller.isBotTurn || _controller.hasPendingMove) {
        return;
      }
      var prepared = false;
      setState(() {
        prepared = _controller.prepareBotMove();
      });
      if (prepared) {
        _playPendingMove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleBotMove();
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
    final replaying = _controller.hasPendingMove && _replayResolution != null;
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
              _ActionError(
                onRetry: replaying ? null : _retry,
                error: _controller.error!,
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RoundBoard(
                      key: replaying
                          ? const Key('move-resolution-playback')
                          : null,
                      snapshot: round,
                      legalMoves: _controller.legalMoves,
                      selectedPieceId: _controller.selectedPieceId,
                      playback: replaying
                          ? BoardPlayback(
                              resolution: _replayResolution!,
                              progress: _replayController.value,
                              reducedMotion: _reducedMotion,
                            )
                          : null,
                      onCellTap: replaying
                          ? null
                          : (x, y) => _onCellTap(round, x, y),
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
              label: _controller.opponent.label,
              onTap: replaying ? null : _cycleOpponent,
            ),
          ],
        ),
      ),
    );
  }

  void _advanceRound() {
    setState(_controller.advanceRound);
  }

  void _cycleOpponent() {
    _botTimer?.cancel();
    setState(_controller.cycleOpponent);
  }

  void _onCellTap(GameSnapshot snapshot, int x, int y) {
    if (_controller.hasPendingMove) {
      return;
    }
    // Destination resolution precedes selection, so tapping an opposing
    // piece that is also a legal push destination pushes it.
    final move = _controller.moveForTappedDestination(x, y);
    if (move != null) {
      var prepared = false;
      setState(() {
        prepared = _controller.prepareHumanMove(move);
      });
      if (prepared) {
        _playPendingMove();
      }
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

  void _playPendingMove() {
    final resolution = _controller.pendingResolution;
    if (resolution != null) {
      _playPreparedMove(resolution);
    }
  }

  void _playPreparedMove(rust.MoveResolution resolution) {
    final generation = ++_replayGeneration;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _replayResolution = resolution;
      _reducedMotion = reducedMotion;
      _replayController
        ..duration = reducedMotion
            ? _reducedReplayDuration
            : _normalReplayDuration
        ..value = 0;
    });

    late final AnimationStatusListener onReplayComplete;
    onReplayComplete = (status) {
      if (status != AnimationStatus.completed) {
        return;
      }
      _replayController.removeStatusListener(onReplayComplete);
      if (!mounted ||
          generation != _replayGeneration ||
          _controller.pendingResolution != resolution) {
        return;
      }

      setState(() {
        _controller.commitPendingMove();
        _replayResolution = null;
      });
      _feedbackForCommittedMove(resolution);
      _scheduleBotMove();
    };
    _replayController
      ..addStatusListener(onReplayComplete)
      ..forward();
  }

  /// Fires only after the replay has committed the Rust-prepared snapshot.
  void _feedbackForCommittedMove(rust.MoveResolution resolution) {
    if (!_controller.isPlaying) {
      _feedback.roundWon();
      return;
    }
    switch (resolution.actionKind) {
      case rust.MoveActionKind.normal:
        _feedback.moveApplied();
      case rust.MoveActionKind.push:
        _feedback.pushApplied();
    }
  }

  void _restart() {
    setState(_controller.restart);
  }

  void _retry() {
    setState(_controller.retry);
    _playPendingMove();
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
    this.label,
    this.onTap,
  });

  final rust.GamePlayer player;
  final int wins;
  final bool isActive;

  /// Overrides the player's name, so the second seat can say which opponent
  /// is playing it.
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _playerColor(player);
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                label ?? _playerLabel(player),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : _mutedTextColor,
                ),
              ),
            ),
            // Whose turn it is reads off the filled panel and the white
            // mark. A second, textual say-so competed for the row with the
            // longest opponent name and lost it to an ellipsis.
            _RoundWins(player: player, wins: wins, isActive: isActive),
          ],
        ),
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

  final VoidCallback? onRetry;
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
