import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:ttush_push/game/board/board_definition.dart';
import 'package:ttush_push/game/coach/first_play_coach_store.dart';
import 'package:ttush_push/game/feedback/round_feedback.dart';
import 'package:ttush_push/game/match/match_controller.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/game/view/production_sprite_set.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/src/rust/api.dart';

import '../../support/match_fixtures.dart';

const _sharedPanelColor = Color(0xFF161A22);
const _panelBorderColor = Color(0xFF303846);
const _firstPlayerColor = Color(0xFF2A48DF);
const _secondPlayerColor = Color(0xFFE14B4B);

const _pushResolution = MoveResolution(
  actionKind: MoveActionKind.push,
  mover: PieceTravel(pieceId: 0, fromX: 0, fromY: 0, toX: 0, toY: 1),
  displaced: PieceDisplacement(
    pieceId: 1,
    fromX: 0,
    fromY: 1,
    toX: 0,
    toY: 2,
  ),
  tileTransition: TileTransition(
    x: 0,
    y: 0,
    from: GameTileKind.normal,
    to: GameTileKind.damaged,
  ),
);

const _fallPushResolution = MoveResolution(
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

const _secondBotDownResolution = MoveResolution(
  actionKind: MoveActionKind.normal,
  mover: PieceTravel(pieceId: 1, fromX: 0, fromY: 0, toX: 0, toY: 1),
  tileTransition: TileTransition(
    x: 0,
    y: 0,
    from: GameTileKind.normal,
    to: GameTileKind.damaged,
  ),
);

const BoardDefinition _runtimeDefinitionA = baselineBoardDefinition;
const _runtimeDefinitionB = BoardDefinition(
  backgroundAssetPath: 'assets/images/sprites/foothold_hole.png',
  rules: GameBoardDefinition(
    playableCells: [
      GameBoardCell(x: 3, y: 4),
      GameBoardCell(x: 3, y: 5),
    ],
    startingPieces: [
      GamePiece(id: 8, owner: GamePlayer.first, x: 3, y: 4),
      GamePiece(id: 9, owner: GamePlayer.second, x: 3, y: 5),
    ],
  ),
);

const _runtimeSnapshotB = GameSnapshot(
  currentPlayer: GamePlayer.second,
  tiles: [
    GameTile(x: 3, y: 4, kind: GameTileKind.normal),
    GameTile(x: 3, y: 5, kind: GameTileKind.normal),
  ],
  pieces: [
    GamePiece(id: 8, owner: GamePlayer.first, x: 3, y: 4),
    GamePiece(id: 9, owner: GamePlayer.second, x: 3, y: 5),
  ],
  snapshotHash: 'runtime-board-b',
);

void main() {
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await SharedPreferencesFirstPlayCoachStore().markComplete(
      version: firstPlayCoachVersion,
    );
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('places Ember above Azure around the playable board', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.normal)],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'initial',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot)),
        ),
      ),
    );

    _expectActiveTurn(tester, GamePlayer.first);
    expect(find.byType(RoundBoard), findsOneWidget);
    expect(find.text('Ember Expedition'), findsOneWidget);
    expect(find.text('Azure Expedition'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('player-panel-second'))).top,
      lessThan(tester.getRect(find.byKey(const Key('player-panel-first'))).top),
    );
  });

  testWidgets('uses a shared panel surface with a board-facing turn accent', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.normal)],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'shared-panel-surface',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot)),
        ),
      ),
    );

    final firstPanel = tester.widget<Container>(
      find.byKey(const Key('player-panel-first')),
    );
    final secondPanel = tester.widget<Container>(
      find.byKey(const Key('player-panel-second')),
    );
    final firstDecoration = firstPanel.decoration! as BoxDecoration;
    final secondDecoration = secondPanel.decoration! as BoxDecoration;
    final firstBorder = firstDecoration.border! as Border;
    final secondBorder = secondDecoration.border! as Border;

    expect(firstDecoration.color, _sharedPanelColor);
    expect(secondDecoration.color, _sharedPanelColor);
    expect(firstBorder.top.color, _firstPlayerColor);
    expect(firstBorder.top.width, 3);
    expect(secondBorder.bottom.color, _panelBorderColor);
    expect(secondBorder.bottom.width, 3);
  });

  testWidgets('renders the air-ruins environment behind the match', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'air-ruins-background',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot)),
        ),
      ),
    );

    expect(find.byKey(const Key('air-ruins-background')), findsOneWidget);
  });

  testWidgets('uses its BoardDefinition for rules and background', (
    tester,
  ) async {
    const definition = BoardDefinition(
      backgroundAssetPath: 'assets/images/sprites/foothold_hole.png',
      rules: GameBoardDefinition(
        playableCells: [
          GameBoardCell(x: 4, y: 7),
          GameBoardCell(x: 5, y: 7),
          GameBoardCell(x: 5, y: 8),
        ],
        startingPieces: [
          GamePiece(id: 7, owner: GamePlayer.first, x: 4, y: 7),
          GamePiece(id: 9, owner: GamePlayer.second, x: 5, y: 8),
        ],
      ),
    );
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 4, y: 7, kind: GameTileKind.normal),
        GameTile(x: 5, y: 7, kind: GameTileKind.normal),
        GameTile(x: 5, y: 8, kind: GameTileKind.normal),
      ],
      pieces: [
        GamePiece(id: 7, owner: GamePlayer.first, x: 4, y: 7),
        GamePiece(id: 9, owner: GamePlayer.second, x: 5, y: 8),
      ],
      snapshotHash: 'configured-board',
    );
    final engine = FakeRulesEngine.playing(initial: matchOf(snapshot));

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(boardDefinition: definition, rulesEngine: engine),
      ),
    );

    expect(engine.initialDefinitions, [definition.rules]);
    final image = tester.widget<Image>(
      find.byKey(const Key('air-ruins-background')),
    );
    expect(
      (image.image as AssetImage).assetName,
      definition.backgroundAssetPath,
    );
  });

  testWidgets(
    'restarts the retained page when its BoardDefinition changes',
    (tester) async {
      const snapshotA = GameSnapshot(
        currentPlayer: GamePlayer.second,
        tiles: [
          GameTile(x: 0, y: 0, kind: GameTileKind.normal),
          GameTile(x: 0, y: 1, kind: GameTileKind.normal),
        ],
        pieces: [
          GamePiece(id: 1, owner: GamePlayer.second, x: 0, y: 0),
        ],
        snapshotHash: 'runtime-board-a',
      );
      const botMove = GameMove(
        pieceId: 1,
        direction: GameDirection.down,
      );
      final engine = FakeRulesEngine(
        initial: [matchOf(snapshotA), matchOf(_runtimeSnapshotB)],
        legalMovesFor: (_) => const [botMove],
        botMove: (_, _) => botMove,
      );
      const pageKey = Key('runtime-board-game-page');
      Widget host(BoardDefinition definition) => MaterialApp(
        home: GamePage(
          key: pageKey,
          boardDefinition: definition,
          rulesEngine: engine,
        ),
      );

      await tester.pumpWidget(host(_runtimeDefinitionA));
      final stateBefore = tester.state(find.byType(GamePage));

      await tester.pumpWidget(host(_runtimeDefinitionA));
      expect(engine.initialDefinitions, [_runtimeDefinitionA.rules]);

      await tester.tapAt(_cellCenterOf(tester)(0, 0));
      await tester.pump();
      expect(find.byKey(const Key('match-announcement')), findsOneWidget);

      await _selectOpponent(tester, 'random');
      final oldTimerStartedAt = tester.binding.clock.now();
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(_runtimeDefinitionB));

      expect(tester.state(find.byType(GamePage)), same(stateBefore));
      expect(engine.initialDefinitions, [
        _runtimeDefinitionA.rules,
        _runtimeDefinitionB.rules,
      ]);
      expect(
        tester.widget<RoundBoard>(find.byType(RoundBoard)).snapshot,
        _runtimeSnapshotB,
      );
      final background = tester.widget<Image>(
        find.byKey(const Key('air-ruins-background')),
      );
      expect(
        (background.image as AssetImage).assetName,
        _runtimeDefinitionB.backgroundAssetPath,
      );
      expect(_inPanel('second', 'Opponent: Human'), findsOneWidget);
      expect(find.byKey(const Key('match-announcement')), findsNothing);

      await tester.tap(find.byKey(const Key('opponent-control')));
      await tester.pump();
      Navigator.of(
        tester.element(find.byKey(const Key('opponent-choice-random'))),
      ).pop(Opponent.random);
      await tester.pump();
      const botPause = Duration(milliseconds: 450);
      final elapsed = tester.binding.clock.now().difference(oldTimerStartedAt);
      expect(elapsed, lessThan(botPause));
      await tester.pump(botPause - elapsed);
      expect(engine.botRequests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'ignores an opponent choice opened before board replacement',
    (tester) async {
      const snapshotA = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [],
        pieces: [],
        snapshotHash: 'opponent-sheet-board-a',
      );
      final engine = FakeRulesEngine(
        initial: [matchOf(snapshotA), matchOf(_runtimeSnapshotB)],
      );
      const pageKey = Key('opponent-sheet-board-game-page');
      Widget host(BoardDefinition definition) => MaterialApp(
        home: GamePage(
          key: pageKey,
          boardDefinition: definition,
          rulesEngine: engine,
        ),
      );

      await tester.pumpWidget(host(_runtimeDefinitionA));
      await tester.tap(find.byKey(const Key('opponent-control')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(_runtimeDefinitionB));
      expect(_inPanel('second', 'Opponent: Human'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('opponent-choice-random')),
      );
      await tester.pumpAndSettle();

      expect(_inPanel('second', 'Opponent: Human'), findsOneWidget);
    },
  );

  testWidgets('stops the previous board replay when its definition changes', (
    tester,
  ) async {
    const snapshotA = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
        GameTile(x: 1, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0),
        GamePiece(id: 1, owner: GamePlayer.second, x: 1, y: 1),
      ],
      snapshotHash: 'replay-board-a',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine(
      initial: [
        matchOf(snapshotA, hash: 'replay-match-a'),
        matchOf(_runtimeSnapshotB, hash: 'replay-match-b'),
      ],
      moveResults: [
        moveResultOf(
          next: matchOf(snapshotA, hash: 'replay-match-a-moved'),
          resolution: testMoveResolution,
        ),
      ],
      legalMovesFor: (state) =>
          state.snapshotHash == 'replay-match-a' ? const [move] : const [],
    );
    const pageKey = Key('replay-board-game-page');
    Widget host(BoardDefinition definition) => MaterialApp(
      home: GamePage(
        key: pageKey,
        boardDefinition: definition,
        rulesEngine: engine,
      ),
    );

    await tester.pumpWidget(host(_runtimeDefinitionA));

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(0, 0));
    await tester.tapAt(cellCenter(0, 1));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).pieceFacings,
      {0: ExplorerFacing.up},
    );

    await tester.pumpWidget(host(_runtimeDefinitionB));

    final board = tester.widget<RoundBoard>(find.byType(RoundBoard));
    expect(board.playback, isNull);
    expect(board.snapshot, _runtimeSnapshotB);
    expect(board.pieceFacings, isEmpty);
    final settlePumps = await tester.pumpAndSettle();
    // Six 100 ms pumps would let the old 540 ms replay finish normally.
    expect(settlePumps, lessThan(6));

    await tester.pump(const Duration(milliseconds: 600));
    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).snapshot,
      _runtimeSnapshotB,
    );
  });

  testWidgets('keeps ruins inside the portrait background crop', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view
      ..physicalSize = const Size(320, 480)
      ..devicePixelRatio = 1;

    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'portrait-air-ruins-background',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot)),
        ),
      ),
    );

    final background = tester.widget<Image>(
      find.byKey(const Key('air-ruins-background')),
    );
    expect(background.alignment, Alignment.centerLeft);
  });

  testWidgets('retries an initial bridge failure', (tester) async {
    const readySnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'ready',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine(
            initial: [StateError('bridge unavailable'), matchOf(readySnapshot)],
          ),
        ),
      ),
    );

    expect(find.text('Unable to start round'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();

    _expectActiveTurn(tester, GamePlayer.first);
  });

  testWidgets('blocks terminal board input and restarts the round', (
    tester,
  ) async {
    const startSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 2, y: 0, kind: GameTileKind.hole),
        GameTile(x: 2, y: 1, kind: GameTileKind.normal),
        GameTile(x: 2, y: 2, kind: GameTileKind.normal),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'restart-start',
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
      snapshotHash: 'terminal',
    );
    final restartedSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: startSnapshot.tiles,
      pieces: startSnapshot.pieces,
      snapshotHash: 'restarted',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.up);
    final engine = FakeRulesEngine(
      initial: [
        matchOf(startSnapshot, hash: 'restart-match-start'),
        matchOf(restartedSnapshot),
      ],
      moveResults: [
        moveResultOf(
          next: matchOverMatch(
            terminalSnapshot,
            winner: GamePlayer.first,
          ),
          resolution: _fallPushResolution,
        ),
      ],
      legalMovesFor: (snapshot) =>
          snapshot.snapshotHash == 'restart-match-start'
          ? const [move]
          : const [],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();
    await _finishReplay(tester);

    expect(find.text('MATCH COMPLETE'), findsOneWidget);
    expect(find.text('ROUND COMPLETE'), findsNothing);
    final matchScope = tester.widget<Container>(
      find.byKey(const Key('result-scope-match')),
    );
    expect(
      (matchScope.decoration! as BoxDecoration).color,
      _firstPlayerColor,
    );
    expect(_inOverlay('Azure Expedition'), findsOneWidget);
    expect(find.text('wins the match'), findsOneWidget);
    expect(find.text('by knockout'), findsOneWidget);
    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    await tester.tapAt(boardRect.center);

    expect(engine.appliedMoves, [move]);
    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).pieceFacings,
      isNotEmpty,
    );

    await tester.tap(find.text('Start New Match'));
    await tester.pump();

    _expectActiveTurn(tester, GamePlayer.first);
    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).pieceFacings,
      isEmpty,
    );
  });

  testWidgets('applies only the selected legal destination without shifting '
      'the board', (tester) async {
    const initialSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'initial',
    );
    const nextSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
      snapshotHash: 'next',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initialSnapshot),
      next: matchOf(nextSnapshot, hash: 'next'),
      legalMoves: const [move],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    final initialBoardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    final cellCenter = _cellCenterOf(tester);

    await tester.tapAt(cellCenter(0, 0));
    await tester.tapAt(cellCenter(0, 1));
    await tester.pump();
    await _finishReplay(tester);

    expect(engine.appliedMoves, [move]);
    _expectActiveTurn(tester, GamePlayer.second);
    expect(
      tester.getRect(find.byKey(const Key('round-board-canvas'))),
      initialBoardRect,
    );
  });

  testWidgets('keeps the current snapshot visible until replay completes', (
    tester,
  ) async {
    const initialSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'replay-initial',
    );
    const nextSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
      snapshotHash: 'replay-next',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initialSnapshot),
      next: matchOf(nextSnapshot, hash: 'replay-next-match'),
      legalMoves: const [move],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    final geometry = BoardGeometry.fromSnapshot(
      initialSnapshot,
      boardRect.size,
    );
    await tester.tapAt(boardRect.topLeft + geometry.cellCenter(0, 0));
    await tester.tapAt(boardRect.topLeft + geometry.cellCenter(0, 1));
    await tester.pump();

    expect(engine.appliedMoves, [move]);
    _expectActiveTurn(tester, GamePlayer.first);
    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).playback,
      isNotNull,
    );
    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).pieceFacings,
      {0: ExplorerFacing.up},
    );

    await tester.pump(const Duration(milliseconds: 539));
    _expectActiveTurn(tester, GamePlayer.first);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    _expectActiveTurn(tester, GamePlayer.second);
    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).pieceFacings,
      {0: ExplorerFacing.up},
    );
  });

  testWidgets('uses the same commit path with reduced motion', (tester) async {
    const initialSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'reduced-initial',
    );
    const nextSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
      snapshotHash: 'reduced-next',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initialSnapshot),
      next: matchOf(nextSnapshot, hash: 'reduced-next-match'),
      legalMoves: const [move],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: GamePage(rulesEngine: engine),
        ),
      ),
    );

    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    final geometry = BoardGeometry.fromSnapshot(
      initialSnapshot,
      boardRect.size,
    );
    await tester.tapAt(boardRect.topLeft + geometry.cellCenter(0, 0));
    await tester.tapAt(boardRect.topLeft + geometry.cellCenter(0, 1));
    await tester.pump();

    _expectActiveTurn(tester, GamePlayer.first);
    await tester.pump(const Duration(milliseconds: 119));
    _expectActiveTurn(tester, GamePlayer.first);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    _expectActiveTurn(tester, GamePlayer.second);
  });

  testWidgets('locks board and opponent controls while replaying', (
    tester,
  ) async {
    const initialSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'locked-initial',
    );
    const nextSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
      snapshotHash: 'locked-next',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initialSnapshot),
      next: matchOf(nextSnapshot, hash: 'locked-next-match'),
      legalMoves: const [move],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    final geometry = BoardGeometry.fromSnapshot(
      initialSnapshot,
      boardRect.size,
    );
    await tester.tapAt(boardRect.topLeft + geometry.cellCenter(0, 0));
    await tester.tapAt(boardRect.topLeft + geometry.cellCenter(0, 1));
    await tester.pump();

    await tester.tapAt(boardRect.topLeft + geometry.cellCenter(0, 1));
    await tester.tap(find.byKey(const Key('opponent-control')));
    await tester.pump();

    expect(engine.appliedMoves, [move]);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('opponent-control')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).playback,
      isNotNull,
    );
  });

  testWidgets('does not commit a replay after the page is disposed', (
    tester,
  ) async {
    const initialSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'dispose-initial',
    );
    const nextSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
      snapshotHash: 'dispose-next',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initialSnapshot),
      next: matchOf(nextSnapshot, hash: 'dispose-next-match'),
      legalMoves: const [move],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    final geometry = BoardGeometry.fromSnapshot(
      initialSnapshot,
      boardRect.size,
    );
    await tester.tapAt(boardRect.topLeft + geometry.cellCenter(0, 0));
    await tester.tapAt(boardRect.topLeft + geometry.cellCenter(0, 1));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'clears selection after a tap outside the current player pieces',
    (
      tester,
    ) async {
      const initialSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [],
        pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
        snapshotHash: 'clear-selection',
      );
      const nextSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.second,
        tiles: [],
        pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
        snapshotHash: 'should-not-apply',
      );
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final engine = FakeRulesEngine.playing(
        initial: matchOf(initialSnapshot),
        next: matchOf(nextSnapshot, hash: 'next'),
        legalMoves: const [move],
      );

      await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

      final cellCenter = _cellCenterOf(tester);

      await tester.tapAt(cellCenter(0, 0));
      await tester.tapAt(cellCenter(1, 0));
      await tester.tapAt(cellCenter(0, 1));
      await tester.pump();

      expect(engine.appliedMoves, isEmpty);
      _expectActiveTurn(tester, GamePlayer.first);
    },
  );

  testWidgets('pushes an opposing piece standing on a legal destination', (
    tester,
  ) async {
    const initialSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'push-precedence',
    );
    const nextSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 0),
      ],
      snapshotHash: 'pushed',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.up);
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initialSnapshot),
      next: matchOf(nextSnapshot, hash: 'next'),
      legalMoves: const [move],
      resolution: _pushResolution,
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    final cellCenter = _cellCenterOf(tester);

    await tester.tapAt(cellCenter(2, 2));
    // The destination is occupied by the opponent, so this tap must push
    // rather than fall through to selecting their piece.
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();
    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).pieceFacings,
      {0: ExplorerFacing.up, 1: ExplorerFacing.up},
    );
    await _finishReplay(tester);

    expect(engine.appliedMoves, [move]);
    _expectActiveTurn(tester, GamePlayer.second);
    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).pieceFacings,
      {0: ExplorerFacing.up, 1: ExplorerFacing.up},
    );
  });

  testWidgets('resets presentation facing after round advance', (tester) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'facing-round-start',
    );
    const wonRound = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1)],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'facing-round-won',
    );
    const nextRound = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'facing-round-next',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.up);
    final engine = FakeRulesEngine(
      initial: [matchOf(start, hash: 'facing-match-start')],
      moveResults: [
        moveResultOf(
          next: roundOverMatch(
            wonRound,
            winner: GamePlayer.first,
            hash: 'facing-match-won',
          ),
          resolution: _fallPushResolution,
        ),
      ],
      advanceResults: [
        matchOf(nextRound, firstWins: 1, hash: 'facing-match-next'),
      ],
      legalMovesFor: (snapshot) => snapshot.snapshotHash == 'facing-match-start'
          ? const [move]
          : const [],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));
    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();
    await _finishReplay(tester);

    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).pieceFacings,
      isNotEmpty,
    );
    await tester.tap(find.text('Start Next Round'));
    await tester.pump();

    expect(
      tester.widget<RoundBoard>(find.byType(RoundBoard)).pieceFacings,
      isEmpty,
    );
  });

  testWidgets('shows an immobilization result over the final board', (
    tester,
  ) async {
    const terminalSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.normal)],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      winner: GamePlayer.second,
      winReason: GameWinReason.immobilization,
      snapshotHash: 'immobilized',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOverMatch(
              terminalSnapshot,
              winner: GamePlayer.second,
              reason: GameWinReason.immobilization,
            ),
          ),
        ),
      ),
    );

    expect(_inOverlay('Ember Expedition'), findsOneWidget);
    expect(find.text('wins the match'), findsOneWidget);
    expect(find.text('by immobilization'), findsOneWidget);
    // The position that ended the round stays readable underneath.
    expect(find.byType(RoundBoard), findsOneWidget);
  });

  testWidgets('keeps the board paint region within a small and a large '
      'screen', (tester) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'layout',
    );
    const terminalSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'layout-terminal',
    );
    addTearDown(tester.view.reset);

    for (final size in const [
      Size(320, 480),
      Size(1024, 1280),
      Size(568, 320),
    ]) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot)),
          ),
        ),
      );

      final boardRect = tester.getRect(
        find.byKey(const Key('round-board-canvas')),
      );

      expect(boardRect.width, greaterThan(0), reason: 'at $size');
      expect(
        boardRect.width,
        lessThanOrEqualTo(size.width),
        reason: 'at $size',
      );
      expect(boardRect.height, greaterThan(0), reason: 'at $size');
      expect(
        boardRect.height,
        lessThanOrEqualTo(size.height),
        reason: 'at $size',
      );
      expect(tester.takeException(), isNull, reason: 'ongoing at $size');

      // The overlay carries its own overflow risk, so it is laid out here too.
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            key: const Key('terminal'),
            rulesEngine: FakeRulesEngine.playing(
              initial: matchOverMatch(
                terminalSnapshot,
                winner: GamePlayer.first,
              ),
            ),
          ),
        ),
      );

      expect(
        find.text('Start New Match'),
        findsOneWidget,
        reason: 'at $size',
      );
      expect(tester.takeException(), isNull, reason: 'terminal at $size');
    }
  });

  testWidgets('keeps a panel at its own height when space is short', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'landscape',
    );
    addTearDown(tester.view.reset);
    tester.view
      ..physicalSize = const Size(568, 320)
      ..devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot)),
        ),
      ),
    );

    // A panel squeezed below its content height deforms the player mark
    // before it ever reports an overflow, so the mark is measured directly.
    final mark = tester.getRect(
      find.byKey(const Key('player-mark-first')),
    );

    expect(mark.width, mark.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('feels a selection and then an ordinary move', (tester) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'haptic-start',
    );
    const afterMove = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 3),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'haptic-moved',
    );
    const moveDown = GameMove(pieceId: 0, direction: GameDirection.down);
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(start),
            next: matchOf(afterMove, hash: 'next'),
            legalMoves: const [moveDown],
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.pump();

    expect(felt, ['select']);

    felt.clear();
    await tester.tapAt(cellCenter(2, 3));
    await tester.pump();
    await _finishReplay(tester);

    expect(felt, ['move']);
  });

  testWidgets('feels the won round rather than the push that won it', (
    tester,
  ) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'haptic-winning',
    );
    const afterPush = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1)],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'haptic-won',
    );
    const pushUp = GameMove(pieceId: 0, direction: GameDirection.up);
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(start),
            next: roundOverMatch(afterPush, winner: GamePlayer.first),
            legalMoves: const [pushUp],
            resolution: _pushResolution,
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();
    await _finishReplay(tester);

    expect(felt, ['select', 'win']);
  });

  testWidgets('feels a push that leaves the round ongoing', (tester) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'push-ongoing',
    );
    const afterPush = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 0),
      ],
      snapshotHash: 'push-ongoing-next',
    );
    const pushUp = GameMove(pieceId: 0, direction: GameDirection.up);
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(start),
            next: matchOf(afterPush, hash: 'next'),
            legalMoves: const [pushUp],
            resolution: _pushResolution,
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);

    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();
    await _finishReplay(tester);

    expect(felt, [
      'select',
      'push',
    ]);
  });

  testWidgets('stays silent when a tap changes nothing', (tester) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 0, y: 0),
      ],
      snapshotHash: 'silent',
    );
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(start)),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);

    // An empty cell, an opposing piece, and an own piece with no legal move.
    await tester.tapAt(cellCenter(4, 4));
    await tester.tapAt(cellCenter(0, 0));
    await tester.tapAt(cellCenter(2, 2));
    await tester.pump();

    expect(felt, isEmpty);
  });

  testWidgets('stays silent when applying a move fails', (tester) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2)],
      snapshotHash: 'failing',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine(
            initial: [matchOf(start)],
            moveResults: [StateError('bridge unavailable')],
            legalMovesFor: (_) => const [move],
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);

    await tester.tapAt(cellCenter(2, 2));
    felt.clear();
    await tester.tapAt(cellCenter(2, 3));
    await tester.pump();

    expect(felt, isEmpty);
  });

  testWidgets('says nothing when the same piece is tapped again', (
    tester,
  ) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2)],
      snapshotHash: 'reselect',
    );
    const moveDown = GameMove(pieceId: 0, direction: GameDirection.down);
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(start),
            next: matchOf(start, hash: 'next'),
            legalMoves: const [moveDown],
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.pump();

    expect(felt, ['select']);

    felt.clear();
    await tester.tapAt(cellCenter(2, 2));
    await tester.pump();

    expect(felt, isEmpty);
  });

  testWidgets('feels a move that lands on retry', (tester) async {
    const start = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'retry-feel',
    );
    const afterPush = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 1),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 0),
      ],
      snapshotHash: 'retry-feel-next',
    );
    const pushUp = GameMove(pieceId: 0, direction: GameDirection.up);
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine(
            initial: [matchOf(start)],
            moveResults: [
              StateError('bridge unavailable'),
              moveResultOf(
                next: matchOf(afterPush, hash: 'next'),
                resolution: _pushResolution,
              ),
            ],
            legalMovesFor: (_) => const [pushUp],
          ),
        ),
      ),
    );

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(2, 2));
    await tester.tapAt(cellCenter(2, 1));
    await tester.pump();
    felt.clear();

    // The board advances on retry, so it must feel like the push it is.
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await _finishReplay(tester);

    expect(felt, ['push']);
  });

  testWidgets('says nothing when retrying initialization', (tester) async {
    const ready = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'init-retry',
    );
    final feedback = _RecordingFeedback();
    final felt = feedback.events;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          feedback: feedback,
          rulesEngine: FakeRulesEngine(
            initial: [StateError('bridge unavailable'), ready],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(felt, isEmpty);
  });

  testWidgets('shows a finished round and advances past it', (tester) async {
    const finalBoard = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.damaged)],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'round-1-final',
    );
    const nextBoard = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.normal)],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'round-2',
    );
    final engine = FakeRulesEngine(
      initial: [roundOverMatch(finalBoard, winner: GamePlayer.first)],
      advanceResults: [matchOf(nextBoard, firstWins: 1, hash: 'round-2-match')],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    expect(find.text('ROUND COMPLETE'), findsOneWidget);
    expect(find.text('MATCH COMPLETE'), findsNothing);
    final roundScope = tester.widget<Container>(
      find.byKey(const Key('result-scope-round')),
    );
    expect(
      (roundScope.decoration! as BoxDecoration).color,
      _sharedPanelColor,
    );
    expect(_inOverlay('Azure Expedition'), findsOneWidget);
    expect(find.text('takes the round'), findsOneWidget);
    expect(find.text('by knockout'), findsOneWidget);
    expect(find.text('1 - 0'), findsOneWidget);
    // The board that ended the round is what the result sits over.
    expect(find.byType(RoundBoard), findsOneWidget);
    // Neither player is on turn while the result is up.

    await tester.tap(find.text('Start Next Round'));
    await tester.pump();

    expect(engine.advanceCount, 1);
    _expectActiveTurn(tester, GamePlayer.second);
    expect(find.text('Start Next Round'), findsNothing);
  });

  testWidgets('shows each player their round wins', (tester) async {
    const board = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'scored',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(board, firstWins: 1),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('round-wins-first-1')), findsOneWidget);
    expect(find.byKey(const Key('round-wins-second-0')), findsOneWidget);
  });

  testWidgets('states the result without truncating it', (tester) async {
    const finalBoard = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [],
      winner: GamePlayer.second,
      winReason: GameWinReason.immobilization,
      snapshotHash: 'legible',
    );
    addTearDown(tester.view.reset);

    for (final size in const [Size(320, 480), Size(390, 844)]) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            key: ValueKey(size),
            rulesEngine: FakeRulesEngine.playing(
              initial: roundOverMatch(
                finalBoard,
                winner: GamePlayer.second,
                reason: GameWinReason.immobilization,
                firstWins: 0,
                secondWins: 1,
              ),
            ),
          ),
        ),
      );

      for (final finder in [
        find.byKey(const Key('result-scope-round')),
        find.widgetWithText(FilledButton, 'Start Next Round'),
      ]) {
        final rect = tester.getRect(finder);
        expect(
          rect.left >= 0 &&
              rect.top >= 0 &&
              rect.right <= size.width &&
              rect.bottom <= size.height,
          isTrue,
          reason: 'result rect at $size: $rect',
        );
      }

      // Ellipsis is silent: it raises no exception and passes every layout
      // assertion while removing the half that says what happened.
      for (final text in const [
        'ROUND COMPLETE',
        'Ember Expedition',
        'takes the round',
        'by immobilization',
        'Start Next Round',
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(
          _inOverlay(text),
        );

        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '"$text" is cut off at $size',
        );
      }
    }
  });

  testWidgets('opens opponent choices before the first move', (tester) async {
    const board = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'opponent-sheet',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(board)),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('opponent-control')));
    await tester.pumpAndSettle();

    expect(find.text('Opponent'), findsWidgets);
    expect(find.text('Minimax'), findsOneWidget);
    for (final choice in const ['human', 'random', 'greedy', 'minimax']) {
      expect(
        tester.getRect(find.byKey(Key('opponent-choice-$choice'))).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
        reason: '$choice is reachable',
      );
    }
  });

  testWidgets(
    'keeps opponent sheet labels legible against its dark background',
    (tester) async {
      const board = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [],
        pieces: [],
        snapshotHash: 'opponent-sheet-contrast',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            rulesEngine: FakeRulesEngine.playing(initial: matchOf(board)),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('opponent-control')));
      await tester.pumpAndSettle();

      final background = tester
          .widget<BottomSheet>(find.byType(BottomSheet))
          .backgroundColor;
      expect(background, isNotNull);

      for (final label in const [
        'Opponent',
        'Human',
        'Random',
        'Greedy',
        'Minimax',
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        final foreground = paragraph.text.style?.color;
        expect(foreground, isNotNull, reason: '$label has a resolved color');
        expect(
          _contrastRatio(foreground!, background!),
          greaterThanOrEqualTo(4.5),
          reason: '$label must remain legible against the sheet background',
        );
      }
    },
  );

  testWidgets('keeps opponent choices locked after the first move', (
    tester,
  ) async {
    const initialSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'opponent-lock-initial',
    );
    const nextSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
      snapshotHash: 'opponent-lock-next',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initialSnapshot),
      next: matchOf(nextSnapshot, hash: 'opponent-lock-match'),
      legalMoves: const [move],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(0, 0));
    await tester.tapAt(cellCenter(0, 1));
    await tester.pump();
    await _finishReplay(tester);

    await tester.tap(find.byKey(const Key('opponent-control')));
    await tester.pumpAndSettle();

    expect(find.text('Minimax'), findsNothing);
  });

  testWidgets('selects an opponent from the explicit bottom sheet', (
    tester,
  ) async {
    const board = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'opponent',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine.playing(initial: matchOf(board)),
        ),
      ),
    );

    expect(_inPanel('second', 'Ember Expedition'), findsOneWidget);

    for (final choice in const ['random', 'greedy', 'minimax', 'human']) {
      await _selectOpponent(tester, choice);

      expect(
        find.descendant(
          of: find.byKey(const Key('opponent-control')),
          matching: find.text(
            'Opponent: ${switch (choice) {
              'random' => 'Random',
              'greedy' => 'Greedy',
              'minimax' => 'Minimax',
              _ => 'Human',
            }}',
          ),
        ),
        findsOneWidget,
        reason: choice,
      );
    }

    expect(_inPanel('second', 'Ember Expedition'), findsOneWidget);
    expect(_inPanel('first', 'Azure Expedition'), findsOneWidget);
  });

  testWidgets('reschedules a bot after dismissing opponent selection', (
    tester,
  ) async {
    const board = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [],
      snapshotHash: 'dismiss-opponent-sheet',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine(
      initial: [matchOf(board)],
      moveResults: [
        moveResultOf(
          next: matchOf(board, hash: 'dismissed-sheet-bot-move'),
          resolution: testMoveResolution,
        ),
      ],
      legalMovesFor: (_) => const [move],
      botMove: (_, _) => move,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(rulesEngine: engine),
      ),
    );
    await _selectOpponent(tester, 'random');

    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('opponent-control')));
    await tester.pump();
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 300));

    expect(engine.botRequests, isEmpty);
    await tester.pump(const Duration(milliseconds: 450));
    expect(engine.botRequests, [BotPolicy.random]);
  });

  testWidgets('lets the bot answer after a pause, not instantly', (
    tester,
  ) async {
    const botTurn = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 1, owner: GamePlayer.second, x: 0, y: 0)],
      snapshotHash: 'bot-turn',
    );
    const answered = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 1, owner: GamePlayer.second, x: 0, y: 1)],
      snapshotHash: 'bot-answered',
    );
    const move = GameMove(pieceId: 1, direction: GameDirection.down);
    final engine = FakeRulesEngine(
      initial: [matchOf(botTurn)],
      moveResults: [
        moveResultOf(
          next: matchOf(answered, hash: 'answered-match'),
          resolution: _secondBotDownResolution,
        ),
      ],
      legalMovesFor: (_) => const [move],
      botMove: (_, _) => move,
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));
    await _selectOpponent(tester, 'random');

    // The board must not change while the person is still reading it.
    expect(engine.appliedMoves, isEmpty);

    await tester.pump(const Duration(milliseconds: 450));
    await _finishReplay(tester);

    expect(engine.appliedMoves, [move]);
    expect(engine.botRequests, [BotPolicy.random]);
    _expectActiveTurn(tester, GamePlayer.first);
  });

  testWidgets('cancels a pending bot move when the opponent changes', (
    tester,
  ) async {
    const botTurn = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [],
      snapshotHash: 'cancelled',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine(
      initial: [matchOf(botTurn)],
      moveResults: [
        moveResultOf(
          next: matchOf(botTurn, hash: 'unused'),
          resolution: testMoveResolution,
        ),
      ],
      legalMovesFor: (_) => const [move],
      botMove: (_, _) => move,
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));
    await _selectOpponent(tester, 'random');
    // Hand the seat back to a person before the pause elapses.
    await tester.pump(const Duration(milliseconds: 200));
    await _selectOpponent(tester, 'human');
    await tester.pump(const Duration(milliseconds: 600));

    expect(engine.appliedMoves, isEmpty);
    expect(_inPanel('second', 'Ember Expedition'), findsOneWidget);
  });

  testWidgets('refuses a tap on the seat a bot is about to play', (
    tester,
  ) async {
    const botTurn = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 1, owner: GamePlayer.second, x: 0, y: 0)],
      snapshotHash: 'bot-seat',
    );
    const answered = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 1, owner: GamePlayer.second, x: 0, y: 1)],
      snapshotHash: 'bot-seat-answered',
    );
    const move = GameMove(pieceId: 1, direction: GameDirection.down);
    final engine = FakeRulesEngine(
      initial: [matchOf(botTurn)],
      moveResults: [
        moveResultOf(
          next: matchOf(answered, hash: 'bot-seat-next'),
          resolution: _secondBotDownResolution,
        ),
      ],
      legalMovesFor: (state) =>
          state.round.snapshotHash == 'bot-seat' ? const [move] : const [],
      botMove: (_, _) => move,
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));
    await _selectOpponent(tester, 'random');

    // Inside the pause it is still the bot's turn and its moves are still the
    // legal ones, so without a turn guard these two taps play its move for it.
    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(0, 0));
    await tester.tapAt(cellCenter(0, 1));
    await tester.pump();

    expect(engine.appliedMoves, isEmpty);

    // The bot still plays the move itself once the pause is up.
    await tester.pump(const Duration(milliseconds: 600));

    expect(engine.appliedMoves, [move]);
  });

  testWidgets('stops repeating a bot move that failed until Retry', (
    tester,
  ) async {
    const botTurn = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [],
      snapshotHash: 'bot-fails',
    );
    const answered = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'bot-recovered',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine(
      initial: [matchOf(botTurn)],
      moveResults: [
        StateError('the bridge refused the move'),
        moveResultOf(
          next: matchOf(answered, hash: 'bot-recovered-match'),
          resolution: testMoveResolution,
        ),
      ],
      legalMovesFor: (_) => const [move],
      botMove: (_, _) => move,
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));
    await _selectOpponent(tester, 'random');
    await tester.pump(const Duration(milliseconds: 600));

    expect(engine.botRequests, hasLength(1));
    expect(find.textContaining('Unable to update round'), findsOneWidget);

    // A failed move leaves the round untouched, so it is still the bot's
    // turn. Waiting must not turn that into a native call every pause.
    for (var pause = 0; pause < 4; pause++) {
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(engine.botRequests, hasLength(1));

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(engine.botRequests, hasLength(2));
    expect(engine.appliedMoves, [move, move]);
    expect(find.textContaining('Unable to update round'), findsNothing);
  });

  testWidgets(
    'drops a stranded bot error when the seat turns human',
    (
      tester,
    ) async {
      const botTurn = GameSnapshot(
        currentPlayer: GamePlayer.second,
        tiles: [],
        pieces: [],
        snapshotHash: 'bot-stranded',
      );
      const move = GameMove(pieceId: 0, direction: GameDirection.down);
      final engine = FakeRulesEngine(
        initial: [matchOf(botTurn)],
        moveResults: [StateError('the bridge refused the move')],
        legalMovesFor: (_) => const [move],
        botMove: (_, _) => move,
      );

      await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));
      await _selectOpponent(tester, 'random');
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('Unable to update round'), findsOneWidget);

      // Retry still points at a bot move, so handing the seat back to a person
      // would leave a banner whose only button does nothing.
      await _selectOpponent(tester, 'human');

      expect(_inPanel('second', 'Ember Expedition'), findsOneWidget);
      expect(find.textContaining('Unable to update round'), findsNothing);
    },
  );

  testWidgets('feels a round the bot won as a win, not as a move', (
    tester,
  ) async {
    const botTurn = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 1, owner: GamePlayer.second, x: 0, y: 0)],
      snapshotHash: 'bot-wins',
    );
    const won = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 1, owner: GamePlayer.second, x: 0, y: 1)],
      winner: GamePlayer.second,
      winReason: GameWinReason.knockout,
      snapshotHash: 'bot-won',
    );
    const move = GameMove(pieceId: 1, direction: GameDirection.down);
    final feedback = _RecordingFeedback();
    final engine = FakeRulesEngine(
      initial: [matchOf(botTurn)],
      moveResults: [
        moveResultOf(
          next: roundOverMatch(
            won,
            winner: GamePlayer.second,
            firstWins: 0,
            secondWins: 1,
            hash: 'bot-won-match',
          ),
          resolution: _secondBotDownResolution,
        ),
      ],
      legalMovesFor: (_) => const [move],
      botMove: (_, _) => move,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(feedback: feedback, rulesEngine: engine),
      ),
    );
    await _selectOpponent(tester, 'random');
    feedback.events.clear();
    await tester.pump(const Duration(milliseconds: 450));
    await _finishReplay(tester);

    expect(feedback.events, ['win']);
  });

  testWidgets('fits the longest opponent label on a narrow screen', (
    tester,
  ) async {
    const botTurn = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [],
      snapshotHash: 'narrow-bot',
    );
    addTearDown(tester.view.reset);
    tester.view
      ..physicalSize = const Size(320, 480)
      ..devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          rulesEngine: FakeRulesEngine(
            initial: [matchOf(botTurn, firstWins: 1, secondWins: 1)],
          ),
        ),
      ),
    );

    await _selectOpponent(tester, 'minimax');

    final opponentValue = find.descendant(
      of: find.byKey(const Key('opponent-control')),
      matching: find.text('Opponent: Minimax'),
    );
    expect(opponentValue, findsOneWidget);
    expect(tester.takeException(), isNull);

    final label = tester.renderObject<RenderParagraph>(
      opponentValue,
    );

    expect(label.didExceedMaxLines, isFalse);
  });

  testWidgets('keeps a valid board visible and retries a failed move', (
    tester,
  ) async {
    const initialSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'retry-move',
    );
    const nextSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
      snapshotHash: 'move-retried',
    );
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    final engine = FakeRulesEngine(
      initial: [matchOf(initialSnapshot)],
      moveResults: [
        StateError('bridge unavailable'),
        moveResultOf(
          next: matchOf(nextSnapshot, hash: 'next'),
          resolution: testMoveResolution,
        ),
      ],
      legalMovesFor: (_) => const [move],
    );

    await tester.pumpWidget(MaterialApp(home: GamePage(rulesEngine: engine)));

    final cellCenter = _cellCenterOf(tester);

    await tester.tapAt(cellCenter(0, 0));
    await tester.tapAt(cellCenter(0, 1));
    await tester.pump();

    _expectActiveTurn(tester, GamePlayer.first);
    expect(find.textContaining('Unable to update round'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await _finishReplay(tester);

    expect(engine.appliedMoves, [move, move]);
    _expectActiveTurn(tester, GamePlayer.second);
    expect(find.textContaining('Unable to update round'), findsNothing);
  });
}

