import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

const _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (screenshotName, screenshotBytes, [args]) async {
      if (screenshotBytes.length < _pngSignature.length ||
          !_hasPngSignature(screenshotBytes)) {
        return false;
      }
      final outputDirectory = Directory(
        'build/screenshots/production-sprite-set',
      );
      await outputDirectory.create(recursive: true);
      final outputFile = File(
        '${outputDirectory.path}/$screenshotName.png',
      );
      await outputFile.writeAsBytes(screenshotBytes, flush: true);
      return outputFile.lengthSync() == screenshotBytes.length;
    },
  );
}

bool _hasPngSignature(List<int> bytes) {
  for (final (index, expected) in _pngSignature.indexed) {
    if (bytes[index] != expected) {
      return false;
    }
  }
  return true;
}
