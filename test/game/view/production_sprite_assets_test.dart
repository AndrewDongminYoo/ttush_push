import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _productionSpritePaths = [
  ..._explorerSpritePaths,
  'assets/images/sprites/foothold_intact.png',
  'assets/images/sprites/foothold_damaged.png',
  'assets/images/sprites/foothold_hole.png',
];
const _explorerSpritePaths = [
  'assets/images/sprites/azure_explorer_up.png',
  'assets/images/sprites/azure_explorer_down.png',
  'assets/images/sprites/azure_explorer_left.png',
  'assets/images/sprites/azure_explorer_right.png',
  'assets/images/sprites/ember_explorer_up.png',
  'assets/images/sprites/ember_explorer_down.png',
  'assets/images/sprites/ember_explorer_left.png',
  'assets/images/sprites/ember_explorer_right.png',
];
const _turnaroundReferencePath =
    'assets/images/reference/directional-explorer-sprites-v1/'
    'azure_turnaround_reference.png';
const _holeSpritePath = 'assets/images/sprites/foothold_hole.png';
const _intactSpritePath = 'assets/images/sprites/foothold_intact.png';
const _damagedSpritePath = 'assets/images/sprites/foothold_damaged.png';
const List<String> _footholdSpritePaths = [
  _intactSpritePath,
  _damagedSpritePath,
  _holeSpritePath,
];
const _minimumReadableAlphaComponentArea = 1024;
const _nativeScale = 64;

void main() {
  testWidgets('bundles eleven transparent 512 pixel production sprites', (
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

  testWidgets('keeps the approved turnaround outside the asset bundle', (
    tester,
  ) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    expect(manifest.listAssets(), isNot(contains(_turnaroundReferencePath)));
  });

  testWidgets('explorer directions share one scale and foot anchor', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final assetPath in _explorerSpritePaths) {
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

        expect(bounds.height, 340, reason: assetPath);
        expect(bounds.maxY, 425, reason: assetPath);
        expect(
          (bounds.minX + bounds.maxX + 1) / 2,
          closeTo(256, 1),
          reason: assetPath,
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

  testWidgets(
    'damaged foothold remains fractured and solid at board scale',
    (
      tester,
    ) async {
      await tester.runAsync(() async {
        final intact = await _loadRgbaAtSize(_intactSpritePath, _nativeScale);
        final damaged = await _loadRgbaAtSize(_damagedSpritePath, _nativeScale);
        final hole = await _loadRgbaAtSize(_holeSpritePath, _nativeScale);
        final intactDarkFraction = _darkVisiblePixelFraction(intact);
        final damagedDarkFraction = _darkVisiblePixelFraction(damaged);

        expect(
          damagedDarkFraction,
          greaterThan(intactDarkFraction),
          reason: 'damage fractures must remain distinct after native scaling',
        );
        expect(
          _centerAlphaValues(damaged, size: _nativeScale),
          everyElement(greaterThanOrEqualTo(250)),
          reason: 'the damaged foothold center region must remain solid',
        );
        expect(
          _centerAlphaValues(hole, size: _nativeScale),
          contains(lessThan(128)),
          reason: 'the center-region check must detect a collapsed hole',
        );
      });
    },
  );

  test('rejects a fully transparent alpha footprint', () {
    expect(
      () => _alphaBounds(Uint8List(16), width: 2, height: 2),
      throwsStateError,
    );
  });
}

({int width, int height, int minX, int minY, int maxX, int maxY}) _alphaBounds(
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
  return (
    width: maxX - minX + 1,
    height: maxY - minY + 1,
    minX: minX,
    minY: minY,
    maxX: maxX,
    maxY: maxY,
  );
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

Future<Uint8List> _loadRgbaAtSize(String assetPath, int size) async {
  final data = await _loadAsset(assetPath);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    targetWidth: size,
    targetHeight: size,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final pixels = await image.toByteData();
  image.dispose();
  codec.dispose();
  if (pixels == null) {
    throw StateError('$assetPath failed to decode at $size pixels');
  }
  return pixels.buffer.asUint8List(
    pixels.offsetInBytes,
    pixels.lengthInBytes,
  );
}

double _darkVisiblePixelFraction(Uint8List rgba) {
  var visiblePixels = 0;
  var darkPixels = 0;
  for (var index = 0; index < rgba.length; index += 4) {
    if (rgba[index + 3] < 128) {
      continue;
    }
    visiblePixels += 1;
    final luminance =
        (299 * rgba[index] + 587 * rgba[index + 1] + 114 * rgba[index + 2]) ~/
        1000;
    if (luminance <= 89) {
      darkPixels += 1;
    }
  }
  return darkPixels / visiblePixels;
}

List<int> _centerAlphaValues(Uint8List rgba, {required int size}) {
  final start = size * 3 ~/ 8;
  final end = size * 5 ~/ 8;
  return [
    for (var y = start; y < end; y++)
      for (var x = start; x < end; x++) rgba[(y * size + x) * 4 + 3],
  ];
}
