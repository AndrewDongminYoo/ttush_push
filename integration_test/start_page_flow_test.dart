import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ttush_push/app/view/app.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/src/rust/api.dart';
import 'package:ttush_push/src/rust/frb_generated.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(RustLib.init);
  tearDownAll(RustLib.dispose);
  final previous = WidgetController.hitTestWarningShouldBeFatal;
  WidgetController.hitTestWarningShouldBeFatal = true;
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = previous);

  for (final locale in ['en', 'ko']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$locale setup at text scale $scale', (tester) async {
        tester.binding.platformDispatcher.localesTestValue = [Locale(locale)];
        tester.binding.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
        addTearDown(
          tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
        );
        final prefix = 'setup-refresh-$locale-${scale.toInt()}';
        await tester.pumpWidget(App(key: ValueKey(prefix)));
        await tester.pumpAndSettle();
        if (Platform.isAndroid) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pump();
        }
        await _capture(tester, binding, '$prefix-top');
        Future<void> choose(String key) async {
          final target = find.byKey(Key(key));
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('start-match')).hitTestable(),
            findsOneWidget,
          );
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        await choose('start-mode-versus-ai');
        await choose('start-difficulty-strategic');
        await _capture(tester, binding, '$prefix-ai');
        for (final board in [
          'baseline',
          'clipped-corners',
          'large',
          'large-holes',
        ]) {
          await choose('start-board-$board');
        }
        await _capture(tester, binding, '$prefix-boards');
        await tester.tap(find.byKey(const Key('start-match')));
        for (
          var frame = 0;
          frame < 100 && find.byType(RoundBoard).evaluate().isEmpty;
          frame++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(RoundBoard), findsOneWidget);
        final board = tester.widget<RoundBoard>(find.byType(RoundBoard));
        expect(board.snapshot.tiles, hasLength(49));
        expect(board.snapshot.pieces, hasLength(6));
        expect(
          board.snapshot.tiles.where((tile) => tile.kind == GameTileKind.hole),
          hasLength(3),
        );
        await tester.pumpAndSettle();
        final coach = find.byKey(const Key('coach-dismiss'));
        if (coach.evaluate().isNotEmpty) {
          await tester.tap(coach);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('leave-match')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('leave-match-confirm')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('start-match')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<void> _capture(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  // A settled widget tree can precede asynchronous asset decoding on iOS.
  for (var frame = 0; frame < 100; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    final images = tester.widgetList<RawImage>(find.byType(RawImage));
    if (images.isNotEmpty && images.every((image) => image.image != null)) {
      await binding.takeScreenshot(name);
      return;
    }
  }
  fail('Setup images did not finish decoding before $name');
}
