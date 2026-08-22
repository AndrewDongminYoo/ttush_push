import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

const _boardLength = 5;

final class RoundBoard extends StatelessWidget {
  const RoundBoard({
    required this.snapshot,
    required this.legalMoves,
    required this.selectedPieceId,
    required this.onCellTap,
    super.key,
  });

  final GameSnapshot snapshot;
  final List<GameMove> legalMoves;
  final int? selectedPieceId;
  final void Function(int x, int y) onCellTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        if (!side.isFinite || side <= 0) {
          return const SizedBox.shrink();
        }

        return Center(
          child: SizedBox.square(
            dimension: side,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final cellSize = side / _boardLength;
                final x = (details.localPosition.dx / cellSize).floor();
                final y = (details.localPosition.dy / cellSize).floor();
                if (x >= 0 && x < _boardLength && y >= 0 && y < _boardLength) {
                  onCellTap(x, y);
                }
              },
              child: CustomPaint(
                key: const Key('round-board-canvas'),
                painter: _RoundBoardPainter(
                  snapshot: snapshot,
                  legalMoves: legalMoves,
                  selectedPieceId: selectedPieceId,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _RoundBoardPainter extends CustomPainter {
  _RoundBoardPainter({
    required this.snapshot,
    required this.legalMoves,
    required this.selectedPieceId,
  });

  final GameSnapshot snapshot;
  final List<GameMove> legalMoves;
  final int? selectedPieceId;

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / _boardLength;
    final boardRect = Offset.zero & size;
    canvas.drawRect(boardRect, Paint()..color = const Color(0xFF101218));

    for (final tile in snapshot.tiles) {
      final cellRect = Rect.fromLTWH(
        tile.x * cellSize,
        tile.y * cellSize,
        cellSize,
        cellSize,
      );
      canvas
        ..drawRect(cellRect, Paint()..color = _tileColor(tile.kind))
        ..drawRect(
          cellRect,
          Paint()
            ..color = const Color(0xFF1B1F2A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
    }

    for (final destination in _legalDestinations()) {
      final center = Offset(
        (destination.$1 + 0.5) * cellSize,
        (destination.$2 + 0.5) * cellSize,
      );
      canvas.drawCircle(
        center,
        cellSize * 0.16,
        Paint()..color = const Color(0xFF53D769),
      );
    }

    for (final piece in snapshot.pieces) {
      final center = Offset(
        (piece.x + 0.5) * cellSize,
        (piece.y + 0.5) * cellSize,
      );
      final isSelected = piece.id == selectedPieceId;
      canvas.drawCircle(
        center,
        cellSize * 0.32,
        Paint()
          ..color = switch (piece.owner) {
            rust.GamePlayer.first => const Color(0xFF2A48DF),
            rust.GamePlayer.second => const Color(0xFFE14B4B),
          },
      );
      if (isSelected) {
        canvas.drawCircle(
          center,
          cellSize * 0.37,
          Paint()
            ..color = const Color(0xFFFFD54F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = cellSize * 0.06,
        );
      }
    }
  }

  Iterable<(int, int)> _legalDestinations() sync* {
    final selectedPieceId = this.selectedPieceId;
    if (selectedPieceId == null) {
      return;
    }
    final pieceIndex = snapshot.pieces.indexWhere(
      (piece) => piece.id == selectedPieceId,
    );
    if (pieceIndex == -1) {
      return;
    }
    final piece = snapshot.pieces[pieceIndex];

    for (final move in legalMoves) {
      if (move.pieceId != selectedPieceId) {
        continue;
      }
      yield switch (move.direction) {
        rust.GameDirection.up => (piece.x, piece.y - 1),
        rust.GameDirection.down => (piece.x, piece.y + 1),
        rust.GameDirection.left => (piece.x - 1, piece.y),
        rust.GameDirection.right => (piece.x + 1, piece.y),
      };
    }
  }

  Color _tileColor(rust.GameTileKind kind) {
    return switch (kind) {
      rust.GameTileKind.normal => const Color(0xFFE7ECF5),
      rust.GameTileKind.damaged => const Color(0xFFF5B849),
      rust.GameTileKind.hole => const Color(0xFF343A46),
    };
  }

  @override
  bool shouldRepaint(covariant _RoundBoardPainter oldDelegate) {
    return snapshot != oldDelegate.snapshot ||
        legalMoves != oldDelegate.legalMoves ||
        selectedPieceId != oldDelegate.selectedPieceId;
  }
}
