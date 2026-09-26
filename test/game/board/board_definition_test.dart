import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/board/board_definition.dart';

void main() {
  group('BuiltInBoard', () {
    test('uses stable catalog IDs and their definitions', () {
      expect(BuiltInBoard.values.map((board) => board.id), [
        'baseline',
        'clipped-corners',
      ]);
      expect(BuiltInBoard.baseline.definition, same(baselineBoardDefinition));
      expect(
        BuiltInBoard.clippedCorners.definition,
        same(clippedCornersBoardDefinition),
      );
    });

    test('keeps the complete baseline board and starting pieces', () {
      final definition = BuiltInBoard.baseline.definition;

      expect(
        definition.backgroundAssetPath,
        'assets/images/air_ruins_twilight.png',
      );
      expect(definition.rules.playableCells, hasLength(25));
      expect(
        _cellCoordinates(definition),
        unorderedEquals([
          for (var x = 0; x < 5; x++)
            for (var y = 0; y < 5; y++) '$x,$y',
        ]),
      );
      expect(_pieceCoordinates(definition), _baselinePieces);
    });

    test(
      'clips only the four corners and keeps the baseline starting pieces',
      () {
        final definition = BuiltInBoard.clippedCorners.definition;

        expect(
          definition.backgroundAssetPath,
          baselineBoardDefinition.backgroundAssetPath,
        );
        expect(definition.rules.playableCells, hasLength(21));
        expect(
          _cellCoordinates(definition),
          unorderedEquals([
            for (var x = 0; x < 5; x++)
              for (var y = 0; y < 5; y++)
                if (!((x == 0 || x == 4) && (y == 0 || y == 4))) '$x,$y',
          ]),
        );
        expect(_pieceCoordinates(definition), _baselinePieces);
      },
    );
  });
}

const _baselinePieces = [
  '0:first:1,0',
  '1:first:3,0',
  '2:second:1,4',
  '3:second:3,4',
];

List<String> _cellCoordinates(BoardDefinition definition) => [
  for (final cell in definition.rules.playableCells) '${cell.x},${cell.y}',
];

List<String> _pieceCoordinates(BoardDefinition definition) => [
  for (final piece in definition.rules.startingPieces)
    '${piece.id}:${piece.owner.name}:${piece.x},${piece.y}',
];
