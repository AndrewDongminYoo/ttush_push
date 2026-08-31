import 'package:flutter/material.dart';
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
    // The first seat opens on turn, which its mark says with a white outline.
    final mark = tester.widget<Container>(
      find.byKey(const Key('player-mark-first')),
    );
    final decoration = mark.decoration! as BoxDecoration;

    expect((decoration.border! as Border).top.color, Colors.white);
  });
}
