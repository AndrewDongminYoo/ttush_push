import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/view/production_sprite_set.dart';
import 'package:ttush_push/src/rust/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and maps the complete production sprite set', () async {
    final spriteSet = await loadProductionSpriteSet(rootBundle);
    addTearDown(spriteSet.dispose);

    expect(spriteSet.images, hasLength(5));
    expect(
      spriteSet.explorerFor(GamePlayer.first),
      same(spriteSet.azureExplorer),
    );
    expect(
      spriteSet.explorerFor(GamePlayer.second),
      same(spriteSet.emberExplorer),
    );
    expect(
      spriteSet.footholdFor(GameTileKind.normal),
      same(spriteSet.intactFoothold),
    );
    expect(
      spriteSet.footholdFor(GameTileKind.damaged),
      same(spriteSet.damagedFoothold),
    );
    expect(
      spriteSet.footholdFor(GameTileKind.hole),
      same(spriteSet.holeFoothold),
    );
  });

  test(
    'disposes images decoded before a later production asset fails',
    () async {
      final validPng = await rootBundle.load(
        'assets/images/sprites/azure_explorer.png',
      );
      final bundle = _FailAfterFirstAssetBundle(validPng);
      final createdImages = <ui.Image>[];
      final disposalCounts = <ui.Image, int>{};
      final previousOnCreate = ui.Image.onCreate;
      final previousOnDispose = ui.Image.onDispose;
      ui.Image.onCreate = (image) {
        createdImages.add(image);
        previousOnCreate?.call(image);
      };
      ui.Image.onDispose = (image) {
        disposalCounts.update(image, (count) => count + 1, ifAbsent: () => 1);
        previousOnDispose?.call(image);
      };
      addTearDown(() {
        ui.Image.onCreate = previousOnCreate;
        ui.Image.onDispose = previousOnDispose;
      });

      await expectLater(loadProductionSpriteSet(bundle), throwsA(anything));

      expect(bundle.loadedPaths, [
        'assets/images/sprites/azure_explorer.png',
        'assets/images/sprites/ember_explorer.png',
      ]);
      expect(createdImages, hasLength(1));
      expect(createdImages.single.debugDisposed, isTrue);
      expect(disposalCounts[createdImages.single], 1);
    },
  );
}

final class _FailAfterFirstAssetBundle extends CachingAssetBundle {
  _FailAfterFirstAssetBundle(this.validPng);

  final ByteData validPng;
  final loadedPaths = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loadedPaths.add(key);
    if (loadedPaths.length == 1) {
      return validPng;
    }
    return ByteData.sublistView(Uint8List.fromList([0, 1, 2, 3]));
  }
}
