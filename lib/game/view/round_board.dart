import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/l10n/l10n.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

/// How a legal destination is presented.
///
/// The distinction is read from the current snapshot, not derived from any
/// rule: a destination is a push when some piece already stands there. What
/// the push then does stays entirely in Rust.
enum DestinationKind { move, push }

/// Maps Rust tile coordinates onto the available paint region.
///
/// Bounds come from tiles rather than a presentation-owned board size, so a
/// future board may change shape, origin, or dimensions without changing
/// Flutter's coordinate math.
final class BoardGeometry {
  factory BoardGeometry.fromSnapshot(
    GameSnapshot snapshot,
    Size availableSize,
  ) {
    final tiles = snapshot.tiles;
    if (tiles.isEmpty ||
        !availableSize.width.isFinite ||
        !availableSize.height.isFinite ||
        availableSize.width <= 0 ||
        availableSize.height <= 0) {
      return BoardGeometry._empty();
    }

    final minX = tiles.map((tile) => tile.x).reduce(math.min);
    final maxX = tiles.map((tile) => tile.x).reduce(math.max);
    final minY = tiles.map((tile) => tile.y).reduce(math.min);
    final maxY = tiles.map((tile) => tile.y).reduce(math.max);
    final columnCount = maxX - minX + 1;
    final rowCount = maxY - minY + 1;
    final cellSize = math.min(
      availableSize.width / columnCount,
      availableSize.height / rowCount,
    );
    final boardSize = Size(cellSize * columnCount, cellSize * rowCount);
    final origin = Offset(
      (availableSize.width - boardSize.width) / 2,
      (availableSize.height - boardSize.height) / 2,
    );

    return BoardGeometry._(
      minX: minX,
      minY: minY,
      columnCount: columnCount,
      rowCount: rowCount,
      cellSize: cellSize,
      origin: origin,
    );
  }

  const BoardGeometry._({
    required this.minX,
    required this.minY,
    required this.columnCount,
    required this.rowCount,
    required this.cellSize,
    required this.origin,
  });

  factory BoardGeometry._empty() => const BoardGeometry._(
    minX: 0,
    minY: 0,
    columnCount: 0,
    rowCount: 0,
    cellSize: 0,
    origin: Offset.zero,
  );

  final int minX;
  final int minY;
  final int columnCount;
  final int rowCount;
  final double cellSize;
  final Offset origin;

  bool get hasCells => cellSize > 0;

  Rect cellRect(int x, int y) {
    return Rect.fromLTWH(
      origin.dx + (x - minX) * cellSize,
      origin.dy + _visualRowFor(y) * cellSize,
      cellSize,
      cellSize,
    );
  }

  Offset cellCenter(int x, int y) => cellRect(x, y).center;

  (int, int)? cellAt(Offset point) {
    if (!hasCells) {
      return null;
    }
    final localX = point.dx - origin.dx;
    final localY = point.dy - origin.dy;
    final boardWidth = cellSize * columnCount;
    final boardHeight = cellSize * rowCount;
    if (localX < 0 ||
        localY < 0 ||
        localX >= boardWidth ||
        localY >= boardHeight) {
      return null;
    }
    return (
      minX + (localX / cellSize).floor(),
      minY + rowCount - 1 - (localY / cellSize).floor(),
    );
  }

  int _visualRowFor(int y) => rowCount - 1 - (y - minY);
}

/// Rust-authored move facts being replayed over the currently visible board.
final class BoardPlayback {
  const BoardPlayback({
    required this.resolution,
    required this.progress,
    required this.reducedMotion,
  });

  final rust.MoveResolution resolution;
  final double progress;
  final bool reducedMotion;
}

final class RoundBoard extends StatelessWidget {
  const RoundBoard({
    required this.snapshot,
    required this.legalMoves,
    required this.selectedPieceId,
    required this.onCellTap,
    this.playback,
    super.key,
  });

