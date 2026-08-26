import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/view/production_sprite_set.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/l10n/l10n.dart';
import 'package:ttush_push/src/rust/api.dart';

const double _boardSide = 250;
const double _cellSize = _boardSide / 5;

const _voidColor = Color(0xFF0B0D12);
const _environmentColor = Color(0xFF34445C);
const _footholdColor = Color(0xFFE7ECF5);
const _slabShadowColor = Color(0xFFC5CBD6);
const _damagedFootholdColor = Color(0xFFF3CE8E);
const _crackColor = Color(0xFF6B4A16);
const _firstPlayerColor = Color(0xFF2A48DF);
const _secondPlayerColor = Color(0xFFE14B4B);
const _destinationColor = Color(0xFF53D769);
const _productionAzureColor = Color(0xFF1261A0);
const _productionEmberColor = Color(0xFF9C2C22);
const _productionIntactColor = Color(0xFF7289A8);
const _productionDamagedColor = Color(0xFFB4793C);
const _productionHoleColor = Color(0xFF7D6C91);

void main() {
  const emptySnapshot = GameSnapshot(
    currentPlayer: GamePlayer.first,
    tiles: [],
    pieces: [],
    snapshotHash: 'board',
  );

  test('derives rectangular non-zero-origin geometry from tiles', () {
    final geometry = BoardGeometry.fromSnapshot(
      const GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [
          GameTile(x: 4, y: 7, kind: GameTileKind.normal),
          GameTile(x: 6, y: 7, kind: GameTileKind.hole),
          GameTile(x: 6, y: 8, kind: GameTileKind.normal),
        ],
        pieces: [],
        snapshotHash: 'irregular',
      ),
      const Size(300, 200),
    );

    expect(geometry.minX, 4);
    expect(geometry.minY, 7);
    expect(geometry.columnCount, 3);
    expect(geometry.rowCount, 2);
    expect(geometry.cellAt(geometry.cellCenter(6, 8)), (6, 8));
    expect(
      geometry.cellCenter(4, 7).dy,
      greaterThan(geometry.cellCenter(6, 8).dy),
    );
    expect(
      geometry.cellAt(
        Offset(
          geometry.cellCenter(6, 8).dx,
          geometry.origin.dy + geometry.cellSize / 2,
        ),
      ),
      (6, 8),
    );
    expect(geometry.cellAt(const Offset(301, 2)), isNull);
  });

  testWidgets('forwards the tapped board cell to its callback', (tester) async {
    var tappedCell = (-1, -1);

    await tester.pumpWidget(
      _boardHarness(
        snapshot: emptySnapshot,
        legalMoves: const [],
        selectedPieceId: null,
        onCellTap: (x, y) => tappedCell = (x, y),
      ),
    );

    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    await tester.tapAt(
      Offset(
        boardRect.left + boardRect.width * 0.5,
        boardRect.top + boardRect.height * 0.7,
      ),
    );

    expect(tappedCell, (2, 1));
  });

  testWidgets('maps only present irregular tiles from their Rust coordinates', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 4, y: 7, kind: GameTileKind.normal),
        GameTile(x: 6, y: 7, kind: GameTileKind.hole),
        GameTile(x: 6, y: 8, kind: GameTileKind.normal),
      ],
      pieces: [],
      snapshotHash: 'irregular-taps',
    );
    final geometry = BoardGeometry.fromSnapshot(
      snapshot,
      const Size(_boardSide, _boardSide),
    );
    var tappedCell = (-1, -1);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: _boardSide,
            height: _boardSide,
            child: RoundBoard(
              snapshot: snapshot,
              legalMoves: const [],
              selectedPieceId: null,
              onCellTap: (x, y) => tappedCell = (x, y),
            ),
          ),
        ),
      ),
    );

    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    await tester.tapAt(boardRect.topLeft + geometry.cellCenter(6, 8));
    expect(tappedCell, (6, 8));

    tappedCell = (-1, -1);
    await tester.tapAt(boardRect.topLeft + geometry.cellCenter(5, 7));
    expect(tappedCell, (-1, -1));

    await tester.tapAt(boardRect.topLeft + const Offset(2, 2));
    expect(tappedCell, (-1, -1));
  });

  testWidgets('does not dispatch a cell when a tap is canceled', (
    tester,
  ) async {
    var tappedCell = (-1, -1);

    await tester.pumpWidget(
      _boardHarness(
        snapshot: emptySnapshot,
        legalMoves: const [],
        selectedPieceId: null,
        onCellTap: (x, y) => tappedCell = (x, y),
      ),
    );

    final boardRect = tester.getRect(
      find.byKey(const Key('round-board-canvas')),
    );
    final gesture = await tester.startGesture(boardRect.center);
    await gesture.moveTo(boardRect.bottomRight + const Offset(20, 20));
    await gesture.up();

    expect(tappedCell, (-1, -1));
  });

  testWidgets('renders nothing without usable space', (tester) async {
    final board = RoundBoard(
      snapshot: emptySnapshot,
      legalMoves: const [],
      selectedPieceId: null,
      onCellTap: (_, _) {},
    );

    await tester.pumpWidget(
      MaterialApp(home: UnconstrainedBox(child: board)),
    );
    expect(find.byKey(const Key('round-board-canvas')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: SizedBox.square(dimension: 0, child: board)),
      ),
    );
    expect(find.byKey(const Key('round-board-canvas')), findsNothing);
  });

  testWidgets('keeps fallback unresolved and switches the complete set once', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 2, y: 0, kind: GameTileKind.hole),
        GameTile(x: 3, y: 0, kind: GameTileKind.normal),
        GameTile(x: 4, y: 0, kind: GameTileKind.damaged),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0),
        GamePiece(id: 1, owner: GamePlayer.second, x: 1, y: 0),
      ],
      snapshotHash: 'atomic-sprites',
    );
    final completion = Completer<ProductionSpriteSet>();
    final spriteSet = await _testSpriteSet();
    final disposalCounts = <ui.Image, int>{};
    final previousOnDispose = ui.Image.onDispose;
    ui.Image.onDispose = (image) {
      if (spriteSet.images.contains(image)) {
        disposalCounts.update(image, (count) => count + 1, ifAbsent: () => 1);
      }
      previousOnDispose?.call(image);
    };
    addTearDown(() => ui.Image.onDispose = previousOnDispose);

    await tester.pumpWidget(
      _boardHarness(
        snapshot: snapshot,
        legalMoves: const [],
        selectedPieceId: null,
        capturePixels: true,
        spriteLoader: (_) => completion.future,
      ),
    );

    final fallback = await _sampleCurrentBoard(tester);
    expect(fallback(_cellCenter(0, 0)), _firstPlayerColor);
    expect(fallback(_cellCenter(1, 0)), _secondPlayerColor);
    expect(fallback(_cellCenter(2, 0)), _voidColor);

    completion.complete(spriteSet);
    await tester.pump();

    final production = await _sampleCurrentBoard(tester);
    expect(production(_cellCenter(0, 0)), _productionAzureColor);
    expect(production(_cellCenter(1, 0)), _productionEmberColor);
    expect(production(_cellCenter(2, 0)), _voidColor);
    expect(production(_cellCenter(3, 0)), _productionIntactColor);
    expect(production(_cellCenter(4, 0)), _productionDamagedColor);
    expect(
      production(
        _cellCenter(2, 0) + const Offset(-_cellSize * 0.35, -_cellSize * 0.35),
      ),
      _productionHoleColor,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    expect(spriteSet.images, everyElement(_isDisposedImage));
    expect(
      spriteSet.images.map((image) => disposalCounts[image]),
      everyElement(1),
    );
  });

  testWidgets('keeps fallback and reports a controlled load failure once', (
    tester,
  ) async {
    final reports = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reports.add;
    addTearDown(() => FlutterError.onError = previousOnError);
    final failure = StateError('sprite decode failed');
    final failureStack = StackTrace.current;
    var loadCount = 0;

    await tester.pumpWidget(
      _boardHarness(
        snapshot: const GameSnapshot(
          currentPlayer: GamePlayer.first,
          tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.normal)],
          pieces: [],
          snapshotHash: 'sprite-failure',
        ),
        legalMoves: const [],
        selectedPieceId: null,
        capturePixels: true,
        spriteLoader: (_) {
          loadCount += 1;
          return Future<ProductionSpriteSet>.error(failure, failureStack);
        },
      ),
    );
    await tester.pump();

    final fallback = await _sampleCurrentBoard(tester);
    expect(fallback(_cellCenter(0, 0)), _footholdColor);
    expect(loadCount, 1);
    expect(reports, hasLength(1));
    expect(reports.single.exception, same(failure));
    expect(reports.single.stack, same(failureStack));
    expect(
      reports.single.context.toString(),
      contains('while loading production board sprites'),
    );

    await tester.pump();
    expect(reports, hasLength(1));
  });

  testWidgets('disposes a stale complete set without updating the board', (
    tester,
  ) async {
    final completion = Completer<ProductionSpriteSet>();
    final spriteSet = await _testSpriteSet();
    final disposalCounts = <ui.Image, int>{};
    final previousOnDispose = ui.Image.onDispose;
    ui.Image.onDispose = (image) {
      if (spriteSet.images.contains(image)) {
        disposalCounts.update(image, (count) => count + 1, ifAbsent: () => 1);
      }
      previousOnDispose?.call(image);
    };
    addTearDown(() => ui.Image.onDispose = previousOnDispose);

    await tester.pumpWidget(
      _boardHarness(
        snapshot: emptySnapshot,
        legalMoves: const [],
        selectedPieceId: null,
        spriteLoader: (_) => completion.future,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    completion.complete(spriteSet);
    await tester.pump();

    expect(spriteSet.images, everyElement(_isDisposedImage));
    expect(
      spriteSet.images.map((image) => disposalCounts[image]),
      everyElement(1),
    );
    spriteSet.dispose();
    expect(
      spriteSet.images.map((image) => disposalCounts[image]),
      everyElement(1),
    );
  });

  testWidgets('keeps one loader session across board and playback updates', (
    tester,
  ) async {
    var loadCount = 0;
    final completion = Completer<ProductionSpriteSet>();
    Future<ProductionSpriteSet> loader(AssetBundle _) {
      loadCount += 1;
      return completion.future;
    }

    await tester.pumpWidget(
      _boardHarness(
        snapshot: emptySnapshot,
        legalMoves: const [],
        selectedPieceId: null,
        spriteLoader: loader,
      ),
    );
    await tester.pumpWidget(
      _boardHarness(
        snapshot: emptySnapshot,
        legalMoves: const [],
        selectedPieceId: null,
        spriteLoader: loader,
        playback: const BoardPlayback(
          resolution: MoveResolution(
            actionKind: MoveActionKind.normal,
            mover: PieceTravel(
              pieceId: 0,
              fromX: 0,
              fromY: 0,
              toX: 0,
              toY: 1,
            ),
            tileTransition: TileTransition(
              x: 0,
              y: 0,
              from: GameTileKind.normal,
              to: GameTileKind.damaged,
            ),
          ),
          progress: 0.5,
          reducedMotion: false,
        ),
      ),
    );
    await tester.pumpWidget(
      _boardHarness(
        snapshot: const GameSnapshot(
          currentPlayer: GamePlayer.second,
          tiles: [],
          pieces: [],
          snapshotHash: 'updated-board',
        ),
        legalMoves: const [],
        selectedPieceId: 99,
        spriteLoader: loader,
      ),
    );

    expect(loadCount, 1);
  });

  testWidgets('distinguishes each tile kind by shape, not only by color', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 2, y: 0, kind: GameTileKind.hole),
      ],
      pieces: [],
      snapshotHash: 'tile-kinds',
    );

    final sample = await _paintAndSample(tester, snapshot: snapshot);

    expect(sample(_cellCenter(0, 0)), _footholdColor);
    expect(sample(_cellCenter(1, 0)), isNot(_footholdColor));
    // A hole keeps its center open, so the void shows through.
    expect(sample(_cellCenter(2, 0)), _voidColor);
    // An untouched cell has no tile at all and reads the same way.
    expect(sample(_cellCenter(4, 4)), _voidColor);
  });

  testWidgets('lets the environment show through a hole', (tester) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.hole),
      ],
      pieces: [],
      snapshotHash: 'environment-through-hole',
    );

    final sample = await _paintAndSample(
      tester,
      snapshot: snapshot,
      backgroundColor: _environmentColor,
    );

    expect(sample(_cellCenter(1, 0)), _environmentColor);
    expect(
      sample(
        _cellCenter(1, 0) + const Offset(-_cellSize * 0.35, -_cellSize * 0.35),
      ),
      isNot(_environmentColor),
    );
  });

  testWidgets('paints production sprites below destinations and playback', (
    tester,
  ) async {
    final spriteSet = await _testSpriteSet();
    const snapshot = GameSnapshot(
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
      snapshotHash: 'production-order',
    );
    const playback = BoardPlayback(
      resolution: MoveResolution(
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
          to: GameTileKind.hole,
        ),
      ),
      progress: 0.9,
      reducedMotion: true,
    );

    final sample = await _paintAndSample(
      tester,
      snapshot: snapshot,
      playback: playback,
      backgroundColor: _environmentColor,
      spriteLoader: (_) async => spriteSet,
    );

    expect(sample(_cellCenter(0, 0)), _environmentColor);
    expect(
      sample(
        _cellCenter(0, 0) + const Offset(-_cellSize * 0.35, -_cellSize * 0.35),
      ),
      _productionHoleColor,
    );
    expect(sample(_cellCenter(1, 0)), _productionAzureColor);
    expect(sample(_cellCenter(2, 0)), _productionEmberColor);
  });

  testWidgets('draws a crack across a damaged foothold', (tester) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.damaged),
      ],
      pieces: [],
      snapshotHash: 'crack',
    );

    final sample = await _paintAndSample(tester, snapshot: snapshot);
    final normalCell = _cellColors(sample, 0, 0);
    final damagedCell = _cellColors(sample, 1, 0);

    expect(damagedCell, contains(_damagedFootholdColor));
    expect(damagedCell, contains(_crackColor));
    expect(normalCell, isNot(contains(_crackColor)));
  });

  testWidgets('gives intact footholds a lower stone facet', (tester) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.normal)],
      pieces: [],
      snapshotHash: 'slab-facet',
    );

    final sample = await _paintAndSample(tester, snapshot: snapshot);

    expect(
      sample(_cellCenter(0, 0) + const Offset(0, _cellSize * 0.36)),
      _slabShadowColor,
    );
  });

  testWidgets('gives each player a distinct silhouette', (tester) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0),
        GamePiece(id: 1, owner: GamePlayer.second, x: 1, y: 0),
      ],
      snapshotHash: 'silhouettes',
    );

    final sample = await _paintAndSample(tester, snapshot: snapshot);
    const cloakCorner = Offset(-10, 12);

    expect(sample(_cellCenter(0, 0)), _firstPlayerColor);
    expect(sample(_cellCenter(1, 0)), _secondPlayerColor);
    // Azure's cloak is broad while Ember's robe is narrow at the same depth.
    expect(sample(_cellCenter(0, 0) + cloakCorner), _firstPlayerColor);
    expect(sample(_cellCenter(1, 0) + cloakCorner), isNot(_secondPlayerColor));
  });

  testWidgets('uses explorer bodies instead of prototype piece tokens', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.normal),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0),
        GamePiece(id: 1, owner: GamePlayer.second, x: 1, y: 0),
      ],
      snapshotHash: 'explorer-bodies',
    );

    final sample = await _paintAndSample(tester, snapshot: snapshot);
    const cloakHem = Offset(0, _cellSize * 0.38);

    expect(sample(_cellCenter(0, 0) + cloakHem), _firstPlayerColor);
    expect(sample(_cellCenter(1, 0) + cloakHem), _secondPlayerColor);
  });

  testWidgets('marks the selected piece', (tester) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [GameTile(x: 0, y: 0, kind: GameTileKind.normal)],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 0, y: 0)],
      snapshotHash: 'selection',
    );

    final unselected = await _paintAndSample(tester, snapshot: snapshot);
    final selected = await _paintAndSample(
      tester,
      snapshot: snapshot,
      selectedPieceId: 0,
    );

    expect(_cellColors(selected, 0, 0), isNot(_cellColors(unselected, 0, 0)));
  });

  testWidgets('separates a move destination from a push destination', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 2, y: 1),
      ],
      snapshotHash: 'destinations',
    );

    final sample = await _paintAndSample(
      tester,
      snapshot: snapshot,
      legalMoves: const [
        // Up is occupied by the opponent; the other three are empty.
        GameMove(pieceId: 0, direction: GameDirection.up),
        GameMove(pieceId: 0, direction: GameDirection.down),
        GameMove(pieceId: 0, direction: GameDirection.left),
        GameMove(pieceId: 0, direction: GameDirection.right),
      ],
      selectedPieceId: 0,
    );

    // An empty destination is a filled dot at its center.
    expect(sample(_cellCenter(2, 3)), _destinationColor);
    expect(sample(_cellCenter(1, 2)), _destinationColor);
    expect(sample(_cellCenter(3, 2)), _destinationColor);
    // An occupied destination is a ring, so its center still shows the piece
    // standing there while the ring marks the cell.
    expect(sample(_cellCenter(2, 1)), _secondPlayerColor);
    expect(
      sample(_cellCenter(2, 1) + const Offset(0, _cellSize * 0.37)),
      _destinationColor,
    );
  });

  testWidgets(
    'replays Rust-authored Push, fall, and collapse frames in order',
    (
      tester,
    ) async {
      const snapshot = GameSnapshot(
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
        snapshotHash: 'playback',
      );
      const mover = PieceTravel(
        pieceId: 0,
        fromX: 0,
        fromY: 0,
        toX: 1,
        toY: 0,
      );
      const collapse = TileTransition(
        x: 0,
        y: 0,
        from: GameTileKind.normal,
        to: GameTileKind.hole,
      );
      const displaced = PieceDisplacement(
        pieceId: 1,
        fromX: 1,
        fromY: 0,
        toX: 2,
        toY: 0,
      );

      final beforeImpact = await _paintAndSample(
        tester,
        snapshot: snapshot,
        playback: const BoardPlayback(
          resolution: MoveResolution(
            actionKind: MoveActionKind.push,
            mover: mover,
            displaced: displaced,
            tileTransition: collapse,
          ),
          progress: 0.2,
          reducedMotion: false,
        ),
      );
      expect(beforeImpact(_cellCenter(1, 0)), _secondPlayerColor);
      expect(
        beforeImpact(
          _cellCenter(0, 0) + const Offset(_cellSize * 5 / 9, 0),
        ),
        _firstPlayerColor,
      );

      final impact = await _paintAndSample(
        tester,
        snapshot: snapshot,
        playback: const BoardPlayback(
          resolution: MoveResolution(
            actionKind: MoveActionKind.push,
            mover: mover,
            displaced: displaced,
            tileTransition: collapse,
          ),
          progress: 0.43,
          reducedMotion: false,
        ),
      );
      final impactPoint =
          _cellCenter(1, 0) + const Offset(0, -_cellSize * 0.42);
      expect(impact(impactPoint), isNot(beforeImpact(impactPoint)));

      final displacedMidTravel = await _paintAndSample(
        tester,
        snapshot: snapshot,
        playback: const BoardPlayback(
          resolution: MoveResolution(
            actionKind: MoveActionKind.push,
            mover: mover,
            displaced: displaced,
            tileTransition: collapse,
          ),
          progress: 0.65,
          reducedMotion: false,
        ),
      );
      expect(
        displacedMidTravel(_cellCenter(1, 0) + const Offset(_cellSize / 2, 0)),
        _secondPlayerColor,
      );

      final beforeTransition = await _paintAndSample(
        tester,
        snapshot: snapshot,
        playback: const BoardPlayback(
          resolution: MoveResolution(
            actionKind: MoveActionKind.push,
            mover: mover,
            displaced: displaced,
            tileTransition: collapse,
          ),
          progress: 0.82,
          reducedMotion: false,
        ),
      );
      expect(
        beforeTransition(_cellCenter(0, 0) + const Offset(0, -_cellSize / 4)),
        _footholdColor,
      );

      final collapsed = await _paintAndSample(
        tester,
        snapshot: snapshot,
        playback: const BoardPlayback(
          resolution: MoveResolution(
            actionKind: MoveActionKind.push,
            mover: mover,
            displaced: displaced,
            tileTransition: collapse,
          ),
          progress: 0.9,
          reducedMotion: true,
        ),
        backgroundColor: _environmentColor,
      );

      expect(collapsed(_cellCenter(0, 0)), _environmentColor);

      const fallSnapshot = GameSnapshot(
        currentPlayer: GamePlayer.first,
        tiles: [
          GameTile(x: 2, y: 2, kind: GameTileKind.normal),
          GameTile(x: 3, y: 2, kind: GameTileKind.normal),
        ],
        pieces: [
          GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
          GamePiece(id: 1, owner: GamePlayer.second, x: 3, y: 2),
        ],
        snapshotHash: 'falls',
      );
      const fallMover = PieceTravel(
        pieceId: 0,
        fromX: 2,
        fromY: 2,
        toX: 3,
        toY: 2,
      );
      for (final direction in GameDirection.values) {
        final falling = await _paintAndSample(
          tester,
          snapshot: fallSnapshot,
          playback: BoardPlayback(
            resolution: MoveResolution(
              actionKind: MoveActionKind.push,
              mover: fallMover,
              displaced: PieceDisplacement(
                pieceId: 1,
                fromX: 3,
                fromY: 2,
                exitDirection: direction,
              ),
              tileTransition: const TileTransition(
                x: 2,
                y: 2,
                from: GameTileKind.normal,
                to: GameTileKind.damaged,
              ),
            ),
            progress: 0.65,
            reducedMotion: false,
          ),
        );
        final offset = switch (direction) {
          GameDirection.up => const Offset(0, _cellSize * 0.65),
          GameDirection.down => const Offset(0, -_cellSize * 0.65),
          GameDirection.left => const Offset(-_cellSize * 0.65, 0),
          GameDirection.right => const Offset(_cellSize * 0.65, 0),
        };
        expect(falling(_cellCenter(3, 2) + offset), _secondPlayerColor);
      }
    },
  );

  testWidgets('marks no destination without a resolvable selection', (
    tester,
  ) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2)],
      snapshotHash: 'no-destination',
    );
    const legalMoves = [GameMove(pieceId: 0, direction: GameDirection.down)];

    final unselected = await _paintAndSample(
      tester,
      snapshot: snapshot,
      legalMoves: legalMoves,
    );
    final unknownSelection = await _paintAndSample(
      tester,
      snapshot: snapshot,
      legalMoves: legalMoves,
      selectedPieceId: 99,
    );
    final otherPiece = await _paintAndSample(
      tester,
      snapshot: snapshot,
      legalMoves: const [GameMove(pieceId: 1, direction: GameDirection.down)],
      selectedPieceId: 0,
    );

    expect(unselected(_cellCenter(2, 3)), _voidColor);
    expect(unknownSelection(_cellCenter(2, 3)), _voidColor);
    expect(otherPiece(_cellCenter(2, 3)), _voidColor);
  });

  testWidgets('repaints only when its inputs change', (tester) async {
    const snapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [],
      pieces: [GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2)],
      snapshotHash: 'repaint',
    );
    const legalMoves = [GameMove(pieceId: 0, direction: GameDirection.down)];
    final sameMoves = List<GameMove>.of(legalMoves);
    void onCellTap(int _, int _) {}

    await tester.pumpWidget(
      _boardHarness(
        snapshot: snapshot,
        legalMoves: legalMoves,
        selectedPieceId: 0,
        onCellTap: onCellTap,
      ),
    );
    await tester.pumpWidget(
      _boardHarness(
        snapshot: snapshot,
        legalMoves: sameMoves,
        selectedPieceId: 0,
        onCellTap: onCellTap,
      ),
    );
    await tester.pumpWidget(
      _boardHarness(
        snapshot: snapshot,
        legalMoves: sameMoves,
        selectedPieceId: null,
        onCellTap: onCellTap,
        playback: const BoardPlayback(
          resolution: MoveResolution(
            actionKind: MoveActionKind.normal,
            mover: PieceTravel(
              pieceId: 0,
              fromX: 2,
              fromY: 2,
              toX: 2,
              toY: 3,
            ),
            tileTransition: TileTransition(
              x: 2,
              y: 2,
              from: GameTileKind.normal,
              to: GameTileKind.damaged,
            ),
          ),
          progress: 0,
          reducedMotion: false,
        ),
      ),
    );
    await tester.pumpWidget(
      _boardHarness(
        snapshot: snapshot,
        legalMoves: sameMoves,
        selectedPieceId: null,
        onCellTap: onCellTap,
        playback: const BoardPlayback(
          resolution: MoveResolution(
            actionKind: MoveActionKind.normal,
            mover: PieceTravel(
              pieceId: 0,
              fromX: 2,
              fromY: 2,
              toX: 2,
              toY: 3,
            ),
            tileTransition: TileTransition(
              x: 2,
              y: 2,
              from: GameTileKind.normal,
              to: GameTileKind.damaged,
            ),
          ),
          progress: 1,
          reducedMotion: false,
        ),
      ),
    );

    expect(find.byKey(const Key('round-board-canvas')), findsOneWidget);
  });
}

