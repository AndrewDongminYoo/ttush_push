import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:ttush_push/src/rust/api.dart' as rust;

typedef ProductionSpriteLoader =
    Future<ProductionSpriteSet> Function(
      AssetBundle bundle,
    );

const productionSpriteAssetPaths = [
  'assets/images/sprites/azure_explorer_up.png',
  'assets/images/sprites/azure_explorer_down.png',
  'assets/images/sprites/azure_explorer_left.png',
  'assets/images/sprites/azure_explorer_right.png',
  'assets/images/sprites/ember_explorer_up.png',
  'assets/images/sprites/ember_explorer_down.png',
  'assets/images/sprites/ember_explorer_left.png',
  'assets/images/sprites/ember_explorer_right.png',
  'assets/images/sprites/foothold_intact.png',
  'assets/images/sprites/foothold_damaged.png',
  'assets/images/sprites/foothold_hole.png',
];

enum ExplorerFacing { up, down, left, right }

ExplorerFacing initialExplorerFacing(rust.GamePlayer player) =>
    switch (player) {
      rust.GamePlayer.first => ExplorerFacing.up,
      rust.GamePlayer.second => ExplorerFacing.down,
    };

final class ProductionSpriteSet {
  ProductionSpriteSet({
    required this.azureExplorers,
    required this.emberExplorers,
    required this.intactFoothold,
    required this.damagedFoothold,
    required this.holeFoothold,
  });

  final Map<ExplorerFacing, ui.Image> azureExplorers;
  final Map<ExplorerFacing, ui.Image> emberExplorers;
  final ui.Image intactFoothold;
  final ui.Image damagedFoothold;
  final ui.Image holeFoothold;
  bool _disposed = false;

  List<ui.Image> get images => [
    ...azureExplorers.values,
    ...emberExplorers.values,
    intactFoothold,
    damagedFoothold,
    holeFoothold,
  ];

  ui.Image explorerFor(rust.GamePlayer player, ExplorerFacing facing) =>
      switch (player) {
        rust.GamePlayer.first => azureExplorers[facing]!,
        rust.GamePlayer.second => emberExplorers[facing]!,
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
    for (final image in images.toSet()) {
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
      azureExplorers: {
        ExplorerFacing.up: decodedImages[0],
        ExplorerFacing.down: decodedImages[1],
        ExplorerFacing.left: decodedImages[2],
        ExplorerFacing.right: decodedImages[3],
      },
      emberExplorers: {
        ExplorerFacing.up: decodedImages[4],
        ExplorerFacing.down: decodedImages[5],
        ExplorerFacing.left: decodedImages[6],
        ExplorerFacing.right: decodedImages[7],
      },
      intactFoothold: decodedImages[8],
      damagedFoothold: decodedImages[9],
      holeFoothold: decodedImages[10],
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