  final GameSnapshot snapshot;
  final List<GameMove> legalMoves;
  final int? selectedPieceId;
  final void Function(int x, int y)? onCellTap;
  final BoardPlayback? playback;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = BoardGeometry.fromSnapshot(
          snapshot,
          constraints.biggest,
        );
        if (!geometry.hasCells) {
          return const SizedBox.shrink();
        }
        final l10n =
            Localizations.of<AppLocalizations>(context, AppLocalizations) ??
            lookupAppLocalizations(const Locale('en'));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapUp: onCellTap == null
              ? null
              : (details) {
                  final cell = geometry.cellAt(details.localPosition);
                  if (cell != null &&
                      snapshot.tiles.any(
                        (tile) => tile.x == cell.$1 && tile.y == cell.$2,
                      )) {
                    onCellTap!(cell.$1, cell.$2);
                  }
                },
          child: SizedBox.expand(
            child: CustomPaint(
              key: const Key('round-board-canvas'),
              painter: _RoundBoardPainter(
                snapshot: snapshot,
                legalMoves: legalMoves,
                selectedPieceId: selectedPieceId,
                geometry: geometry,
                playback: playback,
                onCellTap: onCellTap,
                l10n: l10n,
                textDirection: Directionality.of(context),
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
    required this.geometry,
    required this.playback,
    required this.onCellTap,
    required this.l10n,
    required this.textDirection,
  });

  static const _footholdColor = Color(0xFFE7ECF5);
  static const _slabShadowColor = Color(0xFFC5CBD6);
  static const _damagedFootholdColor = Color(0xFFF3CE8E);
  static const _damagedSlabShadowColor = Color(0xFFD9AF68);
  static const _crackColor = Color(0xFF6B4A16);
  static const _footholdEdgeColor = Color(0xFFA9B4C6);
  static const _firstPlayerColor = Color(0xFF2A48DF);
  static const _secondPlayerColor = Color(0xFFE14B4B);
  static const _pieceEdgeColor = Color(0xFF0B0D12);
  static const _selectionColor = Color(0xFFFFD54F);
  static const _destinationColor = Color(0xFF53D769);
  static const _pushArrival = 0.36;
  static const _pushImpactEnd = 0.5;
  static const _pushDisplacementEnd = 0.8;
  static const _pushTransitionStart = 0.84;
  static const _normalArrival = 0.64;
  static const _normalTransitionStart = 0.76;

  final GameSnapshot snapshot;
  final List<GameMove> legalMoves;
  final int? selectedPieceId;
  final BoardGeometry geometry;
  final BoardPlayback? playback;
  final void Function(int x, int y)? onCellTap;
  final AppLocalizations l10n;
  final TextDirection textDirection;

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final onCellTap = this.onCellTap;
    if (playback != null) {
      return [
        CustomPainterSemantics(
          rect: Offset.zero & size,
          properties: SemanticsProperties(
            label: l10n.boardControlsDisabled,
            textDirection: textDirection,
            enabled: false,
            liveRegion: true,
          ),
        ),
      ];
    }
    if (onCellTap == null) {
      return const [];
    }

    final semantics = <CustomPainterSemantics>[];
    for (final piece in snapshot.pieces) {
      final moveCount = legalMoves
          .where((move) => move.pieceId == piece.id)
          .length;
      if (piece.owner != snapshot.currentPlayer || moveCount == 0) {
        continue;
      }
      semantics.add(
        CustomPainterSemantics(
          rect: geometry.cellRect(piece.x, piece.y),
          properties: SemanticsProperties(
            label: l10n.explorerSemanticsLabel(
              _expeditionLabel(piece.owner),
              _semanticRow(piece.y),
              _semanticColumn(piece.x),
              moveCount,
            ),
            textDirection: textDirection,
            button: true,
            selected: piece.id == selectedPieceId,
            onTap: () => onCellTap(piece.x, piece.y),
          ),
        ),
      );
    }

    final selectedPieceIndex = snapshot.pieces.indexWhere(
      (piece) => piece.id == selectedPieceId,
    );
    if (selectedPieceIndex == -1) {
      return semantics;
    }
    final selectedPiece = snapshot.pieces[selectedPieceIndex];
    for (final move in legalMoves) {
      if (move.pieceId != selectedPiece.id) {
        continue;
      }
      final position = _destinationPosition(selectedPiece, move.direction);
      final kind = _destinationKind(position);
      final label = switch (kind) {
        DestinationKind.move => l10n.moveDestinationSemanticsLabel(
          _directionLabel(move.direction),
          _semanticRow(position.$2),
          _semanticColumn(position.$1),
        ),
        DestinationKind.push => l10n.pushDestinationSemanticsLabel(
          _directionLabel(move.direction),
          _semanticRow(position.$2),
          _semanticColumn(position.$1),
          _expeditionLabel(
            snapshot.pieces
                .firstWhere(
                  (piece) => piece.x == position.$1 && piece.y == position.$2,
                )
                .owner,
          ),
        ),
      };
      semantics.add(
        CustomPainterSemantics(
          rect: geometry.cellRect(position.$1, position.$2),
          properties: SemanticsProperties(
            label: label,
            textDirection: textDirection,
            button: true,
            onTap: () => onCellTap(position.$1, position.$2),
          ),
        ),
      );
    }
    return semantics;
  };

