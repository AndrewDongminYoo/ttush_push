import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/app/app.dart';
import 'package:ttush_push/game/board/board_definition.dart';
import 'package:ttush_push/game/start/start_page.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/l10n/l10n.dart';
import 'package:ttush_push/src/rust/api.dart';

import '../../support/match_fixtures.dart';
import '../../support/recording_ad_gateway.dart';

void main() {
  const snapshot = GameSnapshot(
    currentPlayer: GamePlayer.first,
    tiles: [],
    pieces: [],
    snapshotHash: 'initial',
  );

  Future<void> pumpApp(
    WidgetTester tester, {
    FakeRulesEngine? engine,
    Key? key,
  }) async {
    await tester.pumpWidget(
      App(
        key: key,
        rulesEngine:
            engine ?? FakeRulesEngine.playing(initial: matchOf(snapshot)),
      ),
    );
  }

  Future<void> startMatch(WidgetTester tester) async {
    final start = find.byKey(const Key('start-match'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
  }

  Future<void> leaveMatch(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('leave-match')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-match-confirm')));
    await tester.pumpAndSettle();
  }

  /// Reads the seat back off the match, which is the only place the choice
  /// becomes observable: the page keeps it privately.
  Finder opponentValue(String label) {
    return find.descendant(
      of: find.byKey(const Key('opponent-control')),
      matching: find.text('Opponent: $label'),
    );
  }

  testWidgets('forwards the selected clipped-corners board to the match', (
    tester,
  ) async {
    final engine = FakeRulesEngine.playing(initial: matchOf(snapshot));

    await tester.pumpWidget(App(rulesEngine: engine));

    final boardChoice = find.byKey(const Key('start-board-clipped-corners'));
    expect(boardChoice, findsOneWidget);

    await tester.tap(boardChoice);
    await tester.pumpAndSettle();
    await startMatch(tester);

    expect(engine.initialDefinitions, hasLength(1));
    expect(
      engine.initialDefinitions.single,
      same(BuiltInBoard.clippedCorners.definition.rules),
    );
  });

  testWidgets('keeps the selected board when the setup page stays mounted', (
    tester,
  ) async {
    final engine = FakeRulesEngine.playing(initial: matchOf(snapshot));

    await pumpApp(tester, engine: engine);
    await tester.tap(find.byKey(const Key('start-board-clipped-corners')));
    await tester.pumpAndSettle();
    await startMatch(tester);
    await leaveMatch(tester);

    expect(find.byKey(const Key('start-match')), findsOneWidget);

    await startMatch(tester);

    expect(engine.initialDefinitions, hasLength(2));
    expect(
      engine.initialDefinitions,
      everyElement(same(BuiltInBoard.clippedCorners.definition.rules)),
    );
  });

  testWidgets('resets the board when a fresh App key creates setup state', (
    tester,
  ) async {
    final engine = FakeRulesEngine.playing(initial: matchOf(snapshot));

    await pumpApp(
      tester,
      engine: engine,
      key: const ValueKey('first-app-state'),
    );
    await tester.tap(find.byKey(const Key('start-board-clipped-corners')));
    await tester.pumpAndSettle();
    await startMatch(tester);

    await pumpApp(
      tester,
      engine: engine,
      key: const ValueKey('fresh-app-state'),
    );
    await startMatch(tester);

    expect(engine.initialDefinitions, hasLength(2));
    expect(
      engine.initialDefinitions.first,
      same(BuiltInBoard.clippedCorners.definition.rules),
    );
    expect(
      engine.initialDefinitions.last,
      same(BuiltInBoard.baseline.definition.rules),
    );
  });

  testWidgets('ignores a null board radio value', (tester) async {
    final engine = FakeRulesEngine.playing(initial: matchOf(snapshot));

    await pumpApp(tester, engine: engine);
    final boardChoice = find.byKey(const Key('start-board-clipped-corners'));
    await tester.tap(boardChoice);
    await tester.pumpAndSettle();

    final group = tester.widget<RadioGroup<BuiltInBoard>>(
      find.ancestor(
        of: boardChoice,
        matching: find.byType(RadioGroup<BuiltInBoard>),
      ),
    );
    group.onChanged(null);
    await tester.pump();

    await startMatch(tester);

    expect(
      engine.initialDefinitions.single,
      same(BuiltInBoard.clippedCorners.definition.rules),
    );
  });

  testWidgets('keeps board choices and Start reachable at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final setup in [
      (
        locale: const Locale('en'),
        heading: 'Board',
        baseline: 'Classic',
        baselineDescription: '25 playable cells',
        clippedCorners: 'Clipped corners',
        clippedCornersDescription:
            '21 playable cells with the four corners removed',
      ),
      (
        locale: const Locale('ko'),
        heading: '보드',
        baseline: '기본 보드',
        baselineDescription: '25칸 보드',
        clippedCorners: '모서리 없는 보드',
        clippedCornersDescription: '네 모서리를 뺀 21칸',
      ),
    ]) {
      final engine = FakeRulesEngine.playing(initial: matchOf(snapshot));

      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('start-page-${setup.locale.languageCode}'),
          locale: setup.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: StartPage(rulesEngine: engine),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(setup.heading), findsOneWidget);
      expect(find.text(setup.baseline), findsOneWidget);
      expect(find.text(setup.baselineDescription), findsOneWidget);
      expect(find.text(setup.clippedCorners), findsOneWidget);
      expect(find.text(setup.clippedCornersDescription), findsOneWidget);

      final baselineChoice = find.byKey(const Key('start-board-baseline'));
      await tester.ensureVisible(baselineChoice);
      await tester.pumpAndSettle();
      expect(_isWithinViewport(tester.getRect(baselineChoice)), isTrue);

      final boardChoice = find.byKey(const Key('start-board-clipped-corners'));
      await tester.ensureVisible(boardChoice);
      await tester.pumpAndSettle();
      expect(_isWithinViewport(tester.getRect(boardChoice)), isTrue);

      await tester.tap(boardChoice);
      await tester.pump();

      final start = find.byKey(const Key('start-match'));
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      expect(_isWithinViewport(tester.getRect(start)), isTrue);

      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(
        engine.initialDefinitions.single,
        same(BuiltInBoard.clippedCorners.definition.rules),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('starts a two-player match without offering a difficulty', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byKey(const Key('start-difficulty-greedy')), findsNothing);

    await startMatch(tester);

    expect(opponentValue('Human'), findsOneWidget);
  });

  testWidgets('opens a match against AI on Normal', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('start-mode-versus-ai')));
    await tester.pumpAndSettle();

    // A player who picks the mode and nothing else still gets a considered
    // opponent rather than the random one.
    await startMatch(tester);

    expect(opponentValue('Normal'), findsOneWidget);
  });

  testWidgets('hands the second seat to the chosen difficulty', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('start-mode-versus-ai')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-difficulty-random')));
    await tester.pumpAndSettle();

    await startMatch(tester);

    expect(opponentValue('Easy'), findsOneWidget);
  });

  testWidgets('hands the second seat to Expert', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('start-mode-versus-ai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-difficulty-strategic')));
    await tester.pumpAndSettle();
    await startMatch(tester);

    expect(opponentValue('Expert'), findsOneWidget);
  });

  testWidgets('never shows a policy name to a player', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('start-mode-versus-ai')));
    await tester.pumpAndSettle();

    for (final policy in const ['Random', 'Greedy', 'Minimax', 'Strategic']) {
      expect(find.text(policy), findsNothing, reason: policy);
    }
    for (final difficulty in const ['Easy', 'Normal', 'Hard', 'Expert']) {
      expect(find.text(difficulty), findsOneWidget, reason: difficulty);
    }
  });

  testWidgets('keeps both radio states visible on the dark panel', (
    tester,
  ) async {
    // The app's ThemeData is light, so a radio left to resolve its own fill
    // lands on black: measured 1.20:1 against the panel, which is no outline
    // at all until the tile is selected.
    await pumpApp(tester);

    final tile = find.byKey(const Key('start-mode-versus-ai'));
    final panel = tester.widget<Material>(
      find.ancestor(of: tile, matching: find.byType(Material)).first,
    );
    final background = panel.color;
    expect(background, isNotNull);

    final fill = Theme.of(tester.element(tile)).radioTheme.fillColor;
    expect(fill, isNotNull, reason: 'the radio fill is named, not inherited');

    for (final states in const [
      <WidgetState>{},
      {WidgetState.selected},
    ]) {
      final resolved = fill!.resolve(states);
      expect(resolved, isNotNull, reason: '$states');
      expect(
        _contrastRatio(resolved!, background!),
        greaterThanOrEqualTo(3),
        reason: '$states against the panel',
      );
    }
  });

  testWidgets('leaves the match from a control, not only a gesture', (
    tester,
  ) async {
    // iOS disables the interactive back-swipe while PopScope refuses the pop,
    // so a tappable control is the only exit that exists on both platforms.
    await pumpApp(tester);

    await startMatch(tester);

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

    await startMatch(tester);

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

  testWidgets('carries the ad gateway from the app down to the match', (
    tester,
  ) async {
    const startSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 2, y: 0, kind: GameTileKind.normal),
        GameTile(x: 2, y: 1, kind: GameTileKind.normal),
        GameTile(x: 2, y: 2, kind: GameTileKind.normal),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'threading-start',
    );
    const terminalSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 2, y: 0, kind: GameTileKind.hole),
        GameTile(x: 2, y: 1, kind: GameTileKind.normal),
        GameTile(x: 2, y: 2, kind: GameTileKind.damaged),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1)],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'threading-terminal',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.up);
    const resolution = MoveResolution(
      actionKind: MoveActionKind.push,
      mover: PieceTravel(pieceId: 0, fromX: 2, fromY: 2, toX: 2, toY: 1),
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
    final ads = RecordingAdGateway();

    await tester.pumpWidget(
      App(
        adGateway: ads,
        rulesEngine: FakeRulesEngine.playing(
          initial: matchOf(startSnapshot, hash: 'threading-start'),
          next: matchOverMatch(
            terminalSnapshot,
            winner: GamePlayer.first,
            hash: 'threading-over',
          ),
          legalMoves: const [move],
          resolution: resolution,
        ),
      ),
    );

    await startMatch(tester);

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();
    await _finishReplay(tester);

    expect(ads.events, ['match-decided']);
  });
}

bool _isWithinViewport(Rect rect) =>
    rect.left >= 0 && rect.top >= 0 && rect.right <= 320 && rect.bottom <= 568;

Offset Function(int x, int y) _cellCenterOf(WidgetTester tester) {
  final boardRect = tester.getRect(find.byKey(const Key('round-board-canvas')));
  final board = tester.widget<RoundBoard>(find.byType(RoundBoard));
  final geometry = BoardGeometry.fromSnapshot(board.snapshot, boardRect.size);
  return (x, y) => boardRect.topLeft + geometry.cellCenter(x, y);
}

Future<void> _finishReplay(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

/// WCAG relative contrast, matching the helper the match-screen tests use.
double _contrastRatio(Color foreground, Color background) {
  final renderedForeground = Color.alphaBlend(foreground, background);
  final foregroundLuminance = renderedForeground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
