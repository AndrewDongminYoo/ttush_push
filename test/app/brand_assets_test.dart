import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _androidSmallIconPath =
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png';
const _appleLaunchPath =
    'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png';
const _androidAdaptiveArtworkPaths = [
  'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_background_art.png',
  'android/app/src/development/res/drawable-xxxhdpi/ic_launcher_background_art.png',
  'android/app/src/staging/res/drawable-xxxhdpi/ic_launcher_background_art.png',
];
const _appIconPath = 'assets/images/branding/app_icon.png';
const _launchMarkPath = 'assets/images/branding/launch_mark.png';
const _iconComposerPaths = [
  'ios/Runner/AppIcons/AppIcon.icon',
  'ios/Runner/AppIcons/AppIcon-dev.icon',
  'ios/Runner/AppIcons/AppIcon-stg.icon',
  'macos/AppIcons/AppIcon.icon',
  'macos/AppIcons/AppIcon-dev.icon',
  'macos/AppIcons/AppIcon-stg.icon',
];

void main() {
  testWidgets('keeps each team color prominent on its side at 48 pixels', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixels = await _loadRgba(_androidSmallIconPath, size: 48);

      expect(
        _coolPixelFraction(
          pixels,
          width: 48,
          maxX: 24,
          minimumBlue: 102,
        ),
        greaterThan(0.2),
        reason: 'bright Azure blue must fill the left side at 48 pixels',
      );
      expect(
        _warmPixelFraction(
          pixels,
          width: 48,
          minX: 24,
          minimumRed: 102,
        ),
        greaterThan(0.2),
        reason: 'bright Ember red must fill the right side at 48 pixels',
      );
    });
  });

  testWidgets('keeps both team colors in the Apple launch mark', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixels = await _loadRgba(_appleLaunchPath, size: 64);

      expect(
        _coolPixelFraction(pixels, width: 64),
        greaterThan(0.01),
      );
      expect(
        _warmPixelFraction(pixels, width: 64),
        greaterThan(0.01),
      );
      expect(
        _alphaValues(pixels),
        contains(0),
        reason: 'the launch mark must retain transparent padding',
      );
    });
  });

  testWidgets('keeps Android adaptive artwork opaque', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final path in _androidAdaptiveArtworkPaths) {
        expect(File(path).existsSync(), isTrue, reason: path);
        if (!File(path).existsSync()) {
          continue;
        }
        final pixels = await _loadRgba(path, size: 64);
        expect(_alphaValues(pixels), everyElement(255), reason: path);
      }
    });
  });

  testWidgets(
    'keeps every Android flavor distinct inside the adaptive safe circle',
    (
      tester,
    ) async {
      await tester.runAsync(() async {
        final artworkPixels = <Uint8List>[];
        for (final path in _androidAdaptiveArtworkPaths) {
          if (!File(path).existsSync()) {
            fail('$path does not exist');
          }
          artworkPixels.add(await _loadRgba(path, size: 64));
        }

        expect(
          _differentPixelFractionInsideCircle(
            artworkPixels[0],
            artworkPixels[1],
            width: 64,
            radius: 64 * 33 / 108,
          ),
          greaterThan(0.02),
          reason: 'development must remain distinct under the safe mask',
        );
        expect(
          _differentPixelFractionInsideCircle(
            artworkPixels[0],
            artworkPixels[2],
            width: 64,
            radius: 64 * 33 / 108,
          ),
          greaterThan(0.02),
          reason: 'staging must remain distinct under the safe mask',
        );
        expect(
          _differentPixelFractionInsideCircle(
            artworkPixels[1],
            artworkPixels[2],
            width: 64,
            radius: 64 * 33 / 108,
          ),
          greaterThan(0),
          reason: 'development and staging must remain distinguishable',
        );
      });
    },
  );

  testWidgets('keeps canonical and platform image dimensions stable', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final expectedDimensions = <String, (int, int)>{
        _appIconPath: (1024, 1024),
        _launchMarkPath: (600, 600),
        for (final path in _androidAdaptiveArtworkPaths) path: (432, 432),
        'android/app/src/main/ic_launcher-playstore.png': (512, 512),
        'android/app/src/development/ic_launcher-playstore.png': (512, 512),
        'android/app/src/staging/ic_launcher-playstore.png': (512, 512),
        'ios/Runner/AppIcons/AppIcon.icon/Assets/Artwork.png': (1024, 1024),
        'macos/AppIcons/AppIcon.icon/Assets/Artwork.png': (1024, 1024),
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@1x.png': (
          150,
          150,
        ),
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png': (
          300,
          300,
        ),
        _appleLaunchPath: (600, 600),
        'web/icons/Icon-192.png': (192, 192),
        'web/icons/Icon-512.png': (512, 512),
        'web/icons/LaunchMark-192.png': (192, 192),
        'web/favicon.png': (32, 32),
      };

      for (final entry in expectedDimensions.entries) {
        expect(
          await _loadDimensions(entry.key),
          entry.value,
          reason: entry.key,
        );
      }

      const androidDensities = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final sourceSet in ['main', 'development', 'staging']) {
        for (final entry in androidDensities.entries) {
          for (final iconName in ['ic_launcher.png', 'ic_launcher_round.png']) {
            final path =
                'android/app/src/$sourceSet/res/mipmap-${entry.key}/$iconName';
            expect(
              await _loadDimensions(path),
              (entry.value, entry.value),
              reason: path,
            );
          }
        }
      }
    });
  });

  testWidgets('keeps the icon opaque and the launch mark transparent', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final iconPixels = await _loadRgba(_appIconPath, size: 64);
      final markPixels = await _loadRgba(_launchMarkPath, size: 64);

      expect(_alphaValues(iconPixels), everyElement(255));
      expect(_alphaValues(markPixels), contains(0));
      expect(_alphaValues(markPixels), contains(255));
    });
  });

  test('connects every platform consumer to branded assets', () {
    for (final sourceSet in ['main', 'development', 'staging']) {
      for (final iconName in ['ic_launcher.xml', 'ic_launcher_round.xml']) {
        final path =
            'android/app/src/$sourceSet/res/mipmap-anydpi-v26/$iconName';
        final adaptiveIcon = File(path).readAsStringSync();
        expect(
          adaptiveIcon,
          contains('@drawable/ic_launcher_background_art'),
          reason: path,
        );
        expect(
          adaptiveIcon,
          contains('@android:color/transparent'),
          reason: path,
        );
      }
    }

    for (final iconComposerPath in _iconComposerPaths) {
      final config = File('$iconComposerPath/icon.json').readAsStringSync();
      expect(config, contains('"image-name": "Artwork.png"'));
      expect(config, isNot(contains('Logo.svg')));
      expect(File('$iconComposerPath/Assets/Artwork.png').existsSync(), isTrue);
      expect(File('$iconComposerPath/Assets/Logo.svg').existsSync(), isFalse);
    }

    for (final path in [
      'android/app/src/main/res/values-v31/styles.xml',
      'android/app/src/main/res/values-night-v31/styles.xml',
    ]) {
      final styles = File(path);
      expect(styles.existsSync(), isTrue, reason: path);
      final androidLaunch = styles.readAsStringSync();
      expect(
        androidLaunch,
        contains('windowSplashScreenAnimatedIcon'),
        reason: path,
      );
      expect(
        androidLaunch,
        contains('@drawable/ic_launch_image'),
        reason: path,
      );
      expect(
        androidLaunch,
        contains('@color/ic_launcher_background'),
        reason: path,
      );
    }

    expect(
      Directory(
        'macos/Runner/Assets.xcassets/LaunchImage.imageset',
      ).existsSync(),
      isFalse,
      reason: 'macOS has no launch-image consumer',
    );

    final webManifest = File('web/manifest.json').readAsStringSync();
    final webIndex = File('web/index.html').readAsStringSync();
    expect(webManifest, contains('"background_color": "#0B1024"'));
    expect(webIndex, contains('icons/LaunchMark-192.png'));
  });

  test('preserves distinct production, development, and staging icons', () {
    final production = File(
      'android/app/src/main/ic_launcher-playstore.png',
    ).readAsBytesSync();
    final development = File(
      'android/app/src/development/ic_launcher-playstore.png',
    ).readAsBytesSync();
    final staging = File(
      'android/app/src/staging/ic_launcher-playstore.png',
    ).readAsBytesSync();

    expect(development, isNot(equals(production)));
    expect(staging, isNot(equals(production)));
    expect(staging, isNot(equals(development)));
  });

  testWidgets('preserves Apple development and staging badges', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const artworkSets = {
        'iOS': [
          'ios/Runner/AppIcons/AppIcon.icon/Assets/Artwork.png',
          'ios/Runner/AppIcons/AppIcon-dev.icon/Assets/Artwork.png',
          'ios/Runner/AppIcons/AppIcon-stg.icon/Assets/Artwork.png',
        ],
        'macOS': [
          'macos/AppIcons/AppIcon.icon/Assets/Artwork.png',
          'macos/AppIcons/AppIcon-dev.icon/Assets/Artwork.png',
          'macos/AppIcons/AppIcon-stg.icon/Assets/Artwork.png',
        ],
      };

      for (final entry in artworkSets.entries) {
        final production = await _loadRgba(entry.value[0], size: 64);
        final development = await _loadRgba(entry.value[1], size: 64);
        final staging = await _loadRgba(entry.value[2], size: 64);

        expect(
          _cyanPixelFraction(
            production,
            width: 64,
            minX: 40,
            maxX: 64,
            minY: 0,
            maxY: 24,
          ),
          lessThan(0.01),
          reason: '${entry.key} production',
        );
        expect(
          _cyanPixelFraction(
            development,
            width: 64,
            minX: 40,
            maxX: 64,
            minY: 0,
            maxY: 24,
          ),
          greaterThan(0.25),
          reason: '${entry.key} development',
        );
        expect(
          _cyanPixelFraction(
            staging,
            width: 64,
            minX: 40,
            maxX: 64,
            minY: 0,
            maxY: 24,
          ),
          greaterThan(0.25),
          reason: '${entry.key} staging',
        );
      }
    });
  });
}

