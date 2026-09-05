import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ttush_push/app/view/app.dart';
import 'package:ttush_push/game/coach/first_play_coach_store.dart';
import 'package:ttush_push/game/feedback/round_feedback.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/l10n/l10n.dart';
import 'package:ttush_push/src/rust/api.dart';

import '../test/support/match_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the Play Store listing scenes', (tester) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-mode-versus-ai')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('start-difficulty-strategic')),
      120,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Expert'), findsOneWidget);

    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    await _capture(binding, '01-opponent');

    final opening = _openingSnapshot();
    await tester.pumpWidget(
      _storeApp(
        GamePage(
          key: const Key('store-learn-scene'),
          coachStore: const _CoachStore(isComplete: false),
          feedback: const _SilentRoundFeedback(),
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(opening)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _waitForSprites(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('first-play-coach')), findsOneWidget);
    await _capture(binding, '02-learn');

    const selectedPosition = (2, 2);
    const pushMove = GameMove(pieceId: 0, direction: GameDirection.down);
    final pushSnapshot = _pushSnapshot();
    await tester.pumpWidget(
      _storeApp(
        GamePage(
          key: const Key('store-push-scene'),
          coachStore: const _CoachStore(isComplete: true),
          feedback: const _SilentRoundFeedback(),
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(pushSnapshot),
            legalMoves: const [pushMove],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _waitForSprites(tester);
    final board = tester.widget<RoundBoard>(find.byType(RoundBoard));
    expect(board.snapshot, pushSnapshot);
    expect(board.legalMoves, const [pushMove]);
    expect(board.onCellTap, isNotNull);
    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    final geometry = BoardGeometry.fromSnapshot(pushSnapshot, boardRect.size);
    expect(
      geometry.cellAt(
        geometry.cellCenter(selectedPosition.$1, selectedPosition.$2),
      ),
      selectedPosition,
    );
    await tester.tapAt(
      boardRect.topLeft +
          geometry.cellCenter(selectedPosition.$1, selectedPosition.$2),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).selectedPieceId,
      0,
    );
    await _capture(binding, '03-push');

    final resultSnapshot = _resultSnapshot();
    await tester.pumpWidget(
      _storeApp(
        GamePage(
          key: const Key('store-result-scene'),
          coachStore: const _CoachStore(isComplete: true),
          feedback: const _SilentRoundFeedback(),
          rulesEngine: FakeRulesEngine(
            initial: [
              matchOverMatch(resultSnapshot, winner: GamePlayer.first),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _waitForSprites(tester);
    await tester.pumpAndSettle();
    expect(find.text('MATCH COMPLETE'), findsOneWidget);
    expect(find.text('by knockout'), findsOneWidget);
    await _capture(binding, '04-win');
  });
}

Widget _storeApp(Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primaryColor: const Color(0xFF2A48DF),
      colorScheme: ColorScheme.fromSwatch(
        accentColor: const Color(0xFF2A48DF),
      ),
      fontFamily: 'Poppins',
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  final bytes = await binding.takeScreenshot(name);
  expect(bytes, isNotEmpty);
}

Future<void> _waitForSprites(WidgetTester tester) async {
  final sprites = find.byKey(const Key('round-board-production-sprites'));
  for (var frame = 0; frame < 50 && sprites.evaluate().isEmpty; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(sprites, findsOneWidget);
}

GameSnapshot _openingSnapshot() {
  return GameSnapshot(
    currentPlayer: GamePlayer.first,
    tiles: _tiles(),
    pieces: const [
      GamePiece(id: 0, owner: GamePlayer.first, x: 1, y: 0),
      GamePiece(id: 1, owner: GamePlayer.first, x: 3, y: 0),
      GamePiece(id: 2, owner: GamePlayer.second, x: 1, y: 4),
      GamePiece(id: 3, owner: GamePlayer.second, x: 3, y: 4),
    ],
    snapshotHash: 'store-opening',
  );
}

GameSnapshot _pushSnapshot() {
  return GameSnapshot(
    currentPlayer: GamePlayer.first,
    tiles: _tiles(),
    pieces: const [
      GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
      GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 3),
    ],
    snapshotHash: 'store-push',
  );
}

GameSnapshot _resultSnapshot() {
  return GameSnapshot(
    currentPlayer: GamePlayer.second,
    tiles: _tiles(),
    pieces: const [
      GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
    ],
    winner: GamePlayer.first,
    winReason: GameWinReason.knockout,
    snapshotHash: 'store-result',
  );
}

List<GameTile> _tiles() {
  return [
    for (var x = 0; x < 5; x++)
      for (var y = 0; y < 5; y++)
        GameTile(
          x: x,
          y: y,
          kind: switch ((x, y)) {
            (0, 2) || (4, 2) => GameTileKind.hole,
            (1, 3) || (3, 1) => GameTileKind.damaged,
            _ => GameTileKind.normal,
          },
        ),
  ];
}

final class _CoachStore implements FirstPlayCoachStore {
  const _CoachStore({required bool isComplete}) : _complete = isComplete;

  final bool _complete;

  @override
  Future<bool> isComplete({required int version}) async => _complete;

  @override
  Future<void> markComplete({required int version}) async {}
}

final class _SilentRoundFeedback implements RoundFeedback {
  const _SilentRoundFeedback();

  @override
  void moveApplied() {}

  @override
  void pieceSelected() {}

  @override
  void pushApplied() {}

  @override
  void roundWon() {}
}
