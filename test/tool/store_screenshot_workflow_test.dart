import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts a complete Play Store listing with ImageMagick 6', () async {
    final fixture = await _ListingFixture.create();
    addTearDown(fixture.dispose);

    final result = await fixture.validate(
      environment: fixture.imageMagick6Environment,
    );

    expect(result.exitCode, 0, reason: result.stderr as String?);
    expect(result.stdout, contains('Play Store assets are valid.'));
  });

  test('rejects Play Store copy that exceeds its character limit', () async {
    final fixture = await _ListingFixture.create();
    addTearDown(fixture.dispose);
    await fixture.writeText('short_description.txt', 'x' * 81);

    final result = await fixture.validate();

    expect(result.exitCode, isNot(0));
    expect(
      result.stderr,
      contains('short_description.txt exceeds 80 characters.'),
    );
  });

  test('rejects a feature graphic with the wrong dimensions', () async {
    final fixture = await _ListingFixture.create();
    addTearDown(fixture.dispose);
    await fixture.writeImage('images/featureGraphic.png', 1024, 501);

    final result = await fixture.validate();

    expect(result.exitCode, isNot(0));
    expect(
      result.stderr,
      contains('featureGraphic.png must be 1024x500, found 1024x501.'),
    );
  });

  test('rejects a Play Store icon with the wrong dimensions', () async {
    final fixture = await _ListingFixture.create();
    addTearDown(fixture.dispose);
    await fixture.writeImage('images/icon.png', 511, 512);

    final result = await fixture.validate();

    expect(result.exitCode, isNot(0));
    expect(
      result.stderr,
      contains('icon.png must be 512x512, found 511x512.'),
    );
  });

  test('rejects a phone screenshot with the wrong dimensions', () async {
    final fixture = await _ListingFixture.create();
    addTearDown(fixture.dispose);
    await fixture.writeImage(
      'images/phoneScreenshots/01-scene.png',
      1080,
      1919,
    );

    final result = await fixture.validate();

    expect(result.exitCode, isNot(0));
    expect(
      result.stderr,
      contains('01-scene.png must be 1080x1920, found 1080x1919.'),
    );
  });

  test('frames a raw capture with ImageMagick 6', () async {
    final fixture = await _ListingFixture.create();
    addTearDown(fixture.dispose);
    await fixture.writeImage('raw/01-scene.png', 1080, 2400);
    await fixture.writeText(
      'copy.tsv',
      'filename\taccent\ttitle\tsubtitle\n'
          '01-scene\t6C8CFF\tPUSH SMART\tEvery move changes the board.\n',
    );

    final result = await fixture.generate(
      environment: fixture.imageMagick6Environment,
    );

    expect(result.exitCode, 0, reason: result.stderr as String?);
    final output = File('${fixture.root.path}/framed/01-scene.png');
    expect(output.existsSync(), isTrue);
    final dimensions = await Process.run(fixture.identifyBin, [
      '-format',
      '%wx%h',
      output.path,
    ]);
    expect(dimensions.stdout, '1080x1920');
  });
}

final class _ListingFixture {
  _ListingFixture(this.root, this.convertBin, this.identifyBin);

  final Directory root;
  final String convertBin;
  final String identifyBin;

  Map<String, String> get imageMagick6Environment => {
    'PATH': '/usr/bin:/bin',
    'CONVERT_BIN': convertBin,
    'IDENTIFY_BIN': identifyBin,
  };

  static Future<_ListingFixture> create() async {
    final root = await Directory.systemTemp.createTemp('ttush-store-listing-');
    final fixture = _ListingFixture(
      root,
      await _findExecutable('convert'),
      await _findExecutable('identify'),
    );
    await fixture.writeText('title.txt', 'Ttush Push');
    await fixture.writeText(
      'short_description.txt',
      'Push, outthink, and win on a board that breaks beneath every move.',
    );
    await fixture.writeText(
      'full_description.txt',
      'Choose a rival, plan each move, and take two rounds to win the match.',
    );
    await fixture.writeImage('images/icon.png', 512, 512);
    await fixture.writeImage('images/featureGraphic.png', 1024, 500);
    for (var index = 1; index <= 4; index++) {
      await fixture.writeImage(
        'images/phoneScreenshots/0$index-scene.png',
        1080,
        1920,
      );
    }
    return fixture;
  }

  static Future<String> _findExecutable(String command) async {
    final result = await Process.run('sh', [
      '-c',
      r'command -v "$1"',
      'sh',
      command,
    ]);
    expect(result.exitCode, 0, reason: result.stderr as String?);
    return (result.stdout as String).trim();
  }

  Future<void> writeText(String relativePath, String contents) async {
    final file = File('${root.path}/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  Future<void> writeImage(
    String relativePath,
    int width,
    int height,
  ) async {
    final file = File('${root.path}/$relativePath');
    await file.parent.create(recursive: true);
    final result = await Process.run(convertBin, [
      '-size',
      '${width}x$height',
      'xc:black',
      file.path,
    ]);
    expect(result.exitCode, 0, reason: result.stderr as String?);
  }

  Future<ProcessResult> validate({Map<String, String>? environment}) =>
      Process.run(
        'bash',
        ['tool/store_screenshots/validate.sh', root.path],
        environment: environment,
      );

  Future<ProcessResult> generate({Map<String, String>? environment}) =>
      Process.run(
        'bash',
        [
          'tool/store_screenshots/generate.sh',
          '${root.path}/raw',
          '${root.path}/framed',
          '${root.path}/copy.tsv',
        ],
        environment: environment,
      );

  Future<void> dispose() => root.delete(recursive: true);
}