Future<(int, int)> _loadDimensions(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final dimensions = (frame.image.width, frame.image.height);
  frame.image.dispose();
  codec.dispose();
  return dimensions;
}

Future<Uint8List> _loadRgba(String path, {required int size}) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: size,
    targetHeight: size,
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData();
  frame.image.dispose();
  codec.dispose();
  if (data == null) {
    throw StateError('$path could not be decoded as RGBA pixels');
  }
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

double _coolPixelFraction(
  Uint8List rgba, {
  required int width,
  int minX = 0,
  int? maxX,
  int minimumBlue = 0,
}) => _matchingPixelFraction(
  rgba,
  width: width,
  minX: minX,
  maxX: maxX ?? width,
  matches: (red, green, blue) {
    return blue >= minimumBlue && blue >= red * 1.35 && blue >= green * 1.12;
  },
);

double _warmPixelFraction(
  Uint8List rgba, {
  required int width,
  int minX = 0,
  int? maxX,
  int minimumRed = 0,
}) => _matchingPixelFraction(
  rgba,
  width: width,
  minX: minX,
  maxX: maxX ?? width,
  matches: (red, green, blue) {
    return red >= minimumRed && red >= blue * 1.35 && red >= green * 1.12;
  },
);

double _cyanPixelFraction(
  Uint8List rgba, {
  required int width,
  required int minX,
  required int maxX,
  required int minY,
  required int maxY,
}) {
  var matchingPixels = 0;
  var regionPixels = 0;
  for (var pixelIndex = 0; pixelIndex < rgba.length ~/ 4; pixelIndex++) {
    final x = pixelIndex % width;
    final y = pixelIndex ~/ width;
    if (x < minX || x >= maxX || y < minY || y >= maxY) {
      continue;
    }
    regionPixels += 1;
    final byteIndex = pixelIndex * 4;
    if (rgba[byteIndex] < 80 &&
        rgba[byteIndex + 1] > 150 &&
        rgba[byteIndex + 2] > 220 &&
        rgba[byteIndex + 3] >= 128) {
      matchingPixels += 1;
    }
  }
  return matchingPixels / regionPixels;
}