Offset _cellCenter(int x, int y) {
  return Offset((x + 0.5) * _cellSize, (5 - y - 0.5) * _cellSize);
}

/// Every distinct color inside one cell, so a test can assert that a mark is
/// present somewhere in it without pinning the exact pixel it lands on.
Set<Color> _cellColors(Color Function(Offset) sample, int x, int y) {
  final colors = <Color>{};
  for (var dx = 2; dx < _cellSize - 2; dx += 2) {
    for (var dy = 2; dy < _cellSize - 2; dy += 2) {
      colors.add(
        sample(
          Offset(x * _cellSize + dx, (4 - y) * _cellSize + dy),
        ),
      );
    }
  }
  return colors;
}

/// Paints the board once and returns a sampler over its pixels, addressed in
/// board-local coordinates.
Future<Color Function(Offset)> _paintAndSample(
  WidgetTester tester, {
  required GameSnapshot snapshot,
  List<GameMove> legalMoves = const [],
  int? selectedPieceId,
  BoardPlayback? playback,
  Color backgroundColor = _voidColor,
  ProductionSpriteLoader spriteLoader = _unresolvedSpriteLoader,
}) async {
  await tester.pumpWidget(
    _boardHarness(
      snapshot: snapshot,
      legalMoves: legalMoves,
      selectedPieceId: selectedPieceId,
      playback: playback,
      capturePixels: true,
      backgroundColor: backgroundColor,
      spriteLoader: spriteLoader,
    ),
  );

  await tester.pump();
  return _sampleCurrentBoard(tester);
}

