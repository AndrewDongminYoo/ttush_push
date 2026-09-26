import 'package:ttush_push/src/rust/api.dart' as rust;

final class BoardDefinition {
  const BoardDefinition({
    required this.backgroundAssetPath,
    required this.rules,
  });

  final String backgroundAssetPath;
  final rust.GameBoardDefinition rules;
}

const baselineBoardDefinition = BoardDefinition(
  backgroundAssetPath: 'assets/images/air_ruins_twilight.png',
  rules: rust.GameBoardDefinition(
    playableCells: [
      rust.GameBoardCell(x: 0, y: 0),
      rust.GameBoardCell(x: 0, y: 1),
      rust.GameBoardCell(x: 0, y: 2),
      rust.GameBoardCell(x: 0, y: 3),
      rust.GameBoardCell(x: 0, y: 4),
      rust.GameBoardCell(x: 1, y: 0),
      rust.GameBoardCell(x: 1, y: 1),
      rust.GameBoardCell(x: 1, y: 2),
      rust.GameBoardCell(x: 1, y: 3),
      rust.GameBoardCell(x: 1, y: 4),
      rust.GameBoardCell(x: 2, y: 0),
      rust.GameBoardCell(x: 2, y: 1),
      rust.GameBoardCell(x: 2, y: 2),
      rust.GameBoardCell(x: 2, y: 3),
      rust.GameBoardCell(x: 2, y: 4),
      rust.GameBoardCell(x: 3, y: 0),
      rust.GameBoardCell(x: 3, y: 1),
      rust.GameBoardCell(x: 3, y: 2),
      rust.GameBoardCell(x: 3, y: 3),
      rust.GameBoardCell(x: 3, y: 4),
      rust.GameBoardCell(x: 4, y: 0),
      rust.GameBoardCell(x: 4, y: 1),
      rust.GameBoardCell(x: 4, y: 2),
      rust.GameBoardCell(x: 4, y: 3),
      rust.GameBoardCell(x: 4, y: 4),
    ],
    startingPieces: [
      rust.GamePiece(id: 0, owner: rust.GamePlayer.first, x: 1, y: 0),
      rust.GamePiece(id: 1, owner: rust.GamePlayer.first, x: 3, y: 0),
      rust.GamePiece(id: 2, owner: rust.GamePlayer.second, x: 1, y: 4),
      rust.GamePiece(id: 3, owner: rust.GamePlayer.second, x: 3, y: 4),
    ],
  ),
);

const clippedCornersBoardDefinition = BoardDefinition(
  backgroundAssetPath: 'assets/images/air_ruins_twilight.png',
  rules: rust.GameBoardDefinition(
    playableCells: [
      rust.GameBoardCell(x: 0, y: 1),
      rust.GameBoardCell(x: 0, y: 2),
      rust.GameBoardCell(x: 0, y: 3),
      rust.GameBoardCell(x: 1, y: 0),
      rust.GameBoardCell(x: 1, y: 1),
      rust.GameBoardCell(x: 1, y: 2),
      rust.GameBoardCell(x: 1, y: 3),
      rust.GameBoardCell(x: 1, y: 4),
      rust.GameBoardCell(x: 2, y: 0),
      rust.GameBoardCell(x: 2, y: 1),
      rust.GameBoardCell(x: 2, y: 2),
      rust.GameBoardCell(x: 2, y: 3),
      rust.GameBoardCell(x: 2, y: 4),
      rust.GameBoardCell(x: 3, y: 0),
      rust.GameBoardCell(x: 3, y: 1),
      rust.GameBoardCell(x: 3, y: 2),
      rust.GameBoardCell(x: 3, y: 3),
      rust.GameBoardCell(x: 3, y: 4),
      rust.GameBoardCell(x: 4, y: 1),
      rust.GameBoardCell(x: 4, y: 2),
      rust.GameBoardCell(x: 4, y: 3),
    ],
    startingPieces: [
      rust.GamePiece(id: 0, owner: rust.GamePlayer.first, x: 1, y: 0),
      rust.GamePiece(id: 1, owner: rust.GamePlayer.first, x: 3, y: 0),
      rust.GamePiece(id: 2, owner: rust.GamePlayer.second, x: 1, y: 4),
      rust.GamePiece(id: 3, owner: rust.GamePlayer.second, x: 3, y: 4),
    ],
  ),
);