double _matchingPixelFraction(
  Uint8List rgba, {
  required int width,
  required int minX,
  required int maxX,
  required bool Function(int red, int green, int blue) matches,
}) {
  var visiblePixels = 0;
  var matchingPixels = 0;
  for (var pixelIndex = 0; pixelIndex < rgba.length ~/ 4; pixelIndex++) {
    final x = pixelIndex % width;
    if (x < minX || x >= maxX) {
      continue;
    }
    final byteIndex = pixelIndex * 4;
    if (rgba[byteIndex + 3] < 128) {
      continue;
    }
    visiblePixels += 1;
    if (matches(
      rgba[byteIndex],
      rgba[byteIndex + 1],
      rgba[byteIndex + 2],
    )) {
      matchingPixels += 1;
    }
  }
  return matchingPixels / visiblePixels;
}

double _differentPixelFractionInsideCircle(
  Uint8List first,
  Uint8List second, {
  required int width,
  required double radius,
}) {
  final center = (width - 1) / 2;
  var circlePixels = 0;
  var differentPixels = 0;
  for (var pixelIndex = 0; pixelIndex < first.length ~/ 4; pixelIndex++) {
    final x = pixelIndex % width;
    final y = pixelIndex ~/ width;
    final deltaX = x - center;
    final deltaY = y - center;
    if (deltaX * deltaX + deltaY * deltaY > radius * radius) {
      continue;
    }
    circlePixels += 1;
    final byteIndex = pixelIndex * 4;
    if (first[byteIndex] != second[byteIndex] ||
        first[byteIndex + 1] != second[byteIndex + 1] ||
        first[byteIndex + 2] != second[byteIndex + 2] ||
        first[byteIndex + 3] != second[byteIndex + 3]) {
      differentPixels += 1;
    }
  }
  return differentPixels / circlePixels;
}

Iterable<int> _alphaValues(Uint8List rgba) sync* {
  for (var index = 3; index < rgba.length; index += 4) {
    yield rgba[index];
  }
}
