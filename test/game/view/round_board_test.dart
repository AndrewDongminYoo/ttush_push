import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/view/round_board.dart';
import 'package:ttush_push/src/rust/api.dart';

void main() {
  const snapshot = GameSnapshot(
    currentPlayer: GamePlayer.first,
    tiles: [],
    pieces: [],
    snapshotHash: 'board',
  );

  testWidgets('forwards the tapped board cell to its callback', (tester) async {
    var tappedCell = (-1, -1);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 250,
          height: 250,
          child: RoundBoard(
            snapshot: snapshot,
            legalMoves: const [],
            selectedPieceId: null,
            onCellTap: (x, y) => tappedCell = (x, y),
          ),
        ),
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

  testWidgets('renders tile states, piece ownership, and legal directions', (
    tester,
  ) async {
    const populatedSnapshot = GameSnapshot(
      currentPlayer: GamePlayer.first,
      tiles: [
        GameTile(x: 0, y: 0, kind: GameTileKind.normal),
        GameTile(x: 1, y: 0, kind: GameTileKind.damaged),
        GameTile(x: 2, y: 0, kind: GameTileKind.hole),
      ],
      pieces: [
        GamePiece(id: 0, owner: GamePlayer.first, x: 2, y: 2),
        GamePiece(id: 1, owner: GamePlayer.second, x: 3, y: 3),
      ],
      snapshotHash: 'rendered-board',
    );
    const legalMoves = [
      GameMove(pieceId: 0, direction: GameDirection.up),
      GameMove(pieceId: 0, direction: GameDirection.down),
      GameMove(pieceId: 0, direction: GameDirection.left),
      GameMove(pieceId: 0, direction: GameDirection.right),
    ];
    final rebuiltMoves = List<GameMove>.of(legalMoves);

    await tester.pumpWidget(
      _boardHarness(
        snapshot: populatedSnapshot,
        legalMoves: legalMoves,
        selectedPieceId: 0,
      ),
    );
    await tester.pumpWidget(
      _boardHarness(
        snapshot: populatedSnapshot,
        legalMoves: rebuiltMoves,
        selectedPieceId: 0,
      ),
    );
    await tester.pumpWidget(
      _boardHarness(
        snapshot: populatedSnapshot,
        legalMoves: rebuiltMoves,
        selectedPieceId: 1,
      ),
    );
    await tester.pumpWidget(
      _boardHarness(
        snapshot: populatedSnapshot,
        legalMoves: rebuiltMoves,
        selectedPieceId: 99,
      ),
    );

    expect(find.byKey(const Key('round-board-canvas')), findsOneWidget);
  });
}

Widget _boardHarness({
  required GameSnapshot snapshot,
  required List<GameMove> legalMoves,
  required int? selectedPieceId,
}) {
  return MaterialApp(
    home: SizedBox(
      width: 250,
      height: 250,
      child: RoundBoard(
        snapshot: snapshot,
        legalMoves: legalMoves,
        selectedPieceId: selectedPieceId,
        onCellTap: (_, _) {},
      ),
    ),
  );
}
