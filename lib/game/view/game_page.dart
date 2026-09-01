import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:ttush_push/game/board/board_definition.dart';
import 'package:ttush_push/game/coach/first_play_coach_store.dart';
import 'package:ttush_push/game/feedback/round_feedback.dart';
import 'package:ttush_push/game/match/match_controller.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/game/view/opponent_label.dart';
import 'package:ttush_push/game/view/production_sprite_set.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/l10n/l10n.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

const _surfaceColor = Color(0xFF0B0D12);
const _panelColor = Color(0xFF161A22);
const _panelBorderColor = Color(0xFF303846);
const _mutedTextColor = Color(0xFF8A93A6);
const _firstPlayerColor = Color(0xFF2A48DF);
const _secondPlayerColor = Color(0xFFE14B4B);

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    RulesEngine? rulesEngine,
    BoardDefinition? boardDefinition,
    Opponent? opponent,
    this._coachStore,
    this._feedback,
  }) : _rulesEngine = rulesEngine ?? const FrbRulesEngine(),
       _boardDefinition = boardDefinition ?? baselineBoardDefinition,
       _opponent = opponent ?? Opponent.human;

  final RulesEngine _rulesEngine;
  final BoardDefinition _boardDefinition;

  /// The seat the match opens with. Selection stays unlocked until the first
  /// committed move, so the in-match control can still override it.
  final Opponent _opponent;
  final FirstPlayCoachStore? _coachStore;
  final RoundFeedback? _feedback;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  late MatchController _controller;
  Timer? _botTimer;
  late final AnimationController _replayController;
  rust.MoveResolution? _replayResolution;
  Map<int, ExplorerFacing> _pieceFacings = const {};
  bool _reducedMotion = false;
  int _replayGeneration = 0;
  FirstPlayCoachStore? _coachStore;
  bool _coachVisible = false;
  int _coachStep = 0;
  int _coachInteractionGeneration = 0;
  String? _announcement;
  int _announcementGeneration = 0;
  int _errorAnnouncementGeneration = 0;

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
    _controller = _createMatchController();
    _coachStore = widget._coachStore;
    unawaited(_loadCoach());
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
  void didUpdateWidget(covariant GamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget._boardDefinition, widget._boardDefinition)) {
      return;
    }

    _botTimer?.cancel();
    _botTimer = null;
    _replayGeneration++;
    _replayController.stop();
    _replayResolution = null;
    _pieceFacings = const {};
    _announcement = null;
    _controller = _createMatchController();
  }

  MatchController _createMatchController() {
    final controller = MatchController(
      widget._rulesEngine,
      boardDefinition: widget._boardDefinition.rules,
    );
    // The seat comes before initialize, because selecting one drops any
    // standing error, and an initialization failure must survive to the banner.
    controller.selectOpponent(widget._opponent);
    controller.initialize();
    return controller;
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
    // The match is not saved anywhere, so leaving discards it. Confirm before
    // the route goes, rather than letting a stray back gesture end a round.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) {
          navigator.pop();
        }
      },
      child: _buildMatch(context),
    );
  }

  /// Leaves the match through the same confirmation the back gesture uses.
  ///
  /// iOS needs this: `PopScope.canPop` false makes `popGestureEnabled` false,
  /// which disables the interactive back-swipe before Flutter would ever call
  /// `onPopInvokedWithResult`, so the gesture cannot be the only way out.
  Future<void> _leaveMatch() async {
    final navigator = Navigator.of(context);
    if (await _confirmLeave()) {
      navigator.pop();
    }
  }

  Future<bool> _confirmLeave() async {
    final l10n = localizationsOf(context);
    final leaving = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('leave-match-dialog'),
        title: Text(l10n.leaveMatchTitle),
        content: Text(l10n.leaveMatchMessage),
        actions: [
          TextButton(
            key: const Key('leave-match-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('leave-match-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.leaveMatch),
          ),
        ],
      ),
    );
    return leaving ?? false;
  }

  Widget _buildMatch(BuildContext context) {
    _scheduleBotMove();
    final snapshot = _controller.snapshot;
    if (snapshot == null) {
      return Scaffold(
        backgroundColor: _surfaceColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: _AirRuinsBackground(
                assetPath: widget._boardDefinition.backgroundAssetPath,
              ),
            ),
            Center(
              child: _controller.status == MatchStatus.initializationError
                  ? _InitialError(
                      key: ValueKey(
                        'initial-error-$_errorAnnouncementGeneration',
                      ),
                      onRetry: _retry,
                    )
                  : const CircularProgressIndicator(),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: _LeaveMatch(onPressed: _leaveMatch),
              ),
            ),
          ],
        ),
      );
    }

    final round = snapshot.round;
    final playing = _controller.isPlaying;
    final replaying = _controller.hasPendingMove && _replayResolution != null;
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: _AirRuinsBackground(
              assetPath: widget._boardDefinition.backgroundAssetPath,
            ),
          ),
          if (_announcement case final String announcement)
            KeyedSubtree(
              key: const Key('match-announcement'),
              child: Semantics(
                key: ValueKey('match-announcement-$_announcementGeneration'),
                label: announcement,
                liveRegion: true,
                child: const SizedBox.shrink(),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                _PlayerPanel(
                  player: rust.GamePlayer.second,
                  wins: snapshot.secondPlayerWins,
                  isActive:
                      playing && round.currentPlayer == rust.GamePlayer.second,
                  leadingAction: _LeaveMatch(onPressed: _leaveMatch),
                  action: _OpponentControl(
                    opponent: _controller.opponent,
                    enabled: _controller.canChangeOpponent,
                    onPressed: () => _showOpponentSheet(context),
                  ),
                ),
                if (_controller.error != null)
                  _ActionError(
                    key: ValueKey(
                      'action-error-$_errorAnnouncementGeneration',
                    ),
                    onRetry: replaying ? null : _retry,
                    error: _controller.error!,
                  ),
                if (_coachVisible && playing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: _FirstPlayCoach(
                      step: _coachStep,
                      onNext: _advanceCoach,
                      onDismiss: _completeCoach,
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RoundBoard(
                          snapshot: round,
                          legalMoves: _controller.legalMoves,
                          selectedPieceId: _controller.selectedPieceId,
                          pieceFacings: _pieceFacings,
                          playback: replaying
                              ? BoardPlayback(
                                  resolution: _replayResolution!,
                                  progress: _replayController.value,
                                  reducedMotion: _reducedMotion,
                                )
                              : null,
                          onCellTap:
                              replaying ||
                                  _controller.isBotTurn ||
                                  _controller.error != null
                              ? null
                              : (x, y) => _onCellTap(round, x, y),
                        ),
                      ),
                      if (!playing)
                        Positioned.fill(
                          child: _ResultOverlay(
                            snapshot: snapshot,
                            onContinue: _controller.error != null
                                ? null
                                : _controller.isMatchOver
                                ? _restart
                                : _advanceRound,
                          ),
                        ),
                    ],
                  ),
                ),
                _PlayerPanel(
                  player: rust.GamePlayer.first,
                  wins: snapshot.firstPlayerWins,
                  isActive:
                      playing && round.currentPlayer == rust.GamePlayer.first,
                  helpAction: playing
                      ? _CoachHelp(onPressed: _showCoach)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _advanceRound() {
    setState(() => _mutateAndResetFacing(_controller.advanceRound));
  }

  Future<void> _loadCoach() async {
    final interactionGeneration = _coachInteractionGeneration;
    var isComplete = false;
    try {
      isComplete = await _resolvedCoachStore.isComplete(
        version: firstPlayCoachVersion,
      );
    } on Object catch (error, stackTrace) {
      log(
        'Failed to read first-play coach completion',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted || interactionGeneration != _coachInteractionGeneration) {
      return;
    }
    setState(() => _coachVisible = !isComplete);
  }

  void _advanceCoach() {
    _coachInteractionGeneration++;
    if (_coachStep < 2) {
      setState(() => _coachStep++);
      return;
    }
    _completeCoach();
  }

  void _completeCoach() {
    _coachInteractionGeneration++;
    setState(() => _coachVisible = false);
    unawaited(_markCoachComplete());
  }

  void _showCoach() {
    _coachInteractionGeneration++;
    setState(() {
      _coachStep = 0;
      _coachVisible = true;
    });
  }

  Future<void> _markCoachComplete() async {
    try {
      await _resolvedCoachStore.markComplete(version: firstPlayCoachVersion);
    } on Object catch (error, stackTrace) {
      log(
        'Failed to persist first-play coach completion',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  FirstPlayCoachStore get _resolvedCoachStore =>
      _coachStore ??= SharedPreferencesFirstPlayCoachStore();

  Future<void> _showOpponentSheet(BuildContext context) async {
    final controller = _controller;
    if (!controller.canChangeOpponent) {
      return;
    }
    _botTimer?.cancel();
    final opponent = await showModalBottomSheet<Opponent>(
      context: context,
      backgroundColor: _panelColor,
      builder: (context) => _OpponentSelectionSheet(
        selectedOpponent: controller.opponent,
      ),
    );
    if (!mounted || !identical(controller, _controller)) {
      return;
    }
    if (opponent == null) {
      _scheduleBotMove();
      return;
    }
    if (!controller.canChangeOpponent) {
      return;
    }
    setState(() => controller.selectOpponent(opponent));
    _scheduleBotMove();
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

    final piece = snapshot.pieces[pieceIndex];
    final previousSelection = _controller.selectedPieceId;
    final l10n = localizationsOf(context);
    var announcedSelection = false;
    setState(() {
      _controller.selectPiece(piece.id);
      final selection = _controller.selectedPieceId;
      if (selection != null && selection != previousSelection) {
        final moveCount = _controller.legalMoves
            .where((move) => move.pieceId == selection)
            .length;
        _announce(
          l10n.explorerSelectedAnnouncement(
            _playerLabel(l10n, piece.owner),
            moveCount,
          ),
        );
        announcedSelection = true;
      }
    });
    // Re-tapping the piece already selected changes nothing.
    if (announcedSelection) {
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
      _updateFacingFor(resolution);
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
        _prunePieceFacings();
        _replayResolution = null;
        final l10n = localizationsOf(context);
        if (_controller.isMatchOver) {
          final snapshot = _controller.snapshot!;
          _announce(
            l10n.matchResultAnnouncement(
              _playerLabel(l10n, snapshot.matchWinner!),
              _winReasonLabel(l10n, snapshot.roundWinReason!),
              snapshot.firstPlayerWins,
              snapshot.secondPlayerWins,
            ),
          );
        } else if (_controller.isRoundOver) {
          final snapshot = _controller.snapshot!;
          _announce(
            l10n.roundResultAnnouncement(
              _playerLabel(l10n, snapshot.roundWinner!),
              _winReasonLabel(l10n, snapshot.roundWinReason!),
            ),
          );
        } else {
          _announce(
            switch (resolution.actionKind) {
              rust.MoveActionKind.normal => l10n.moveAppliedAnnouncement,
              rust.MoveActionKind.push => l10n.pushAppliedAnnouncement,
            },
          );
        }
      });
      _feedbackForCommittedMove(resolution);
      _scheduleBotMove();
    };
    _replayController
      ..addStatusListener(onReplayComplete)
      ..forward();
  }

  /// Replaces the live-region node so identical consecutive messages speak.
  void _announce(String announcement) {
    _announcement = announcement;
    _announcementGeneration++;
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
    setState(() => _mutateAndResetFacing(_controller.restart));
  }

  void _retry() {
    setState(() {
      _mutateAndResetFacing(_controller.retry);
      if (_controller.error != null) {
        _errorAnnouncementGeneration++;
      }
    });
    _playPendingMove();
  }

  void _updateFacingFor(rust.MoveResolution resolution) {
    final next = Map<int, ExplorerFacing>.of(_pieceFacings);
    final mover = resolution.mover;
    final moverFacing = _visualFacingForTravel(
      fromX: mover.fromX,
      fromY: mover.fromY,
      toX: mover.toX,
      toY: mover.toY,
    );
    if (moverFacing != null) {
      next[mover.pieceId] = moverFacing;
    }

    final displaced = resolution.displaced;
    if (displaced != null) {
      final displacedFacing = switch ((displaced.toX, displaced.toY)) {
        (final int toX, final int toY) => _visualFacingForTravel(
          fromX: displaced.fromX,
          fromY: displaced.fromY,
          toX: toX,
          toY: toY,
        ),
        _ => _visualFacingByRustDirection[displaced.exitDirection],
      };
      if (displacedFacing != null) {
        next[displaced.pieceId] = displacedFacing;
      }
    }
    _pieceFacings = next;
  }

  void _prunePieceFacings() {
    final pieceIds = _controller.snapshot!.round.pieces
        .map((piece) => piece.id)
        .toSet();
    _pieceFacings = {
      for (final entry in _pieceFacings.entries)
        if (pieceIds.contains(entry.key)) entry.key: entry.value,
    };
  }

  void _mutateAndResetFacing(void Function() mutation) {
    final previousHash = _controller.snapshot?.snapshotHash;
    mutation();
    if (_controller.snapshot?.snapshotHash != previousHash) {
      _pieceFacings = const {};
    }
  }
}

ExplorerFacing? _visualFacingForTravel({
  required int fromX,
  required int fromY,
  required int toX,
  required int toY,
}) {
  if (toX > fromX) {
    return ExplorerFacing.right;
  }
  if (toX < fromX) {
    return ExplorerFacing.left;
  }
  if (toY > fromY) {
    return ExplorerFacing.up;
  }
  if (toY < fromY) {
    return ExplorerFacing.down;
  }
  return null;
}

const _visualFacingByRustDirection = <rust.GameDirection, ExplorerFacing>{
  rust.GameDirection.up: ExplorerFacing.down,
  rust.GameDirection.down: ExplorerFacing.up,
  rust.GameDirection.left: ExplorerFacing.left,
  rust.GameDirection.right: ExplorerFacing.right,
};

String _playerLabel(AppLocalizations l10n, rust.GamePlayer player) {
  return switch (player) {
    rust.GamePlayer.first => l10n.azureExpedition,
    rust.GamePlayer.second => l10n.emberExpedition,
  };
}

String _winReasonLabel(
  AppLocalizations l10n,
  rust.GameWinReason winReason,
) {
  return switch (winReason) {
    rust.GameWinReason.knockout => l10n.byKnockout,
    rust.GameWinReason.immobilization => l10n.byImmobilization,
  };
}

class _FirstPlayCoach extends StatelessWidget {
  const _FirstPlayCoach({
    required this.step,
    required this.onNext,
    required this.onDismiss,
  });

  final int step;
  final VoidCallback onNext;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = localizationsOf(context);
    final message = switch (step) {
      0 => l10n.coachSelectAzure,
      1 => l10n.coachMovesAndPushes,
      _ => l10n.coachCrackedFoothold,
    };
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          key: const Key('first-play-coach'),
          color: _panelColor,
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  key: const Key('coach-message'),
                  label: message,
                  liveRegion: true,
                  child: ExcludeSemantics(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OverflowBar(
                  spacing: 8,
                  children: [
                    TextButton(
                      key: const Key('coach-dismiss'),
                      onPressed: onDismiss,
                      child: Text(l10n.dismiss),
                    ),
                    TextButton(
                      key: const Key('coach-next'),
                      onPressed: onNext,
                      child: Text(step == 2 ? l10n.done : l10n.next),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveMatch extends StatelessWidget {
  const _LeaveMatch({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = localizationsOf(context);
    return IconButton(
      key: const Key('leave-match'),
      tooltip: l10n.leaveMatch,
      color: Colors.white,
      onPressed: onPressed,
      icon: const Icon(Icons.close),
    );
  }
}

class _CoachHelp extends StatelessWidget {
  const _CoachHelp({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = localizationsOf(context);
    return IconButton(
      key: const Key('coach-help'),
      tooltip: l10n.howToPlay,
      color: Colors.white,
      onPressed: onPressed,
      icon: const Icon(Icons.help_outline),
    );
  }
}

class _AirRuinsBackground extends StatelessWidget {
  const _AirRuinsBackground({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final alignment = MediaQuery.orientationOf(context) == Orientation.portrait
        ? Alignment.centerLeft
        : Alignment.center;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            assetPath,
            key: const Key('air-ruins-background'),
            fit: BoxFit.cover,
            alignment: alignment,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x660B0D12), Color(0xBB0B0D12)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _playerColor(rust.GamePlayer player) {
  return switch (player) {
    rust.GamePlayer.first => _firstPlayerColor,
    rust.GamePlayer.second => _secondPlayerColor,
  };
}

/// One player's side of the screen.
///
/// Both panels share one muted surface.
/// The active side gains a board-facing accent.
class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({
    required this.player,
    required this.wins,
    required this.isActive,
    this.leadingAction,
    this.action,
    this.helpAction,
  });

  final rust.GamePlayer player;
  final int wins;
  final bool isActive;

  final Widget? leadingAction;
  final Widget? action;
  final Widget? helpAction;

  @override
  Widget build(BuildContext context) {
    final color = _playerColor(player);
    final l10n = localizationsOf(context);
    const sharedBorder = BorderSide(color: _panelBorderColor);
    final boardFacingBorder = BorderSide(
      color: isActive ? color : _panelBorderColor,
      width: 3,
    );
    return Container(
      key: Key('player-panel-${player.name}'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border(
          top: player == rust.GamePlayer.first
              ? boardFacingBorder
              : sharedBorder,
          right: sharedBorder,
          bottom: player == rust.GamePlayer.second
              ? boardFacingBorder
              : sharedBorder,
          left: sharedBorder,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (leadingAction case final Widget leadingAction) ...[
                leadingAction,
                const SizedBox(width: 4),
              ],
              _PlayerMark(player: player, isActive: isActive),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _playerLabel(l10n, player),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : _mutedTextColor,
                  ),
                ),
              ),
              _RoundWins(player: player, wins: wins, isActive: isActive),
              if (helpAction case final Widget helpAction) ...[
                const SizedBox(width: 4),
                helpAction,
              ],
            ],
          ),
          if (action case final Widget action) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      ),
    );
  }
}

class _OpponentControl extends StatelessWidget {
  const _OpponentControl({
    required this.opponent,
    required this.enabled,
    required this.onPressed,
  });

  final Opponent opponent;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = localizationsOf(context);
    return OutlinedButton.icon(
      key: const Key('opponent-control'),
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.groups_outlined, size: 18),
      label: Text(l10n.opponentWithValue(opponentLabel(l10n, opponent))),
    );
  }
}

class _OpponentSelectionSheet extends StatelessWidget {
  const _OpponentSelectionSheet({required this.selectedOpponent});

  final Opponent selectedOpponent;

  @override
  Widget build(BuildContext context) {
    final l10n = localizationsOf(context);
    return SafeArea(
      top: false,
      child: RadioGroup<Opponent>(
        groupValue: selectedOpponent,
        onChanged: (opponent) => Navigator.pop(context, opponent),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              l10n.opponent,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            for (final opponent in Opponent.values)
              Semantics(
                selected: opponent == selectedOpponent,
                child: RadioListTile<Opponent>(
                  key: Key('opponent-choice-${opponent.name}'),
                  value: opponent,
                  title: Text(
                    opponentLabel(l10n, opponent),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
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
        color: _playerColor(player),
        shape: player == rust.GamePlayer.first
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: player == rust.GamePlayer.first
            ? null
            : BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
    );
  }
}

/// Sits above the final board rather than replacing it, so the position that
/// ended the round stays readable while the result is read.
class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.snapshot, required this.onContinue});

  final MatchSnapshot snapshot;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final winner = snapshot.roundWinner!;
    final matchWinner = snapshot.matchWinner;
    final isMatchComplete = matchWinner != null;
    final l10n = localizationsOf(context);
    return ColoredBox(
      color: _surfaceColor.withValues(alpha: 0.78),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            key: const Key('result-overlay'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                // Only the result copy scales on a short screen. The primary
                // action keeps its full touch target.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        key: Key(
                          isMatchComplete
                              ? 'result-scope-match'
                              : 'result-scope-round',
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isMatchComplete
                              ? _playerColor(winner)
                              : _panelColor,
                          borderRadius: BorderRadius.circular(999),
                          border: isMatchComplete
                              ? null
                              : Border.all(color: _panelBorderColor),
                        ),
                        child: Text(
                          isMatchComplete
                              ? l10n.matchComplete
                              : l10n.roundComplete,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Who won and what they won are separate lines. On one
                      // line the sentence runs past a phone's width and
                      // ellipsis eats exactly the half that says what happened.
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PlayerMark(player: winner, isActive: false),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              _playerLabel(l10n, winner),
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
                        isMatchComplete ? l10n.winsMatch : l10n.takesRound,
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
                          rust.GameWinReason.knockout => l10n.byKnockout,
                          rust.GameWinReason.immobilization =>
                            l10n.byImmobilization,
                        },
                        style: const TextStyle(
                          fontSize: 16,
                          color: _mutedTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.score(
                          snapshot.firstPlayerWins,
                          snapshot.secondPlayerWins,
                        ),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: _mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, kMinInteractiveDimension),
                ),
                onPressed: onContinue,
                child: Text(
                  isMatchComplete ? l10n.newMatch : l10n.nextRound,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialError extends StatelessWidget {
  const _InitialError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = localizationsOf(context);
    return Semantics(
      key: const Key('initial-error'),
      label: l10n.unableToStartRound,
      liveRegion: true,
      container: true,
      explicitChildNodes: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              l10n.unableToStartRound,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}

class _ActionError extends StatelessWidget {
  const _ActionError({required this.onRetry, required this.error, super.key});

  final VoidCallback? onRetry;
  final Object error;

  @override
  Widget build(BuildContext context) {
    final l10n = localizationsOf(context);
    final message = l10n.unableToUpdateRound(error.toString());
    return Semantics(
      key: const Key('action-error'),
      label: message,
      liveRegion: true,
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  message,
                  style: const TextStyle(color: _mutedTextColor),
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
