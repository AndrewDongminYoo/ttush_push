import 'dart:io';

import 'package:ttush_push/game/board/board_definition.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

String serializeBoard(String id, rust.GameBoardDefinition board) {
  final output = StringBuffer('ttush-board-v1 $id\n');
  for (final cell in board.playableCells) {
    output.writeln('cell ${cell.x} ${cell.y}');
  }
  for (final piece in board.startingPieces) {
    output.writeln(
      'piece ${piece.id} ${piece.owner.name} ${piece.x} ${piece.y}',
    );
  }
  for (final tile in board.initialTiles ?? <rust.GameTile>[]) {
    output.writeln('tile ${tile.x} ${tile.y} ${tile.kind.name}');
  }
  return output.toString();
}

Future<void> exportBoards(Directory directory) async {
  await directory.create(recursive: true);
  for (final board in BuiltInBoard.values) {
    await File('${directory.path}/${board.id}.board').writeAsString(
      serializeBoard(board.id, board.definition.rules),
      flush: true,
    );
  }
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 || arguments.single.startsWith('-')) {
    stderr.writeln(
      'usage: dart run tool/export_simulation_boards.dart <output-directory>',
    );
    exitCode = 64;
    return;
  }
  try {
    await exportBoards(Directory(arguments.single));
  } on FileSystemException catch (error) {
    stderr.writeln('Board export failed: $error');
    exitCode = 1;
  }
}