const _largeBoardCells = <rust.GameBoardCell>[
  rust.GameBoardCell(x: 0, y: 0),
  rust.GameBoardCell(x: 0, y: 1),
  rust.GameBoardCell(x: 0, y: 2),
  rust.GameBoardCell(x: 0, y: 3),
  rust.GameBoardCell(x: 0, y: 4),
  rust.GameBoardCell(x: 0, y: 5),
  rust.GameBoardCell(x: 0, y: 6),
  rust.GameBoardCell(x: 1, y: 0),
  rust.GameBoardCell(x: 1, y: 1),
  rust.GameBoardCell(x: 1, y: 2),
  rust.GameBoardCell(x: 1, y: 3),
  rust.GameBoardCell(x: 1, y: 4),
  rust.GameBoardCell(x: 1, y: 5),
  rust.GameBoardCell(x: 1, y: 6),
  rust.GameBoardCell(x: 2, y: 0),
  rust.GameBoardCell(x: 2, y: 1),
  rust.GameBoardCell(x: 2, y: 2),
  rust.GameBoardCell(x: 2, y: 3),
  rust.GameBoardCell(x: 2, y: 4),
  rust.GameBoardCell(x: 2, y: 5),
  rust.GameBoardCell(x: 2, y: 6),
  rust.GameBoardCell(x: 3, y: 0),
  rust.GameBoardCell(x: 3, y: 1),
  rust.GameBoardCell(x: 3, y: 2),
  rust.GameBoardCell(x: 3, y: 3),
  rust.GameBoardCell(x: 3, y: 4),
  rust.GameBoardCell(x: 3, y: 5),
  rust.GameBoardCell(x: 3, y: 6),
  rust.GameBoardCell(x: 4, y: 0),
  rust.GameBoardCell(x: 4, y: 1),
  rust.GameBoardCell(x: 4, y: 2),
  rust.GameBoardCell(x: 4, y: 3),
  rust.GameBoardCell(x: 4, y: 4),
  rust.GameBoardCell(x: 4, y: 5),
  rust.GameBoardCell(x: 4, y: 6),
  rust.GameBoardCell(x: 5, y: 0),
  rust.GameBoardCell(x: 5, y: 1),
  rust.GameBoardCell(x: 5, y: 2),
  rust.GameBoardCell(x: 5, y: 3),
  rust.GameBoardCell(x: 5, y: 4),
  rust.GameBoardCell(x: 5, y: 5),
  rust.GameBoardCell(x: 5, y: 6),
  rust.GameBoardCell(x: 6, y: 0),
  rust.GameBoardCell(x: 6, y: 1),
  rust.GameBoardCell(x: 6, y: 2),
  rust.GameBoardCell(x: 6, y: 3),
  rust.GameBoardCell(x: 6, y: 4),
  rust.GameBoardCell(x: 6, y: 5),
  rust.GameBoardCell(x: 6, y: 6),
];

const _largeStartingPieces = <rust.GamePiece>[
  rust.GamePiece(id: 0, owner: rust.GamePlayer.first, x: 1, y: 1),
  rust.GamePiece(id: 1, owner: rust.GamePlayer.first, x: 3, y: 1),
  rust.GamePiece(id: 2, owner: rust.GamePlayer.first, x: 5, y: 1),
  rust.GamePiece(id: 3, owner: rust.GamePlayer.second, x: 1, y: 5),
  rust.GamePiece(id: 4, owner: rust.GamePlayer.second, x: 3, y: 5),
  rust.GamePiece(id: 5, owner: rust.GamePlayer.second, x: 5, y: 5),
];

const largeBoardDefinition = BoardDefinition(
  backgroundAssetPath: 'assets/images/air_ruins_twilight.png',
  rules: rust.GameBoardDefinition(
    playableCells: _largeBoardCells,
    startingPieces: _largeStartingPieces,
  ),
);

const largeHolesBoardDefinition = BoardDefinition(
  backgroundAssetPath: 'assets/images/air_ruins_twilight.png',
  rules: rust.GameBoardDefinition(
    playableCells: _largeBoardCells,
    startingPieces: _largeStartingPieces,
    initialTiles: [
      rust.GameTile(x: 1, y: 3, kind: rust.GameTileKind.hole),
      rust.GameTile(x: 3, y: 3, kind: rust.GameTileKind.hole),
      rust.GameTile(x: 5, y: 3, kind: rust.GameTileKind.hole),
    ],
  ),
);

enum BuiltInBoard {
  baseline('baseline', baselineBoardDefinition),
  clippedCorners('clipped-corners', clippedCornersBoardDefinition),
  large('large', largeBoardDefinition),
  largeHoles('large-holes', largeHolesBoardDefinition);

  const BuiltInBoard(this.id, this.definition);

  final String id;
  final BoardDefinition definition;
}