Future<Color Function(Offset)> _sampleCurrentBoard(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('round-board-boundary')),
  );
  final image = (await tester.runAsync(boundary.toImage))!;
  final bytes = (await tester.runAsync(image.toByteData))!;
  final boardRect = tester.getRect(find.byKey(const Key('round-board-canvas')));
  final origin = boundary.localToGlobal(Offset.zero);
  final pixels = bytes.buffer.asUint8List();
  final width = image.width;

  Color sample(Offset local) {
    final point = boardRect.topLeft + local - origin;
    final index = (point.dy.floor() * width + point.dx.floor()) * 4;
    return Color.fromARGB(
      pixels[index + 3],
      pixels[index],
      pixels[index + 1],
      pixels[index + 2],
    );
  }

  return sample;
}

Widget _boardHarness({
  required GameSnapshot snapshot,
  required List<GameMove> legalMoves,
  required int? selectedPieceId,
  BoardPlayback? playback,
  void Function(int x, int y)? onCellTap,
  bool capturePixels = false,
  Color backgroundColor = _voidColor,
  ProductionSpriteLoader spriteLoader = _unresolvedSpriteLoader,
}) {
  final renderedSnapshot = _withFiveByFiveTestTiles(snapshot);
  final board = RoundBoard(
    snapshot: renderedSnapshot,
    legalMoves: legalMoves,
    selectedPieceId: selectedPieceId,
    playback: playback,
    onCellTap: onCellTap ?? (_, _) {},
    spriteLoader: spriteLoader,
  );
  final content = ColoredBox(color: backgroundColor, child: board);
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Center(
      child: SizedBox(
        width: _boardSide,
        height: _boardSide,
        child: capturePixels
            ? RepaintBoundary(
                key: const Key('round-board-boundary'),
                child: content,
              )
            : content,
      ),
    ),
  );
}

