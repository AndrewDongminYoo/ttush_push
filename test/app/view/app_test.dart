import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/app/app.dart';
import 'package:ttush_push/game/start/start_page.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/src/rust/api.dart';

import '../../support/match_fixtures.dart';

void main() {
  testWidgets('uses Korean strings for the Korean system locale', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('ko')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'initial',
    );

    await tester.pumpWidget(
      App(
        rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot)),
      ),
    );

    expect(find.text('새 매치'), findsOneWidget);
    expect(find.text('2인 플레이'), findsOneWidget);
    expect(find.text('AI 대전'), findsOneWidget);
    expect(find.text('매치 시작'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('start-match')));
    await tester.pumpAndSettle();

    expect(find.text('푸른 원정대'), findsOneWidget);
    expect(find.text('불씨 원정대'), findsOneWidget);
    expect(find.text('푸른 원정대의 탐험가를 선택하세요.'), findsOneWidget);
    expect(find.text('상대: 사람'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens on match setup rather than on the board', (tester) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'initial',
    );

    await tester.pumpWidget(
      App(
        rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot)),
      ),
    );

    expect(find.byType(StartPage), findsOneWidget);
    expect(find.byType(GamePage), findsNothing);

    await tester.tap(find.byKey(const Key('start-match')));
    await tester.pumpAndSettle();

    expect(find.byType(GamePage), findsOneWidget);
    // The first seat opens on turn, which its mark says with a white outline.
    final mark = tester.widget<Container>(
      find.byKey(const Key('player-mark-first')),
    );
    final decoration = mark.decoration! as BoxDecoration;

    expect((decoration.border! as Border).top.color, Colors.white);
  });
}
