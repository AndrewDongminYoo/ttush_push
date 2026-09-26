import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

/// A decorative view of a non-empty catalog definition, without engine state.
class BoardPreview extends StatelessWidget {
  const BoardPreview({required this.definition, super.key});

  final rust.GameBoardDefinition definition;

  @override
  Widget build(BuildContext context) {
    final cells = definition.playableCells;
    final minX = cells.map((cell) => cell.x).reduce(math.min);
    final maxX = cells.map((cell) => cell.x).reduce(math.max);
    final minY = cells.map((cell) => cell.y).reduce(math.min);
    final maxY = cells.map((cell) => cell.y).reduce(math.max);
    final columns = maxX - minX + 1;
    final rows = maxY - minY + 1;
    final terrain = {
      for (final tile in definition.initialTiles ?? <rust.GameTile>[])
        (tile.x, tile.y): tile.kind,
    };
    final pieces = {
      for (final piece in definition.startingPieces)
        (piece.x, piece.y): piece.owner,
    };

    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: columns / rows,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = constraints.maxWidth / columns;
            return Stack(
              children: [
                for (final cell in cells)
                  Positioned(
                    key: ValueKey((cell.x, cell.y)),
                    left: (cell.x - minX) * cellSize,
                    top: (maxY - cell.y) * cellSize,
                    width: cellSize,
                    height: cellSize,
                    child: Padding(
                      padding: const EdgeInsets.all(1),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            _terrainAsset(
                              terrain[(cell.x, cell.y)] ??
                                  rust.GameTileKind.normal,
                            ),
                            cacheWidth: 96,
                          ),
                          if (pieces[(cell.x, cell.y)] case final owner?)
                            Image.asset(
                              owner == rust.GamePlayer.first
                                  ? 'assets/images/sprites/azure_explorer_up.png'
                                  : 'assets/images/sprites/ember_explorer_down.png',
                              cacheWidth: 96,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _terrainAsset(rust.GameTileKind kind) => switch (kind) {
  rust.GameTileKind.normal => 'assets/images/sprites/foothold_intact.png',
  rust.GameTileKind.damaged => 'assets/images/sprites/foothold_damaged.png',
  rust.GameTileKind.hole => 'assets/images/sprites/foothold_hole.png',
};