/// Maps a board cell to the point to tap for it.
Offset Function(int x, int y) _cellCenterOf(WidgetTester tester) {
  final boardRect = tester.getRect(
    find.byKey(const Key('round-board-canvas')),
  );
  final board = tester.widget<RoundBoard>(find.byType(RoundBoard));
  final geometry = BoardGeometry.fromSnapshot(board.snapshot, boardRect.size);
  return (x, y) => boardRect.topLeft + geometry.cellCenter(x, y);
}

Future<void> _selectOpponent(
  WidgetTester tester,
  String opponent, {
  bool settle = false,
}) async {
  await tester.tap(find.byKey(const Key('opponent-control')));
  await tester.pumpAndSettle();
  final choice = find.byKey(Key('opponent-choice-$opponent'));
  await tester.ensureVisible(choice);
  await tester.tap(choice);
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  }
}

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

Future<void> _finishReplay(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

/// Scopes a text finder to one player's panel.
Finder _inPanel(String seat, String text) {
  return find.descendant(
    of: find.byKey(Key('player-panel-$seat')),
    matching: find.text(text),
  );
}

/// Scopes a text finder to the result overlay, since the panels carry the
/// player names too.
Finder _inOverlay(String text) {
  return find.descendant(
    of: find.byKey(const Key('result-overlay')),
    matching: find.text(text),
  );
}

/// Records what the page reported, without asserting how it is felt.
final class _RecordingFeedback implements RoundFeedback {
  final List<String> events = [];

  @override
  void pieceSelected() => events.add('select');

  @override
  void moveApplied() => events.add('move');

  @override
  void pushApplied() => events.add('push');

  @override
  void roundWon() => events.add('win');
}

/// Reads the active side off the white outline around the colored team mark.
void _expectActiveTurn(WidgetTester tester, GamePlayer player) {
  for (final seat in GamePlayer.values) {
    final mark = tester.widget<Container>(
      find.byKey(Key('player-mark-${seat.name}')),
    );
    final decoration = mark.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(
      decoration.color,
      switch (seat) {
        GamePlayer.first => _firstPlayerColor,
        GamePlayer.second => _secondPlayerColor,
      },
      reason: 'the ${seat.name} team color',
    );
    expect(
      border.top.color,
      seat == player ? Colors.white : Colors.transparent,
      reason: 'the ${seat.name} turn outline',
    );
  }
}
