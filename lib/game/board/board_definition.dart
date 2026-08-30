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