  String _expeditionLabel(rust.GamePlayer player) => switch (player) {
    rust.GamePlayer.first => l10n.azureExpedition,
    rust.GamePlayer.second => l10n.emberExpedition,
  };

  // Painted rows invert Rust y coordinates, so vertical labels invert too.
  String _directionLabel(rust.GameDirection direction) => switch (direction) {
    rust.GameDirection.up => l10n.directionDown,
    rust.GameDirection.down => l10n.directionUp,
    rust.GameDirection.left => l10n.directionLeft,
    rust.GameDirection.right => l10n.directionRight,
  };

  int _semanticRow(int y) => geometry._visualRowFor(y) + 1;

  int _semanticColumn(int x) => x - geometry.minX + 1;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    final playback = this.playback;
    final movingPieceId = playback?.resolution.mover.pieceId;
    final displacedPieceId = playback?.resolution.displaced?.pieceId;

    for (final tile in snapshot.tiles) {
      _paintTile(canvas, tile);
    }
    for (final piece in snapshot.pieces) {
      if (piece.id == movingPieceId || piece.id == displacedPieceId) {
        continue;
      }
      _paintPiece(canvas, piece);
    }
    // Destinations paint last so an occupied one stays visible.
    for (final destination in _legalDestinations()) {
      _paintDestination(canvas, destination);
    }
    if (playback != null) {
      _paintPlayback(canvas, playback);
    }
    canvas.restore();
  }

  /// Paints one foothold.
  ///
  /// A hole is the absence of a foothold rather than a differently colored
  /// one, so nothing is drawn and the void behind the board shows through.
  void _paintTile(Canvas canvas, rust.GameTile tile) {
    if (tile.kind == rust.GameTileKind.hole) {
      return;
    }

    final cellRect = geometry.cellRect(tile.x, tile.y);
    final cellSize = geometry.cellSize;
    final inset = cellSize * 0.06;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        cellRect.left + inset,
        cellRect.top + inset,
        cellRect.width - inset * 2,
        cellRect.height - inset * 2,
      ),
      Radius.circular(cellSize * 0.12),
    );
    final isDamaged = tile.kind == rust.GameTileKind.damaged;

    canvas
      ..drawRRect(
        body,
        Paint()..color = isDamaged ? _damagedFootholdColor : _footholdColor,
      )
      ..drawPath(
        _slabFacet(body.outerRect, cellSize),
        Paint()..color = isDamaged ? _damagedSlabShadowColor : _slabShadowColor,
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

  Path _slabFacet(Rect body, double cellSize) {
    final top = body.bottom - cellSize * 0.24;
    final bottom = body.bottom - cellSize * 0.055;
    return Path()
      ..moveTo(body.left + cellSize * 0.08, top)
      ..lineTo(body.right - cellSize * 0.08, top)
      ..lineTo(body.right - cellSize * 0.14, bottom)
      ..lineTo(body.left + cellSize * 0.14, bottom)
      ..close();
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
  void _paintPiece(Canvas canvas, rust.GamePiece piece) {
    final center = geometry.cellCenter(piece.x, piece.y);
    _paintPieceAt(canvas, piece, center);
  }

  void _paintPieceAt(Canvas canvas, rust.GamePiece piece, Offset center) {
    final cellSize = geometry.cellSize;
    final body = switch (piece.owner) {
      rust.GamePlayer.first => _azureExplorerPath(center, cellSize),
      rust.GamePlayer.second => _emberExplorerPath(center, cellSize),
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

  /// Azure wears a broad, rounded travel cloak beneath a round head.
  Path _azureExplorerPath(Offset center, double cellSize) {
    final head = Rect.fromCircle(
      center: center.translate(0, -cellSize * 0.19),
      radius: cellSize * 0.13,
    );
    final cloakTop = center.dy - cellSize * 0.04;
    final cloakHem = center.dy + cellSize * 0.42;
    return Path()
      ..addOval(head)
      ..moveTo(center.dx - cellSize * 0.14, cloakTop)
      ..lineTo(center.dx - cellSize * 0.28, cloakHem)
      ..lineTo(center.dx + cellSize * 0.28, cloakHem)
      ..lineTo(center.dx + cellSize * 0.14, cloakTop)
      ..close();
  }

  /// Ember's angular hood and narrow robe remain distinct from Azure's cloak.
  Path _emberExplorerPath(Offset center, double cellSize) {
    final hoodTop = center.dy - cellSize * 0.34;
    final hoodBase = center.dy - cellSize * 0.03;
    final robeHem = center.dy + cellSize * 0.42;
    return Path()
      ..moveTo(center.dx, hoodTop)
      ..lineTo(center.dx - cellSize * 0.16, hoodBase)
      ..lineTo(center.dx, center.dy + cellSize * 0.06)
      ..lineTo(center.dx + cellSize * 0.16, hoodBase)
      ..close()
      ..moveTo(center.dx - cellSize * 0.1, hoodBase)
      ..lineTo(center.dx - cellSize * 0.1, robeHem)
      ..lineTo(center.dx + cellSize * 0.1, robeHem)
      ..lineTo(center.dx + cellSize * 0.1, hoodBase)
      ..close();
  }

  void _paintPlayback(Canvas canvas, BoardPlayback playback) {
    final resolution = playback.resolution;
    final isPush = resolution.actionKind == rust.MoveActionKind.push;
    final moverIndex = snapshot.pieces.indexWhere(
      (piece) => piece.id == resolution.mover.pieceId,
    );
    if (moverIndex == -1) {
      return;
    }

    _paintPieceAt(
      canvas,
      snapshot.pieces[moverIndex],
      _travelCenter(
        fromX: resolution.mover.fromX,
        fromY: resolution.mover.fromY,
        toX: resolution.mover.toX,
        toY: resolution.mover.toY,
        progress: _phaseProgress(
          playback.progress,
          end: isPush ? _pushArrival : _normalArrival,
        ),
        reducedMotion: playback.reducedMotion,
      ),
    );

    if (isPush) {
      _paintPushImpact(canvas, resolution, playback.progress);
      final displaced = resolution.displaced;
      if (displaced != null) {
        final displacedIndex = snapshot.pieces.indexWhere(
          (piece) => piece.id == displaced.pieceId,
        );
        if (displacedIndex != -1) {
          _paintPieceAt(
            canvas,
            snapshot.pieces[displacedIndex],
            _displacementCenter(displaced, playback),
          );
        }
      }
    }

    final transitionStart = isPush
        ? _pushTransitionStart
        : _normalTransitionStart;
    if (playback.progress >= transitionStart) {
      _paintTransition(canvas, resolution.tileTransition);
    }
  }

  double _phaseProgress(double progress, {required double end}) {
    return (progress / end).clamp(0.0, 1.0);
  }

  Offset _travelCenter({
    required int fromX,
    required int fromY,
    required int toX,
    required int toY,
    required double progress,
    required bool reducedMotion,
  }) {
    final from = geometry.cellCenter(fromX, fromY);
    final to = geometry.cellCenter(toX, toY);
    if (reducedMotion) {
      return progress < 0.5 ? from : to;
    }
    return Offset.lerp(from, to, progress)!;
  }

  Offset _displacementCenter(
    rust.PieceDisplacement displacement,
    BoardPlayback playback,
  ) {
    final from = geometry.cellCenter(displacement.fromX, displacement.fromY);
    if (playback.progress < _pushImpactEnd) {
      return from;
    }
    final progress = _phaseProgress(
      playback.progress - _pushImpactEnd,
      end: _pushDisplacementEnd - _pushImpactEnd,
    );
    final to = switch ((displacement.toX, displacement.toY)) {
      (final int x, final int y) => geometry.cellCenter(x, y),
      _ => _fallCenter(displacement),
    };
    if (playback.reducedMotion) {
      return progress < 0.5 ? from : to;
    }
    return Offset.lerp(from, to, progress)!;
  }

  Offset _fallCenter(rust.PieceDisplacement displacement) {
    final from = geometry.cellCenter(displacement.fromX, displacement.fromY);
    final direction = displacement.exitDirection!;
    final distance = geometry.cellSize * 1.3;
    return switch (direction) {
      rust.GameDirection.up => from.translate(0, distance),
      rust.GameDirection.down => from.translate(0, -distance),
      rust.GameDirection.left => from.translate(-distance, 0),
      rust.GameDirection.right => from.translate(distance, 0),
    };
  }

  void _paintPushImpact(
    Canvas canvas,
    rust.MoveResolution resolution,
    double progress,
  ) {
    if (progress < _pushArrival || progress > _pushImpactEnd) {
      return;
    }
    final impact = geometry.cellCenter(
      resolution.mover.toX,
      resolution.mover.toY,
    );
    final impactProgress =
        (progress - _pushArrival) / (_pushImpactEnd - _pushArrival);
    final alpha = 1 - (impactProgress - 0.5).abs() * 2;
    canvas.drawCircle(
      impact,
      geometry.cellSize * 0.42,
      Paint()
        ..color = _selectionColor.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.cellSize * 0.05,
    );
  }

  void _paintTransition(Canvas canvas, rust.TileTransition transition) {
    if (transition.to == rust.GameTileKind.hole) {
      canvas.drawRect(
        geometry.cellRect(transition.x, transition.y),
        Paint()..blendMode = BlendMode.clear,
      );
      return;
    }
    _paintTile(
      canvas,
      rust.GameTile(x: transition.x, y: transition.y, kind: transition.to),
    );
  }

  /// A move destination is a filled dot, a push destination a ring around the
  /// piece already standing there, so the two never read as the same action.
  void _paintDestination(
    Canvas canvas,
    ((int, int), DestinationKind) destination,
  ) {
    final (position, kind) = destination;
    final cellSize = geometry.cellSize;
    final center = geometry.cellCenter(position.$1, position.$2);

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
      final position = _destinationPosition(piece, move.direction);
      yield (position, _destinationKind(position));
    }
  }

  (int, int) _destinationPosition(
    rust.GamePiece piece,
    rust.GameDirection direction,
  ) {
    return switch (direction) {
      rust.GameDirection.up => (piece.x, piece.y - 1),
      rust.GameDirection.down => (piece.x, piece.y + 1),
      rust.GameDirection.left => (piece.x - 1, piece.y),
      rust.GameDirection.right => (piece.x + 1, piece.y),
    };
  }

  DestinationKind _destinationKind((int, int) position) {
    final isOccupied = snapshot.pieces.any(
      (piece) => piece.x == position.$1 && piece.y == position.$2,
    );
    return isOccupied ? DestinationKind.push : DestinationKind.move;
  }

  @override
  bool shouldRepaint(covariant _RoundBoardPainter oldDelegate) {
    return playback != oldDelegate.playback ||
        snapshot != oldDelegate.snapshot ||
        legalMoves != oldDelegate.legalMoves ||
        selectedPieceId != oldDelegate.selectedPieceId ||
        geometry != oldDelegate.geometry;
  }

  @override
  bool shouldRebuildSemantics(covariant _RoundBoardPainter oldDelegate) {
    return onCellTap != oldDelegate.onCellTap ||
        l10n != oldDelegate.l10n ||
        textDirection != oldDelegate.textDirection ||
        shouldRepaint(oldDelegate);
  }
}