Future<ProductionSpriteSet> _unresolvedSpriteLoader(AssetBundle _) {
  return Completer<ProductionSpriteSet>().future;
}

Future<ProductionSpriteSet> _testSpriteSet() async {
  return ProductionSpriteSet(
    azureExplorer: await _solidImage(_productionAzureColor),
    emberExplorer: await _solidImage(_productionEmberColor),
    intactFoothold: await _solidImage(_productionIntactColor),
    damagedFoothold: await _solidImage(_productionDamagedColor),
    holeFoothold: await _cornerImage(_productionHoleColor),
  );
}

Future<ui.Image> _solidImage(Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  picture.dispose();
  return image;
}

Future<ui.Image> _cornerImage(Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..color = color;
  canvas
    ..drawRect(const Rect.fromLTWH(0, 0, 3, 3), paint)
    ..drawRect(const Rect.fromLTWH(5, 0, 3, 3), paint)
    ..drawRect(const Rect.fromLTWH(0, 5, 3, 3), paint)
    ..drawRect(const Rect.fromLTWH(5, 5, 3, 3), paint);
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  picture.dispose();
  return image;
}

bool _isDisposedImage(Object? value) {
  return value is ui.Image && value.debugDisposed;
}

/// Production snapshots include one tile record for every board coordinate.
/// These older rendering fixtures state only the terrain they care about, so
/// fill their omitted coordinates with holes before handing them to the board.
GameSnapshot _withFiveByFiveTestTiles(GameSnapshot snapshot) {
  final tiles = <GameTile>[
    for (var x = 0; x < 5; x++)
      for (var y = 0; y < 5; y++)
        if (!snapshot.tiles.any((tile) => tile.x == x && tile.y == y))
          GameTile(x: x, y: y, kind: GameTileKind.hole),
    ...snapshot.tiles,
  ];
  return GameSnapshot(
    currentPlayer: snapshot.currentPlayer,
    tiles: tiles,
    pieces: snapshot.pieces,
    counterPush: snapshot.counterPush,
    winner: snapshot.winner,
    winReason: snapshot.winReason,
    snapshotHash: snapshot.snapshotHash,
  );
}
