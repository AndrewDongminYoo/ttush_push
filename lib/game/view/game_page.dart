import 'package:flutter/material.dart';
import 'package:ttush_push/game/round/round_controller.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/game/view/round_board.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, RulesEngine? rulesEngine})
    : _rulesEngine = rulesEngine ?? const FrbRulesEngine();

  final RulesEngine _rulesEngine;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final RoundController _controller;

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
        body: Center(
          child: _controller.status == RoundStatus.initializationError
              ? _InitialError(onRetry: _retry)
              : const CircularProgressIndicator(),
        ),
      );
    }

    final isTerminal = snapshot.winner != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Ttush Push')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isTerminal
                    ? _terminalText(snapshot)
                    : "${_playerLabel(snapshot.currentPlayer)} player's turn",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_controller.error != null)
              _ActionError(onRetry: _retry, error: _controller.error!),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: RoundBoard(
                    snapshot: snapshot,
                    legalMoves: _controller.legalMoves,
                    selectedPieceId: _controller.selectedPieceId,
                    onCellTap: isTerminal ? (_, _) {} : _onCellTap,
                  ),
                ),
              ),
            ),
            if (isTerminal)
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _restart,
                  child: const Text('Restart round'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onCellTap(int x, int y) {
    setState(() {
      final move = _controller.moveForTappedDestination(x, y);
      if (move != null) {
        _controller.applyMove(move);
        return;
      }

      final snapshot = _controller.snapshot;
      final pieceIndex = snapshot?.pieces.indexWhere(
        (piece) =>
            piece.x == x &&
            piece.y == y &&
            piece.owner == snapshot.currentPlayer,
      );
      if (pieceIndex == null || pieceIndex == -1) {
        _controller.clearSelection();
        return;
      }
      _controller.selectPiece(snapshot!.pieces[pieceIndex].id);
    });
  }

  void _restart() {
    setState(_controller.restart);
  }

  void _retry() {
    setState(_controller.retry);
  }

  String _playerLabel(Enum player) {
    final name = player.name;
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  String _terminalText(GameSnapshot snapshot) {
    final winner = _playerLabel(snapshot.winner!);
    return '$winner wins by ${snapshot.winReason!.name}';
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
        const Text('Unable to start round'),
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
          Expanded(child: Text('Unable to update round: $error')),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
