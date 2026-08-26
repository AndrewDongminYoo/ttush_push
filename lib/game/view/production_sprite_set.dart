import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

typedef ProductionSpriteLoader =
    Future<ProductionSpriteSet> Function(
      AssetBundle bundle,
    );

const productionSpriteAssetPaths = [
  'assets/images/sprites/azure_explorer.png',
  'assets/images/sprites/ember_explorer.png',
  'assets/images/sprites/foothold_intact.png',
  'assets/images/sprites/foothold_damaged.png',
  'assets/images/sprites/foothold_hole.png',
];

final class ProductionSpriteSet {
  ProductionSpriteSet({
    required this.azureExplorer,
    required this.emberExplorer,
    required this.intactFoothold,
    required this.damagedFoothold,
    required this.holeFoothold,
  });

  final ui.Image azureExplorer;
  final ui.Image emberExplorer;
  final ui.Image intactFoothold;
  final ui.Image damagedFoothold;
  final ui.Image holeFoothold;
  bool _disposed = false;

  List<ui.Image> get images => [
    azureExplorer,
    emberExplorer,
    intactFoothold,
    damagedFoothold,
    holeFoothold,
  ];

  ui.Image explorerFor(rust.GamePlayer player) => switch (player) {
    rust.GamePlayer.first => azureExplorer,
    rust.GamePlayer.second => emberExplorer,
  };

  ui.Image footholdFor(rust.GameTileKind kind) => switch (kind) {
    rust.GameTileKind.normal => intactFoothold,
    rust.GameTileKind.damaged => damagedFoothold,
    rust.GameTileKind.hole => holeFoothold,
  };

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final image in images) {
      image.dispose();
    }
  }
}

Future<ProductionSpriteSet> loadProductionSpriteSet(AssetBundle bundle) async {
  final decodedImages = <ui.Image>[];
  try {
    for (final assetPath in productionSpriteAssetPaths) {
      decodedImages.add(await _decodeImage(bundle, assetPath));
    }
    return ProductionSpriteSet(
      azureExplorer: decodedImages[0],
      emberExplorer: decodedImages[1],
      intactFoothold: decodedImages[2],
      damagedFoothold: decodedImages[3],
      holeFoothold: decodedImages[4],
    );
  } on Object {
    for (final image in decodedImages) {
      image.dispose();
    }
    rethrow;
  }
}

Future<ui.Image> _decodeImage(AssetBundle bundle, String assetPath) async {
  final data = await bundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}
