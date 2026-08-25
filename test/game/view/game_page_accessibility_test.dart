import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/coach/first_play_coach_store.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/src/rust/api.dart';

import '../../support/match_fixtures.dart';

void main() {
  testWidgets('shows the first coach step for the current incomplete version', (
    tester,
  ) async {
    final store = _FakeFirstPlayCoachStore();

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: store,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(
              const GameSnapshot(
                currentPlayer: GamePlayer.first,
                tiles: [],
                pieces: [],
                snapshotHash: 'first-coach-step',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Select an Azure explorer.'), findsOneWidget);
    expect(
      find.text('A filled glowing marker is a move. A ring is a Push.'),
      findsNothing,
    );
    expect(store.readVersions, [firstPlayCoachVersion]);
  });

  testWidgets('completes all coach steps and persists the current version', (
    tester,
  ) async {
    final store = _FakeFirstPlayCoachStore();

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: store,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(
              const GameSnapshot(
                currentPlayer: GamePlayer.first,
                tiles: [],
                pieces: [],
                snapshotHash: 'complete-coach',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(
      find.text('A filled glowing marker is a move. A ring is a Push.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(
      find.text(
        'A cracked foothold collapses when an explorer leaves it again.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(find.byKey(const Key('first-play-coach')), findsNothing);
    expect(store.writtenVersions, [firstPlayCoachVersion]);
  });

  testWidgets('dismisses the coach and persists the current version', (
    tester,
  ) async {
    final store = _FakeFirstPlayCoachStore();

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: store,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(
              const GameSnapshot(
                currentPlayer: GamePlayer.first,
                tiles: [],
                pieces: [],
                snapshotHash: 'dismiss-coach',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Dismiss'));
    await tester.pump();

    expect(find.byKey(const Key('first-play-coach')), findsNothing);
    expect(store.writtenVersions, [firstPlayCoachVersion]);
  });

  testWidgets('reopens a completed coach from HUD help without resetting it', (
    tester,
  ) async {
    final store = _FakeFirstPlayCoachStore(
      completedVersions: {firstPlayCoachVersion},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: store,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(
              const GameSnapshot(
                currentPlayer: GamePlayer.first,
                tiles: [],
                pieces: [],
                snapshotHash: 'reopen-coach',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('first-play-coach')), findsNothing);
    await tester.tap(find.byKey(const Key('coach-help')));
    await tester.pump();

    expect(find.text('Select an Azure explorer.'), findsOneWidget);
    expect(store.writtenVersions, isEmpty);
  });

  testWidgets('shows a new coach version after an older version completed', (
    tester,
  ) async {
    final store = _FakeFirstPlayCoachStore(
      completedVersions: {firstPlayCoachVersion - 1},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: store,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(
              const GameSnapshot(
                currentPlayer: GamePlayer.first,
                tiles: [],
                pieces: [],
                snapshotHash: 'new-coach-version',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Select an Azure explorer.'), findsOneWidget);
    expect(store.readVersions, [firstPlayCoachVersion]);
  });

  testWidgets('shows the coach when completion cannot be read', (
    tester,
  ) async {
    final store = _FakeFirstPlayCoachStore(
      readError: StateError('preferences unavailable'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: store,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(
              const GameSnapshot(
                currentPlayer: GamePlayer.first,
                tiles: [],
                pieces: [],
                snapshotHash: 'coach-read-failure',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Select an Azure explorer.'), findsOneWidget);
  });

  testWidgets('keeps the coach dismissed when completion cannot be written', (
    tester,
  ) async {
    final store = _FakeFirstPlayCoachStore(
      writeError: StateError('preferences unavailable'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: store,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(
              const GameSnapshot(
                currentPlayer: GamePlayer.first,
                tiles: [],
                pieces: [],
                snapshotHash: 'coach-write-failure',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Dismiss'));
    await tester.pump();

    expect(find.byKey(const Key('first-play-coach')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not reopen a coach dismissed during a pending read', (
    tester,
  ) async {
    final completion = Completer<bool>();
    final store = _FakeFirstPlayCoachStore(readResult: completion.future);

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: store,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(
              const GameSnapshot(
                currentPlayer: GamePlayer.first,
                tiles: [],
                pieces: [],
                snapshotHash: 'dismiss-during-coach-read',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coach-help')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('coach-dismiss')));
    await tester.pump();

    completion.complete(false);
    await tester.pump();

    expect(find.byKey(const Key('first-play-coach')), findsNothing);
  });

  testWidgets('does not close a coach opened during a pending read', (
    tester,
  ) async {
    final completion = Completer<bool>();
    final store = _FakeFirstPlayCoachStore(readResult: completion.future);

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: store,
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(
              const GameSnapshot(
                currentPlayer: GamePlayer.first,
                tiles: [],
                pieces: [],
                snapshotHash: 'open-during-coach-read',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coach-help')));
    await tester.pump();

    completion.complete(true);
    await tester.pump();

    expect(find.byKey(const Key('first-play-coach')), findsOneWidget);
  });

  testWidgets('keeps visual board actions available while the coach is open', (
    tester,
  ) async {
    const move = GameMove(pieceId: 0, direction: GameDirection.up);
    const initial = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 1)],
      snapshotHash: 'coach-board-action',
    );
    const next = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.damaged),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'coach-board-action-applied',
    );
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initial),
      next: matchOf(next, hash: 'coach-board-action-next'),
      legalMoves: const [move],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(),
          rulesEngine: engine,
        ),
      ),
    );
    await tester.pump();

    final cellCenter = _cellCenterOf(tester);
    final source = cellCenter(0, 1);
    final coachRect = tester.getRect(
      find.byKey(const Key('first-play-coach')),
    );
    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    expect(coachRect.overlaps(boardRect), isFalse);

    await tester.tapAt(source);
    await tester.pump();
    await tester.tapAt(cellCenter(0, 0));
    await tester.pump();

    expect(engine.appliedMoves, [move]);
    expect(find.byKey(const Key('first-play-coach')), findsOneWidget);
  });

  testWidgets('announces vertical destinations in visual board direction', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const move = GameMove(pieceId: 0, direction: GameDirection.down);
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'visual-direction',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(
            completedVersions: {firstPlayCoachVersion},
          ),
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(snapshot),
            legalMoves: const [move],
          ),
        ),
      ),
    );
    await tester.pump();

    tester.semantics.tap(
      find.semantics.byLabel(
        'Azure Expedition explorer, row 2, column 1, 1 available move',
      ),
    );
    await tester.pump();

    expect(
      find.semantics.byLabel('Up move to row 1, column 1'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('omits actionable board semantics while a bot owns the turn', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const move = GameMove(pieceId: 1, direction: GameDirection.down);
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 1, owner: GamePlayer.second, x: 0, y: 0)],
      snapshotHash: 'bot-turn-semantics',
    );
    final engine = FakeRulesEngine(
      initial: [matchOf(snapshot)],
      legalMovesFor: (_) => const [move],
      botMove: (_, _) => move,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(
            completedVersions: {firstPlayCoachVersion},
          ),
          rulesEngine: engine,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('opponent-control')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opponent-choice-random')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      find.semantics.byLabel(
        'Ember Expedition explorer, row 2, column 1, 1 available move',
      ),
      findsNothing,
    );
    expect(engine.botRequests, isEmpty);
    semantics.dispose();
  });

  testWidgets('applies and announces a normal semantic move after replay', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const move = GameMove(pieceId: 0, direction: GameDirection.right);
    const resolution = MoveResolution(
      actionKind: MoveActionKind.normal,
      mover: PieceTravel(pieceId: 0, fromX: 0, fromY: 0, toX: 1, toY: 0),
      tileTransition: TileTransition(
        x: 0,
        y: 0,
        from: GameTileKind.normal,
        to: GameTileKind.damaged,
      ),
    );
    const initial = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'semantic-normal-move',
    );
    const next = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 1, y: 0)],
      snapshotHash: 'semantic-normal-move-applied',
    );
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initial),
      next: matchOf(next, hash: 'semantic-normal-move-next'),
      legalMoves: const [move],
      resolution: resolution,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(
            completedVersions: {firstPlayCoachVersion},
          ),
          rulesEngine: engine,
        ),
      ),
    );
    await tester.pump();

    final explorer = find.semantics.byLabel(
      'Azure Expedition explorer, row 1, column 1, 1 available move',
    );
    tester.semantics.performAction(explorer, SemanticsAction.tap);
    await tester.pump();

    final destination = find.semantics.byLabel(
      'Right move to row 1, column 2',
    );
    tester.semantics.performAction(destination, SemanticsAction.tap);
    await tester.pump();

    expect(engine.appliedMoves, [move]);
    expect(
      find.semantics.byLabel('Move applied.'),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(
      tester.getSemantics(find.byKey(const Key('match-announcement'))),
      matchesSemantics(label: 'Move applied.', isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets('replaces the live region for repeated move announcements', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const humanMove = GameMove(pieceId: 0, direction: GameDirection.right);
    const botMove = GameMove(pieceId: 1, direction: GameDirection.left);
    const startingPieces = [
      GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0),
      GamePiece(id: 1, owner: GamePlayer.second, x: 1, y: 1),
    ];
    const initial = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
        GameTile(x: 1, y: 1, kind: GameTileKind.normal),
      ],
      pieces: startingPieces,
      snapshotHash: 'repeated-announcement-initial',
    );
    const afterHuman = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
        GameTile(x: 1, y: 1, kind: GameTileKind.normal),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 1, y: 0),
        GamePiece(id: 1, owner: GamePlayer.second, x: 1, y: 1),
      ],
      snapshotHash: 'repeated-announcement-after-human',
    );
    const afterBot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
        GameTile(x: 0, y: 1, kind: GameTileKind.normal),
        GameTile(x: 1, y: 1, kind: GameTileKind.damaged),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 1, y: 0),
        GamePiece(id: 1, owner: GamePlayer.second, x: 0, y: 1),
      ],
      snapshotHash: 'repeated-announcement-after-bot',
    );
    const humanResolution = MoveResolution(
      actionKind: MoveActionKind.normal,
      mover: PieceTravel(pieceId: 0, fromX: 0, fromY: 0, toX: 1, toY: 0),
      tileTransition: TileTransition(
        x: 0,
        y: 0,
        from: GameTileKind.normal,
        to: GameTileKind.damaged,
      ),
    );
    const botResolution = MoveResolution(
      actionKind: MoveActionKind.normal,
      mover: PieceTravel(pieceId: 1, fromX: 1, fromY: 1, toX: 0, toY: 1),
      tileTransition: TileTransition(
        x: 1,
        y: 1,
        from: GameTileKind.normal,
        to: GameTileKind.damaged,
      ),
    );
    final engine = FakeRulesEngine(
      initial: [
        matchOf(
          initial,
          startingPieces: startingPieces,
          hash: 'repeated-announcement-match-initial',
        ),
      ],
      moveResults: [
        moveResultOf(
          next: matchOf(
            afterHuman,
            startingPieces: startingPieces,
            hash: 'repeated-announcement-match-after-human',
          ),
          resolution: humanResolution,
        ),
        moveResultOf(
          next: matchOf(
            afterBot,
            startingPieces: startingPieces,
            hash: 'repeated-announcement-match-after-bot',
          ),
          resolution: botResolution,
        ),
      ],
      legalMovesFor: (state) => switch (state.snapshotHash) {
        'repeated-announcement-match-initial' => const [humanMove],
        'repeated-announcement-match-after-human' => const [botMove],
        _ => const [],
      },
      botMove: (_, _) => botMove,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(
            completedVersions: {firstPlayCoachVersion},
          ),
          rulesEngine: engine,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('opponent-control')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opponent-choice-random')));
    await tester.pumpAndSettle();
    tester.semantics.tap(
      find.semantics.byLabel(
        'Azure Expedition explorer, row 2, column 1, 1 available move',
      ),
    );
    await tester.pump();
    tester.semantics.tap(
      find.semantics.byLabel('Right move to row 2, column 2'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    final firstAnnouncement = tester.getSemantics(
      find.byKey(const Key('match-announcement')),
    );
    expect(
      firstAnnouncement,
      matchesSemantics(label: 'Move applied.', isLiveRegion: true),
    );

    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    final secondAnnouncement = tester.getSemantics(
      find.byKey(const Key('match-announcement')),
    );
    expect(
      secondAnnouncement,
      matchesSemantics(label: 'Move applied.', isLiveRegion: true),
    );
    expect(secondAnnouncement.id, isNot(firstAnnouncement.id));
    expect(engine.appliedMoves, [humanMove, botMove]);
    semantics.dispose();
  });

  testWidgets('applies and announces a semantic Push after replay', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const move = GameMove(pieceId: 0, direction: GameDirection.right);
    const resolution = MoveResolution(
      actionKind: MoveActionKind.push,
      mover: PieceTravel(pieceId: 0, fromX: 0, fromY: 0, toX: 1, toY: 0),
      displaced: PieceDisplacement(
        pieceId: 1,
        fromX: 1,
        fromY: 0,
        toX: 2,
        toY: 0,
      ),
      tileTransition: TileTransition(
        x: 0,
        y: 0,
        from: GameTileKind.normal,
        to: GameTileKind.damaged,
      ),
    );
    const initial = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
        GameTile(x: 2, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0),
        GamePiece(id: 1, owner: GamePlayer.second, x: 1, y: 0),
      ],
      snapshotHash: 'semantic-push',
    );
    const next = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
        GameTile(x: 2, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 1, y: 0),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 0),
      ],
      snapshotHash: 'semantic-push-applied',
    );
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initial),
      next: matchOf(next, hash: 'semantic-push-next'),
      legalMoves: const [move],
      resolution: resolution,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(
            completedVersions: {firstPlayCoachVersion},
          ),
          rulesEngine: engine,
        ),
      ),
    );
    await tester.pump();

    tester.semantics.tap(
      find.semantics.byLabel(
        'Azure Expedition explorer, row 1, column 1, 1 available move',
      ),
    );
    await tester.pump();
    tester.semantics.tap(
      find.semantics.byLabel(
        'Right Push to row 1, column 2, affecting Ember Expedition',
      ),
    );
    await tester.pump();

    expect(engine.appliedMoves, [move]);
    expect(find.semantics.byLabel('Push applied.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(
      tester.getSemantics(find.byKey(const Key('match-announcement'))),
      matchesSemantics(label: 'Push applied.', isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets('announces that board controls are disabled during playback', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const move = GameMove(pieceId: 0, direction: GameDirection.right);
    const initial = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'semantic-playback',
    );
    const next = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 1, y: 0)],
      snapshotHash: 'semantic-playback-applied',
    );
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initial),
      next: matchOf(next, hash: 'semantic-playback-next'),
      legalMoves: const [move],
      resolution: const MoveResolution(
        actionKind: MoveActionKind.normal,
        mover: PieceTravel(
          pieceId: 0,
          fromX: 0,
          fromY: 0,
          toX: 1,
          toY: 0,
        ),
        tileTransition: TileTransition(
          x: 0,
          y: 0,
          from: GameTileKind.normal,
          to: GameTileKind.damaged,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(
            completedVersions: {firstPlayCoachVersion},
          ),
          rulesEngine: engine,
        ),
      ),
    );
    await tester.pump();

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(0, 0));
    await tester.pump();
    await tester.tapAt(cellCenter(1, 0));
    await tester.pump();

    expect(
      find.semantics.byLabel(
        'Move resolution in progress. Board controls are disabled.',
      ),
      findsOne,
    );
    expect(
      find.semantics.byLabel(
        'Azure Expedition explorer, row 1, column 1, 1 available move',
      ),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets(
    'omits inert board cells and immovable explorers from semantics',
    (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      const snapshot = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [
          GameTile(x: 0, y: 0, kind: GameTileKind.normal),
          GameTile(x: 1, y: 0, kind: GameTileKind.hole),
        ],
        pieces: [
          GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0),
          GamePiece(id: 1, owner: GamePlayer.second, x: 1, y: 0),
        ],
        snapshotHash: 'semantic-inert-board',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            coachStore: _FakeFirstPlayCoachStore(
              completedVersions: {firstPlayCoachVersion},
            ),
            rulesEngine: FakeRulesEngine.playing(initial: matchOf(snapshot)),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.semantics.byLabel(
          'Azure Expedition explorer, row 1, column 1, 0 available moves',
        ),
        findsNothing,
      );
      expect(
        find.semantics.byLabel(
          'Ember Expedition explorer, row 1, column 2, 0 available moves',
        ),
        findsNothing,
      );
      semantics.dispose();
    },
  );

  testWidgets('keeps the match board and controls usable at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'large-text-match',
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(
            completedVersions: {firstPlayCoachVersion},
          ),
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(snapshot),
            legalMoves: const [
              GameMove(pieceId: 0, direction: GameDirection.right),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    expect(boardRect.width, greaterThan(0));
    expect(boardRect.height, greaterThan(0));
    expect(
      boardRect.left >= 0 &&
          boardRect.top >= 0 &&
          boardRect.right <= 320 &&
          boardRect.bottom <= 568,
      isTrue,
      reason: 'board rect: $boardRect',
    );
    expect(find.byKey(const Key('opponent-control')), findsOneWidget);
    expect(find.byKey(const Key('coach-help')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps coach actions visible at 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'large-text-coach',
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(),
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(snapshot),
            legalMoves: const [
              GameMove(pieceId: 0, direction: GameDirection.right),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    for (final key in const [
      Key('coach-next'),
      Key('coach-dismiss'),
      Key('coach-help'),
      Key('opponent-control'),
    ]) {
      final rect = tester.getRect(find.byKey(key));
      expect(
        rect.left >= 0 &&
            rect.top >= 0 &&
            rect.right <= 320 &&
            rect.bottom <= 568,
        isTrue,
        reason: '$key rect: $rect',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps match result actions visible at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 1, y: 0)],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'large-text-result',
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(),
          rulesEngine: FakeRulesEngine(
            initial: [
              matchOverMatch(snapshot, winner: GamePlayer.first),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final resultRect = tester.getRect(
      find.byKey(const Key('result-overlay')),
    );
    final actionRect = tester.getRect(
      find.widgetWithText(FilledButton, 'New Match'),
    );
    for (final rect in [resultRect, actionRect]) {
      expect(
        rect.left >= 0 &&
            rect.top >= 0 &&
            rect.right <= 320 &&
            rect.bottom <= 568,
        isTrue,
        reason: 'result rect: $rect',
      );
    }
    expect(actionRect.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(actionRect.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(find.byKey(const Key('first-play-coach')), findsNothing);
    expect(find.byKey(const Key('coach-help')), findsNothing);
    expect(find.text('Azure Expedition'), findsWidgets);
    expect(find.text('wins the match'), findsOneWidget);
    expect(find.text('by knockout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('announces a semantic explorer selection in a live region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const move = GameMove(pieceId: 0, direction: GameDirection.right);
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'semantic-selection-announcement',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(
            completedVersions: {firstPlayCoachVersion},
          ),
          rulesEngine: FakeRulesEngine.playing(
            initial: matchOf(snapshot),
            legalMoves: const [move],
          ),
        ),
      ),
    );
    await tester.pump();

    tester.semantics.tap(
      find.semantics.byLabel(
        'Azure Expedition explorer, row 1, column 1, 1 available move',
      ),
    );
    await tester.pump();

    expect(
      tester.getSemantics(find.byKey(const Key('match-announcement'))),
      matchesSemantics(
        label: 'Azure Expedition explorer selected. 1 destination available.',
        isLiveRegion: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('announces a recoverable move error in a live region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const move = GameMove(pieceId: 0, direction: GameDirection.right);
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'semantic-move-error',
    );
    final engine = FakeRulesEngine(
      initial: [matchOf(snapshot)],
      moveResults: [StateError('bridge unavailable')],
      legalMovesFor: (_) => const [move],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(
            completedVersions: {firstPlayCoachVersion},
          ),
          rulesEngine: engine,
        ),
      ),
    );
    await tester.pump();

    tester.semantics.tap(
      find.semantics.byLabel(
        'Azure Expedition explorer, row 1, column 1, 1 available move',
      ),
    );
    await tester.pump();
    tester.semantics.tap(
      find.semantics.byLabel('Right move to row 1, column 2'),
    );
    await tester.pump();

    expect(find.text('Retry'), findsOneWidget);
    final firstError = tester.getSemantics(
      find.byKey(const Key('action-error')),
    );
    expect(
      firstError,
      matchesSemantics(
        label: 'Unable to update round: Bad state: bridge unavailable',
        isLiveRegion: true,
      ),
    );
    expect(
      find.semantics.byLabel('Right move to row 1, column 2'),
      findsNothing,
    );

    final cellCenter = _cellCenterOf(tester);
    await tester.tapAt(cellCenter(1, 0));
    await tester.pump();
    expect(engine.appliedMoves, [move]);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    final repeatedError = tester.getSemantics(
      find.byKey(const Key('action-error')),
    );
    expect(
      repeatedError,
      matchesSemantics(
        label: 'Unable to update round: Bad state: bridge unavailable',
        isLiveRegion: true,
      ),
    );
    expect(repeatedError.id, isNot(firstError.id));
    semantics.dispose();
  });

  testWidgets('announces an initial bridge error in a live region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(
            completedVersions: {firstPlayCoachVersion},
          ),
          rulesEngine: FakeRulesEngine(
            initial: [StateError('bridge unavailable')],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Retry'), findsOneWidget);
    final firstError = tester.getSemantics(
      find.byKey(const Key('initial-error')),
    );
    expect(
      firstError,
      matchesSemantics(
        label: 'Unable to start round',
        isLiveRegion: true,
      ),
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();

    final repeatedError = tester.getSemantics(
      find.byKey(const Key('initial-error')),
    );
    expect(
      repeatedError,
      matchesSemantics(
        label: 'Unable to start round',
        isLiveRegion: true,
      ),
    );
    expect(repeatedError.id, isNot(firstError.id));
    semantics.dispose();
  });

  testWidgets('announces a round result after the winning replay commits', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const move = GameMove(pieceId: 0, direction: GameDirection.right);
    const initial = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'round-result-announcement',
    );
    const won = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 1, y: 0)],
      winner: GamePlayer.first,
      winReason: GameWinReason.immobilization,
      snapshotHash: 'round-result-announced',
    );
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initial),
      next: roundOverMatch(
        won,
        winner: GamePlayer.first,
        reason: GameWinReason.immobilization,
      ),
      legalMoves: const [move],
      resolution: const MoveResolution(
        actionKind: MoveActionKind.normal,
        mover: PieceTravel(
          pieceId: 0,
          fromX: 0,
          fromY: 0,
          toX: 1,
          toY: 0,
        ),
        tileTransition: TileTransition(
          x: 0,
          y: 0,
          from: GameTileKind.normal,
          to: GameTileKind.damaged,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(
            completedVersions: {firstPlayCoachVersion},
          ),
          rulesEngine: engine,
        ),
      ),
    );
    await tester.pump();

    tester.semantics.tap(
      find.semantics.byLabel(
        'Azure Expedition explorer, row 1, column 1, 1 available move',
      ),
    );
    await tester.pump();
    tester.semantics.tap(
      find.semantics.byLabel('Right move to row 1, column 2'),
    );
    await tester.pump();

    expect(engine.appliedMoves, [move]);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(
      tester.getSemantics(find.byKey(const Key('match-announcement'))),
      matchesSemantics(
        label: 'Azure Expedition takes the round by immobilization.',
        isLiveRegion: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('announces a match result after the winning replay commits', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const move = GameMove(pieceId: 0, direction: GameDirection.right);
    const initial = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'match-result-announcement',
    );
    const won = GameSnapshot(
      currentPlayer: GamePlayer.second,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 1, y: 0)],
      winner: GamePlayer.first,
      winReason: GameWinReason.knockout,
      snapshotHash: 'match-result-announced',
    );
    final engine = FakeRulesEngine.playing(
      initial: matchOf(initial, firstWins: 1),
      next: matchOverMatch(won, winner: GamePlayer.first),
      legalMoves: const [move],
      resolution: const MoveResolution(
        actionKind: MoveActionKind.normal,
        mover: PieceTravel(
          pieceId: 0,
          fromX: 0,
          fromY: 0,
          toX: 1,
          toY: 0,
        ),
        tileTransition: TileTransition(
          x: 0,
          y: 0,
          from: GameTileKind.normal,
          to: GameTileKind.damaged,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          coachStore: _FakeFirstPlayCoachStore(
            completedVersions: {firstPlayCoachVersion},
          ),
          rulesEngine: engine,
        ),
      ),
    );
    await tester.pump();

    tester.semantics.tap(
      find.semantics.byLabel(
        'Azure Expedition explorer, row 1, column 1, 1 available move',
      ),
    );
    await tester.pump();
    tester.semantics.tap(
      find.semantics.byLabel('Right move to row 1, column 2'),
    );
    await tester.pump();

    expect(engine.appliedMoves, [move]);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(
      tester.getSemantics(find.byKey(const Key('match-announcement'))),
      matchesSemantics(
        label: 'Azure Expedition wins the match by knockout. Score 2 to 0.',
        isLiveRegion: true,
      ),
    );
    semantics.dispose();
  });
}

