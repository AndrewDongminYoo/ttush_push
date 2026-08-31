import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _productionSpritePaths = [
  'assets/images/sprites/azure_explorer_top_down.png',
  'assets/images/sprites/ember_explorer_top_down.png',
  'assets/images/sprites/foothold_intact.png',
  'assets/images/sprites/foothold_damaged.png',
  'assets/images/sprites/foothold_hole.png',
];
const _holeSpritePath = 'assets/images/sprites/foothold_hole.png';
const List<String> _footholdSpritePaths = [
  'assets/images/sprites/foothold_intact.png',
  'assets/images/sprites/foothold_damaged.png',
  _holeSpritePath,
];
const _minimumReadableAlphaComponentArea = 1024;

void main() {
  testWidgets('bundles five transparent 512 pixel production sprites', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final assetPath in _productionSpritePaths) {
        final data = await _loadAsset(assetPath);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        final image = frame.image;
        addTearDown(() {
          image.dispose();
          codec.dispose();
        });

        expect(image.width, 512, reason: assetPath);
        expect(image.height, 512, reason: assetPath);
        final pixels = await image.toByteData();
        expect(pixels, isNotNull, reason: assetPath);
        final rgba = pixels!.buffer.asUint8List(
          pixels.offsetInBytes,
          pixels.lengthInBytes,
        );
        expect(
          [for (var index = 3; index < rgba.length; index += 4) rgba[index]],
          contains(lessThan(255)),
          reason: '$assetPath must contain transparent pixels',
        );
      }
    });
  });

  testWidgets('hole sprite contains no detached alpha debris', (tester) async {
    await tester.runAsync(() async {
      final data = await _loadAsset(_holeSpritePath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      addTearDown(() {
        image.dispose();
        codec.dispose();
      });

      final pixels = await image.toByteData();
      expect(pixels, isNotNull);
      final rgba = pixels!.buffer.asUint8List(
        pixels.offsetInBytes,
        pixels.lengthInBytes,
      );
      final componentAreas = _alphaComponentAreas(
        rgba,
        width: image.width,
        height: image.height,
      );

      expect(
        componentAreas.where(
          (area) => area < _minimumReadableAlphaComponentArea,
        ),
        isEmpty,
        reason: '$_holeSpritePath must contain only readable stone fragments',
      );
    });
  });

  testWidgets('foothold sprites share matched square alpha footprints', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final extents = <int>[];
      for (final assetPath in _footholdSpritePaths) {
        final data = await _loadAsset(assetPath);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        final image = frame.image;
        addTearDown(() {
          image.dispose();
          codec.dispose();
        });

        final pixels = await image.toByteData();
        expect(pixels, isNotNull, reason: assetPath);
        final rgba = pixels!.buffer.asUint8List(
          pixels.offsetInBytes,
          pixels.lengthInBytes,
        );
        final bounds = _alphaBounds(
          rgba,
          width: image.width,
          height: image.height,
        );
        expect(
          (bounds.width - bounds.height).abs(),
          lessThanOrEqualTo(8),
          reason: '$assetPath must read as a top-down square',
        );
        extents
          ..add(bounds.width)
          ..add(bounds.height);
      }

      expect(
        extents.reduce(math.max) - extents.reduce(math.min),
        lessThanOrEqualTo(8),
        reason: 'all foothold states must share one footprint scale',
      );
    });
  });

  test('rejects a fully transparent alpha footprint', () {
    expect(
      () => _alphaBounds(Uint8List(16), width: 2, height: 2),
      throwsStateError,
    );
  });
}

({int width, int height}) _alphaBounds(
  Uint8List rgba, {
  required int width,
  required int height,
}) {
  var minX = width;
  var minY = height;
  var maxX = -1;
  var maxY = -1;

  for (var pixelIndex = 0; pixelIndex < width * height; pixelIndex++) {
    if (rgba[pixelIndex * 4 + 3] == 0) {
      continue;
    }
    final x = pixelIndex % width;
    final y = pixelIndex ~/ width;
    minX = math.min(minX, x);
    minY = math.min(minY, y);
    maxX = math.max(maxX, x);
    maxY = math.max(maxY, y);
  }

  if (maxX < 0) {
    throw StateError('sprite contains no nontransparent pixels');
  }
  return (width: maxX - minX + 1, height: maxY - minY + 1);
}

List<int> _alphaComponentAreas(
  Uint8List rgba, {
  required int width,
  required int height,
}) {
  final visited = Uint8List(width * height);
  final componentAreas = <int>[];

  for (var pixelIndex = 0; pixelIndex < visited.length; pixelIndex++) {
    if (visited[pixelIndex] != 0 || rgba[pixelIndex * 4 + 3] == 0) {
      continue;
    }
    var componentArea = 0;
    final pending = <int>[pixelIndex];
    visited[pixelIndex] = 1;

    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      componentArea += 1;
      final x = current % width;
      final y = current ~/ width;
      for (var deltaY = -1; deltaY <= 1; deltaY++) {
        for (var deltaX = -1; deltaX <= 1; deltaX++) {
          if (deltaX == 0 && deltaY == 0) {
            continue;
          }
          final neighborX = x + deltaX;
          final neighborY = y + deltaY;
          if (neighborX < 0 ||
              neighborX >= width ||
              neighborY < 0 ||
              neighborY >= height) {
            continue;
          }
          final neighbor = neighborY * width + neighborX;
          if (visited[neighbor] != 0 || rgba[neighbor * 4 + 3] == 0) {
            continue;
          }
          visited[neighbor] = 1;
          pending.add(neighbor);
        }
      }
    }

    componentAreas.add(componentArea);
  }

  return componentAreas;
}

Future<ByteData> _loadAsset(String assetPath) async {
  try {
    return await rootBundle.load(assetPath);
  } on Object catch (error) {
    fail('$assetPath failed to load: $error');
  }
}
