import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _productionSpritePaths = [
  'assets/images/sprites/azure_explorer.png',
  'assets/images/sprites/ember_explorer.png',
  'assets/images/sprites/foothold_intact.png',
  'assets/images/sprites/foothold_damaged.png',
  'assets/images/sprites/foothold_hole.png',
];

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
}

Future<ByteData> _loadAsset(String assetPath) async {
  try {
    return await rootBundle.load(assetPath);
  } on Object catch (error) {
    fail('$assetPath failed to load: $error');
  }
}
