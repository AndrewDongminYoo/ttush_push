import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

const _boardLength = 5;

/// How a legal destination is presented.
///
/// The distinction is read from the current snapshot, not derived from any
/// rule: a destination is a push when some piece already stands there. What
/// the push then does stays entirely in Rust.
enum DestinationKind { move, push }

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
              onTapUp: (details) {
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

  static const _voidColor = Color(0xFF0B0D12);
  static const _footholdColor = Color(0xFFE7ECF5);
  static const _damagedFootholdColor = Color(0xFFF3CE8E);
  static const _crackColor = Color(0xFF6B4A16);
  static const _footholdEdgeColor = Color(0xFFA9B4C6);
  static const _firstPlayerColor = Color(0xFF2A48DF);
  static const _secondPlayerColor = Color(0xFFE14B4B);
  static const _pieceEdgeColor = Color(0xFF0B0D12);
  static const _selectionColor = Color(0xFFFFD54F);
  static const _destinationColor = Color(0xFF53D769);

  final GameSnapshot snapshot;
  final List<GameMove> legalMoves;
  final int? selectedPieceId;

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / _boardLength;
    canvas.drawRect(Offset.zero & size, Paint()..color = _voidColor);

    for (final tile in snapshot.tiles) {
      _paintTile(canvas, tile, cellSize);
    }
    for (final piece in snapshot.pieces) {
      _paintPiece(canvas, piece, cellSize);
    }
    // Destinations paint last so an occupied one stays visible.
    for (final destination in _legalDestinations()) {
      _paintDestination(canvas, destination, cellSize);
    }
  }

  /// Paints one foothold.
  ///
  /// A hole is the absence of a foothold rather than a differently colored
  /// one, so nothing is drawn and the void behind the board shows through.
  void _paintTile(Canvas canvas, rust.GameTile tile, double cellSize) {
    if (tile.kind == rust.GameTileKind.hole) {
      return;
    }

    final inset = cellSize * 0.06;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        tile.x * cellSize + inset,
        tile.y * cellSize + inset,
        cellSize - inset * 2,
        cellSize - inset * 2,
      ),
      Radius.circular(cellSize * 0.12),
    );
    final isDamaged = tile.kind == rust.GameTileKind.damaged;

    canvas
      ..drawRRect(
        body,
        Paint()..color = isDamaged ? _damagedFootholdColor : _footholdColor,
      )
      ..drawRRect(
        body,
        Paint()
          ..color = _footholdEdgeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSize * 0.02,
      );

    if (isDamaged) {
      canvas.drawPath(_crackPath(body.outerRect), _crackPaint(cellSize));
    }
  }

  /// A jagged fracture across the foothold, so damage reads as damage rather
  /// than as a differently tinted terrain type.
  Path _crackPath(Rect body) {
    final left = body.left + body.width * 0.16;
    final right = body.right - body.width * 0.16;
    final top = body.top + body.height * 0.18;
    return Path()
      ..moveTo(left, top)
      ..lineTo(left + body.width * 0.22, body.center.dy)
      ..lineTo(body.center.dx, body.center.dy - body.height * 0.1)
      ..lineTo(
        body.center.dx + body.width * 0.14,
        body.bottom - body.height * 0.2,
      )
      ..lineTo(right, body.bottom - body.height * 0.12);
  }

  Paint _crackPaint(double cellSize) {
    return Paint()
      ..color = _crackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  /// Paints one piece.
  ///
  /// The two sides differ in silhouette as well as hue, so they stay
  /// separable when color alone is not available to the viewer.
  void _paintPiece(Canvas canvas, rust.GamePiece piece, double cellSize) {
    final center = Offset(
      (piece.x + 0.5) * cellSize,
      (piece.y + 0.5) * cellSize,
    );
    final radius = cellSize * 0.3;
    final body = switch (piece.owner) {
      rust.GamePlayer.first =>
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      rust.GamePlayer.second =>
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCircle(center: center, radius: radius),
            Radius.circular(radius * 0.32),
          ),
        ),
    };

    canvas
      ..drawPath(
        body,
        Paint()
          ..color = switch (piece.owner) {
            rust.GamePlayer.first => _firstPlayerColor,
            rust.GamePlayer.second => _secondPlayerColor,
          },
      )
      ..drawPath(
        body,
        Paint()
          ..color = _pieceEdgeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSize * 0.03,
      );

    if (piece.id == selectedPieceId) {
      canvas.drawCircle(
        center,
        cellSize * 0.4,
        Paint()
          ..color = _selectionColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSize * 0.07,
      );
    }
  }

  /// A move destination is a filled dot, a push destination a ring around the
  /// piece already standing there, so the two never read as the same action.
  void _paintDestination(
    Canvas canvas,
    ((int, int), DestinationKind) destination,
    double cellSize,
  ) {
    final (position, kind) = destination;
    final center = Offset(
      (position.$1 + 0.5) * cellSize,
      (position.$2 + 0.5) * cellSize,
    );

    switch (kind) {
      case DestinationKind.move:
        canvas.drawCircle(
          center,
          cellSize * 0.16,
          Paint()..color = _destinationColor,
        );
      case DestinationKind.push:
        canvas.drawCircle(
          center,
          cellSize * 0.37,
          Paint()
            ..color = _destinationColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = cellSize * 0.09,
        );
    }
  }

  Iterable<((int, int), DestinationKind)> _legalDestinations() sync* {
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
      final position = switch (move.direction) {
        rust.GameDirection.up => (piece.x, piece.y - 1),
        rust.GameDirection.down => (piece.x, piece.y + 1),
        rust.GameDirection.left => (piece.x - 1, piece.y),
        rust.GameDirection.right => (piece.x + 1, piece.y),
      };
      yield (position, _destinationKind(position));
    }
  }

  DestinationKind _destinationKind((int, int) position) {
    final isOccupied = snapshot.pieces.any(
      (piece) => piece.x == position.$1 && piece.y == position.$2,
    );
    return isOccupied ? DestinationKind.push : DestinationKind.move;
  }

  @override
  bool shouldRepaint(covariant _RoundBoardPainter oldDelegate) {
    return snapshot != oldDelegate.snapshot ||
        legalMoves != oldDelegate.legalMoves ||
        selectedPieceId != oldDelegate.selectedPieceId;
  }
}
