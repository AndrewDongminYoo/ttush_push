import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/app/app.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/src/rust/api.dart';

import '../../support/match_fixtures.dart';

void main() {
  const snapshot = GameSnapshot(
    currentPlayer: GamePlayer.first,
    tiles: [],
    pieces: [],
    snapshotHash: 'initial',
  );

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      App(rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot))),
    );
  }

  /// Reads the seat back off the match, which is the only place the choice
  /// becomes observable: the page keeps it privately.
  Finder opponentValue(String label) {
    return find.descendant(
      of: find.byKey(const Key('opponent-control')),
      matching: find.text('Opponent: $label'),
    );
  }

  testWidgets('starts a two-player match without offering a difficulty', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byKey(const Key('start-difficulty-greedy')), findsNothing);

    await tester.tap(find.byKey(const Key('start-match')));
    await tester.pumpAndSettle();

    expect(opponentValue('Human'), findsOneWidget);
  });

  testWidgets('opens a match against AI on Normal', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('start-mode-versus-ai')));
    await tester.pumpAndSettle();

    // A player who picks the mode and nothing else still gets a considered
    // opponent rather than the random one.
    await tester.tap(find.byKey(const Key('start-match')));
    await tester.pumpAndSettle();

    expect(opponentValue('Normal'), findsOneWidget);
  });

  testWidgets('hands the second seat to the chosen difficulty', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('start-mode-versus-ai')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-difficulty-random')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-match')));
    await tester.pumpAndSettle();

    expect(opponentValue('Easy'), findsOneWidget);
  });

  testWidgets('never shows a policy name to a player', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('start-mode-versus-ai')));
    await tester.pumpAndSettle();

    for (final policy in const ['Random', 'Greedy', 'Minimax']) {
      expect(find.text(policy), findsNothing, reason: policy);
    }
    for (final difficulty in const ['Easy', 'Normal', 'Hard']) {
      expect(find.text(difficulty), findsOneWidget, reason: difficulty);
    }
  });

  testWidgets('leaves the match from a control, not only a gesture', (
    tester,
  ) async {
    // iOS disables the interactive back-swipe while PopScope refuses the pop,
    // so a tappable control is the only exit that exists on both platforms.
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('start-match')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('leave-match')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leave-match-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('leave-match-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(GamePage), findsOneWidget);

    await tester.tap(find.byKey(const Key('leave-match')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-match-confirm')));
    await tester.pumpAndSettle();

    expect(find.byType(GamePage), findsNothing);
    expect(find.byKey(const Key('start-match')), findsOneWidget);
  });

  testWidgets('confirms before a back gesture discards the match', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('start-match')));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leave-match-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('leave-match-cancel')));
    await tester.pumpAndSettle();

    expect(find.byType(GamePage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-match-confirm')));
    await tester.pumpAndSettle();

    expect(find.byType(GamePage), findsNothing);
    expect(find.byKey(const Key('start-match')), findsOneWidget);
  });
}
