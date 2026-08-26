import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ttush_push/game/coach/first_play_coach_store.dart';
import 'package:ttush_push/game/feedback/round_feedback.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/l10n/l10n.dart';
import 'package:ttush_push/src/rust/api.dart';

import '../test/support/match_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the exercised production sprite scene', (
    tester,
  ) async {
    const azurePieceId = 0;
    const azurePosition = (2, 2);
    const normalMove = GameMove(
      pieceId: azurePieceId,
      direction: GameDirection.right,
    );
    const pushMove = GameMove(
      pieceId: azurePieceId,
      direction: GameDirection.up,
    );
    final snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        for (var x = 0; x < 5; x++)
          for (var y = 0; y < 5; y++)
            GameTile(
              x: x,
              y: y,
              kind: switch ((x, y)) {
                (1, 3) || (4, 1) => GameTileKind.damaged,
                (0, 1) || (3, 3) => GameTileKind.hole,
                _ => GameTileKind.normal,
              },
            ),
      ],
      pieces: [
        GamePiece(
          id: azurePieceId,
          owner: GamePlayer.first,
          x: azurePosition.$1,
          y: azurePosition.$2,
        ),
        const GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'production-sprite-scene',
    );
    final engine = FakeRulesEngine.playing(
      initial: matchOf(snapshot, hash: 'production-sprite-scene-match'),
      legalMoves: const [normalMove, pushMove],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GamePage(
          coachStore: const _CompletedCoachStore(),
          feedback: const _SilentRoundFeedback(),
          rulesEngine: engine,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boardFinder = find.byType(RoundBoard);
    expect(boardFinder, findsOneWidget);
    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    final geometry = BoardGeometry.fromSnapshot(snapshot, boardRect.size);
    await tester.tapAt(
      boardRect.topLeft +
          geometry.cellCenter(azurePosition.$1, azurePosition.$2),
    );
    await tester.pumpAndSettle();

    final exercisedBoard = tester.widget<RoundBoard>(boardFinder);
    expect(exercisedBoard.selectedPieceId, azurePieceId);
    expect(exercisedBoard.legalMoves, containsAll([normalMove, pushMove]));

    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
    }
    await tester.pumpAndSettle();
    final screenshotName = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios-production-sprite-scene',
      TargetPlatform.android => 'android-production-sprite-scene',
      _ => throw UnsupportedError(
        'production sprite screenshots require iOS or Android',
      ),
    };
    final pngBytes = await binding.takeScreenshot(screenshotName);
    expect(pngBytes, isNotEmpty);
  });
}

final class _CompletedCoachStore implements FirstPlayCoachStore {
  const _CompletedCoachStore();

  @override
  Future<bool> isComplete({required int version}) async => true;

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