Offset Function(int x, int y) _cellCenterOf(WidgetTester tester) {
  final boardRect = tester.getRect(
    find.byKey(const Key('round-board-canvas')),
  );
  final board = tester.widget<RoundBoard>(find.byType(RoundBoard));
  final geometry = BoardGeometry.fromSnapshot(board.snapshot, boardRect.size);
  return (x, y) => boardRect.topLeft + geometry.cellCenter(x, y);
}

final class _FakeFirstPlayCoachStore implements FirstPlayCoachStore {
  _FakeFirstPlayCoachStore({
    Set<int>? completedVersions,
    this.readError,
    this.writeError,
    this.readResult,
  }) : completedVersions = completedVersions ?? {};

  final Set<int> completedVersions;
  final Error? readError;
  final Error? writeError;
  final Future<bool>? readResult;
  final List<int> readVersions = [];
  final List<int> writtenVersions = [];

  @override
  Future<bool> isComplete({required int version}) async {
    readVersions.add(version);
    if (readError case final Error error) {
      throw error;
    }
    if (readResult case final Future<bool> result) {
      return result;
    }
    return completedVersions.contains(version);
  }

  @override
  Future<void> markComplete({required int version}) async {
    writtenVersions.add(version);
    if (writeError case final Error error) {
      throw error;
    }
    completedVersions.add(version);
  }
}
