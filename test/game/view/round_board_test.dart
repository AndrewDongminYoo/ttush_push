import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/src/rust/api.dart';

const double _boardSide = 250;
const double _cellSize = _boardSide / 5;

const _voidColor = Color(0xFF0B0D12);
const _footholdColor = Color(0xFFE7ECF5);
const _damagedFootholdColor = Color(0xFFF3CE8E);
const _crackColor = Color(0xFF6B4A16);
const _firstPlayerColor = Color(0xFF2A48DF);
const _secondPlayerColor = Color(0xFFE14B4B);
const _destinationColor = Color(0xFF53D769);

void main() {
  const emptySnapshot = GameSnapshot(
    currentPlayer: GamePlayer.first,
    tiles: [],
    pieces: [],
    snapshotHash: 'board',
  );

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

    expect(tappedCell, (2, 3));
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
    // A hole is the absence of a foothold, so the void shows through.
    expect(sample(_cellCenter(2, 0)), _voidColor);
    // An untouched cell has no tile at all and reads the same way.
    expect(sample(_cellCenter(4, 4)), _voidColor);
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
    const diagonal = Offset(12, 12);

    expect(sample(_cellCenter(0, 0)), _firstPlayerColor);
    expect(sample(_cellCenter(1, 0)), _secondPlayerColor);
    // The first player is a disc, so its diagonal corner is empty; the
    // second player is a rounded square, so the same corner is filled.
    expect(sample(_cellCenter(0, 0) + diagonal), isNot(_firstPlayerColor));
    expect(sample(_cellCenter(1, 0) + diagonal), _secondPlayerColor);
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

    await tester.pumpWidget(
      _boardHarness(
        snapshot: snapshot,
        legalMoves: legalMoves,
        selectedPieceId: 0,
      ),
    );
    await tester.pumpWidget(
      _boardHarness(
        snapshot: snapshot,
        legalMoves: sameMoves,
        selectedPieceId: 0,
      ),
    );
    await tester.pumpWidget(
      _boardHarness(
        snapshot: snapshot,
        legalMoves: sameMoves,
        selectedPieceId: null,
      ),
    );

    expect(find.byKey(const Key('round-board-canvas')), findsOneWidget);
  });
}

Offset _cellCenter(int x, int y) {
  return Offset((x + 0.5) * _cellSize, (y + 0.5) * _cellSize);
}

/// Every distinct color inside one cell, so a test can assert that a mark is
/// present somewhere in it without pinning the exact pixel it lands on.
Set<Color> _cellColors(Color Function(Offset) sample, int x, int y) {
  final colors = <Color>{};
  for (var dx = 2; dx < _cellSize - 2; dx += 2) {
    for (var dy = 2; dy < _cellSize - 2; dy += 2) {
      colors.add(sample(Offset(x * _cellSize + dx, y * _cellSize + dy)));
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
}) async {
  await tester.pumpWidget(
    _boardHarness(
      snapshot: snapshot,
      legalMoves: legalMoves,
      selectedPieceId: selectedPieceId,
      capturePixels: true,
    ),
  );

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
  void Function(int x, int y)? onCellTap,
  bool capturePixels = false,
}) {
  final board = RoundBoard(
    snapshot: snapshot,
    legalMoves: legalMoves,
    selectedPieceId: selectedPieceId,
    onCellTap: onCellTap ?? (_, _) {},
  );
  return MaterialApp(
    home: Center(
      child: SizedBox(
        width: _boardSide,
        height: _boardSide,
        child: capturePixels
            ? RepaintBoundary(
                key: const Key('round-board-boundary'),
                child: board,
              )
            : board,
      ),
    ),
  );
}
