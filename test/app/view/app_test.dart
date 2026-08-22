import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/app/app.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/src/rust/api.dart';

void main() {
  testWidgets('opens directly to the playable round', (tester) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'initial',
    );

    await tester.pumpWidget(
      const App(
        rulesEngine: _FakeRulesEngine(snapshot: snapshot),
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

final class _FakeRulesEngine implements RulesEngine {
  const _FakeRulesEngine({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  GameSnapshot applyMove(GameSnapshot state, GameMove move) {
    throw UnsupportedError('applyMove is not used by this test');
  }

  @override
  GameSnapshot initialState() => snapshot;

  @override
  List<GameMove> legalMoves(GameSnapshot state) => const [];
}
