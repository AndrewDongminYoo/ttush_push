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
}
