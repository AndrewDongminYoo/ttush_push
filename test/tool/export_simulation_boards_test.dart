import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/board/board_definition.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

import '../../tool/export_simulation_boards.dart';

void main() {
  test('exports sparse terrain and both owners without losing coordinates', () {
    // Dropping terrain or swapping an owner must change the exported input.
    const board = rust.GameBoardDefinition(
      playableCells: [
        rust.GameBoardCell(x: 2, y: 3),
        rust.GameBoardCell(x: 3, y: 3),
        rust.GameBoardCell(x: 4, y: 3),
      ],
      startingPieces: [
        rust.GamePiece(id: 7, owner: rust.GamePlayer.first, x: 2, y: 3),
        rust.GamePiece(id: 9, owner: rust.GamePlayer.second, x: 3, y: 3),
      ],
      initialTiles: [
        rust.GameTile(x: 2, y: 3, kind: rust.GameTileKind.damaged),
        rust.GameTile(x: 4, y: 3, kind: rust.GameTileKind.hole),
      ],
    );
    expect(
      serializeBoard('terrain-fixture', board),
      'ttush-board-v1 terrain-fixture\n'
      'cell 2 3\ncell 3 3\ncell 4 3\n'
      'piece 7 first 2 3\npiece 9 second 3 3\n'
      'tile 2 3 damaged\ntile 4 3 hole\n',
    );
  });

  test('writes the current app catalog into the requested directory', () async {
    final parent = await Directory.systemTemp.createTemp('ttush-export-');
    addTearDown(() => parent.delete(recursive: true));
    final target = Directory('${parent.path}/boards');
    await exportBoards(target);
    expect(target.existsSync(), isTrue);
    expect(
      target.listSync().map((file) => file.uri.pathSegments.last),
      unorderedEquals([
        for (final board in BuiltInBoard.values) '${board.id}.board',
      ]),
    );
    for (final board in BuiltInBoard.values) {
      final contents = await File(
        '${target.path}/${board.id}.board',
      ).readAsLines();
      expect(contents.first, 'ttush-board-v1 ${board.id}');
      expect(contents.where((line) => line.startsWith('cell ')).toSet(), {
        for (final cell in board.definition.rules.playableCells)
          'cell ${cell.x} ${cell.y}',
      });
      expect(contents.where((line) => line.startsWith('piece ')).toSet(), {
        for (final piece in board.definition.rules.startingPieces)
          'piece ${piece.id} ${piece.owner.name} ${piece.x} ${piece.y}',
      });
      expect(contents.where((line) => line.startsWith('tile ')).toSet(), {
        for (final tile
            in board.definition.rules.initialTiles ?? <rust.GameTile>[])
          'tile ${tile.x} ${tile.y} ${tile.kind.name}',
      });
    }
  });

  test(
    'CLI rejects missing output and reports unwritable destinations',
    () async {
      final missing = await Process.run('dart', [
        'run',
        'tool/export_simulation_boards.dart',
      ]);
      expect(missing.exitCode, 64);
      expect(missing.stderr, contains('usage:'));
      final parent = await Directory.systemTemp.createTemp(
        'ttush-export-error-',
      );
      addTearDown(() => parent.delete(recursive: true));
      final occupied = File('${parent.path}/occupied');
      await occupied.writeAsString('preserve');
      final invalid = await Process.run('dart', [
        'run',
        'tool/export_simulation_boards.dart',
        occupied.path,
      ]);
      expect(invalid.exitCode, 1);
      expect(invalid.stderr, contains('Board export failed:'));
      expect(await occupied.readAsString(), 'preserve');
    },
  );
}
