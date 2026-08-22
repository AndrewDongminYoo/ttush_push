import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/app/app.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/src/rust/api.dart';

import '../../support/match_fixtures.dart';

void main() {
  testWidgets('opens directly to the playable round', (tester) async {
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

    expect(find.byType(GamePage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('player-panel-first')),
        matching: find.text('Your turn'),
      ),
      findsOneWidget,
    );
  });
}
