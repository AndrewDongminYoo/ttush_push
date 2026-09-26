import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/board/board_definition.dart';

void main() {
  group('BuiltInBoard', () {
    test('uses stable catalog IDs and their definitions', () {
      expect(BuiltInBoard.values.map((board) => board.id), [
        'baseline',
        'clipped-corners',
        'large',
        'large-holes',
      ]);
      expect(BuiltInBoard.baseline.definition, same(baselineBoardDefinition));
      expect(
        BuiltInBoard.clippedCorners.definition,
        same(clippedCornersBoardDefinition),
      );
      expect(BuiltInBoard.large.definition, same(largeBoardDefinition));
      expect(
        BuiltInBoard.largeHoles.definition,
        same(largeHolesBoardDefinition),
      );
    });

    for (final board in [BuiltInBoard.large, BuiltInBoard.largeHoles]) {
      test('${board.id} has the exact seven-by-seven six-piece opening', () {
        final definition = board.definition;
        expect(definition.rules.playableCells, hasLength(49));
        expect(
          _cellCoordinates(definition),
          unorderedEquals([
            for (var x = 0; x < 7; x++)
              for (var y = 0; y < 7; y++) '$x,$y',
          ]),
        );
        expect(_pieceCoordinates(definition), [
          '0:first:1,1',
          '1:first:3,1',
          '2:first:5,1',
          '3:second:1,5',
          '4:second:3,5',
          '5:second:5,5',
        ]);
        expect(
          definition.rules.initialTiles?.map(
                (tile) => '${tile.x},${tile.y}:${tile.kind.name}',
              ) ??
              <String>[],
          board == BuiltInBoard.largeHoles
              ? ['1,3:hole', '3,3:hole', '5,3:hole']
              : isEmpty,
        );
      });
    }

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
