import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
    const pushMove = GameMove(
      pieceId: azurePieceId,
      direction: GameDirection.up,
    );
    const pushResolution = MoveResolution(
      actionKind: MoveActionKind.push,
      mover: PieceTravel(
        pieceId: azurePieceId,
        fromX: 2,
        fromY: 2,
        toX: 2,
        toY: 1,
      ),
      displaced: PieceDisplacement(
        pieceId: 1,
        fromX: 2,
        fromY: 1,
        exitDirection: GameDirection.up,
      ),
      tileTransition: TileTransition(
        x: 2,
        y: 2,
        from: GameTileKind.normal,
        to: GameTileKind.damaged,
      ),
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
                (0, 1) || (2, 0) || (3, 3) => GameTileKind.hole,
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
    final pushedSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        for (var x = 0; x < 5; x++)
          for (var y = 0; y < 5; y++)
            GameTile(
              x: x,
              y: y,
              kind: switch ((x, y)) {
                (2, 2) || (1, 3) || (4, 1) => GameTileKind.damaged,
                (0, 1) || (2, 0) || (3, 3) => GameTileKind.hole,
                _ => GameTileKind.normal,
              },
            ),
      ],
      pieces: const [
        GamePiece(
          id: azurePieceId,
          owner: GamePlayer.first,
          x: 2,
          y: 1,
        ),
      ],
      snapshotHash: 'production-sprite-scene-pushed',
    );
    final engine = FakeRulesEngine.playing(
      initial: matchOf(snapshot, hash: 'production-sprite-scene-match'),
      next: matchOf(
        pushedSnapshot,
        hash: 'production-sprite-scene-pushed-match',
      ),
      legalMoves: const [pushMove],
      resolution: pushResolution,
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

    final spritesReady = find.byKey(
      const Key('round-board-production-sprites'),
    );
    for (
      var frame = 0;
      frame < 50 && spritesReady.evaluate().isEmpty;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(spritesReady, findsOneWidget);

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
    expect(exercisedBoard.legalMoves, [pushMove]);

    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
    }
    await tester.pumpAndSettle();
    final screenshotPrefix = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios-production-sprite',
      TargetPlatform.android => 'android-production-sprite',
      _ => throw UnsupportedError(
        'production sprite screenshots require iOS or Android',
      ),
    };
    final selectionBytes = await binding.takeScreenshot(
      '$screenshotPrefix-selection',
    );
    expect(selectionBytes, isNotEmpty);

    final pushDestination = find.semantics.byLabel(RegExp(' Push '));
    expect(pushDestination, findsOneWidget);
    tester.semantics.performAction(pushDestination, SemanticsAction.tap);
    await tester.pump();
    expect(engine.appliedMoves, [pushMove]);
    expect(tester.widget<RoundBoard>(boardFinder).playback, isNotNull);

    var contactPlayback = tester.widget<RoundBoard>(boardFinder).playback;
    for (var frame = 0; frame < 40; frame++) {
      if ((contactPlayback?.progress ?? 1) >= 0.36) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 8));
      contactPlayback = tester.widget<RoundBoard>(boardFinder).playback;
    }
    await tester.pump();
    contactPlayback = tester.widget<RoundBoard>(boardFinder).playback;
    expect(contactPlayback, isNotNull);
    expect(contactPlayback!.resolution.actionKind, MoveActionKind.push);
    expect(contactPlayback.progress, inInclusiveRange(0.36, 0.78));
    final contactBytes = await binding.takeScreenshot(
      '$screenshotPrefix-push-contact',
    );
    expect(contactBytes, isNotEmpty);

    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump();
    final settledBoard = tester.widget<RoundBoard>(boardFinder);
    expect(settledBoard.playback, isNull);
    expect(settledBoard.snapshot, pushedSnapshot);
    var settledBytes = await binding.takeScreenshot(
      '$screenshotPrefix-push-settled',
    );
    if (listEquals(contactBytes, settledBytes)) {
      await tester.pump(const Duration(milliseconds: 16));
      settledBytes = await binding.takeScreenshot(
        '$screenshotPrefix-push-settled',
      );
    }
    expect(settledBytes, isNotEmpty);
    expect(listEquals(contactBytes, settledBytes), isFalse);
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
