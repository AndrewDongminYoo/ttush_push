import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/board/board_definition.dart';
import 'package:ttush_push/game/start/board_preview.dart';
import 'package:ttush_push/src/rust/api.dart';

void main() {
  Future<void> show(WidgetTester tester, GameBoardDefinition definition) =>
      tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 140,
              child: BoardPreview(definition: definition),
            ),
          ),
        ),
      );

  Finder asset(String name) => find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        ((widget.image as ResizeImage).imageProvider as AssetImage).assetName
            .endsWith(name),
  );

  testWidgets('previews holes, six pieces and the match orientation', (
    tester,
  ) async {
    await show(tester, BuiltInBoard.largeHoles.definition.rules);
    expect(find.byType(Positioned), findsNWidgets(49));
    expect(asset('foothold_hole.png'), findsNWidgets(3));
    expect(asset('foothold_intact.png'), findsNWidgets(46));
    expect(asset('azure_explorer_up.png'), findsNWidgets(3));
    expect(asset('ember_explorer_down.png'), findsNWidgets(3));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey((1, 1)))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey((1, 5)))).dy),
    );
    for (final x in [1, 3, 5]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey((x, 3))),
          matching: asset('foothold_hole.png'),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('omits clipped corners instead of depicting holes', (
    tester,
  ) async {
    await show(tester, BuiltInBoard.clippedCorners.definition.rules);
    expect(find.byType(Positioned), findsNWidgets(21));
    expect(asset('foothold_hole.png'), findsNothing);
    expect(find.byKey(const ValueKey((0, 0))), findsNothing);
  });

  testWidgets('renders a damaged initial tile from the definition', (
    tester,
  ) async {
    await show(
      tester,
      const GameBoardDefinition(
        playableCells: [GameBoardCell(x: 0, y: 0)],
        startingPieces: [],
        initialTiles: [GameTile(x: 0, y: 0, kind: GameTileKind.damaged)],
      ),
    );
    expect(asset('foothold_damaged.png'), findsOneWidget);
    expect(asset('foothold_intact.png'), findsNothing);
  });
}
