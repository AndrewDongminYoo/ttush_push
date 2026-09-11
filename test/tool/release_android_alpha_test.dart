import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_android_alpha.dart';

void main() {
  test('reads the release version from pubspec.yaml', () {
    final version = parseReleaseVersion('''
name: ttush_push
version: 1.1.0+6
''');

    expect(version.name, '1.1.0');
    expect(version.code, 6);
  });

  test('accepts a production AAB with both changelogs', () async {
    final fixture = await _ReleaseFixture.create();
    addTearDown(fixture.dispose);

    final inputs = inspectAlphaRelease(fixture.root);

    expect(inputs.version.name, '1.1.0');
    expect(inputs.version.code, 6);
    expect(inputs.aab.path, endsWith('app-production-release.aab'));
    expect(inputs.changelogs, hasLength(2));
  });

  test('rejects a release without the Korean changelog', () async {
    final fixture = await _ReleaseFixture.create();
    addTearDown(fixture.dispose);
    await fixture.removeKoreanChangelog();

    expect(
      () => inspectAlphaRelease(fixture.root),
      throwsA(
        isA<ReleaseException>().having(
          (error) => error.message,
          'message',
          contains('ko-KR/changelogs/6.txt'),
        ),
      ),
    );
  });

  test('reads the package and version from a decoded AAB manifest', () {
    final manifest = parseBundleManifest('''
4 {
  2: "package"
  3: "kr.donminzzi.ttush_push"
}
4 {
  2: "versionCode"
  3: "6"
}
4 {
  2: "versionName"
  3: "1.1.0"
}
''');

    expect(manifest.packageName, 'kr.donminzzi.ttush_push');
    expect(manifest.version.name, '1.1.0');
    expect(manifest.version.code, 6);
  });

  test('rejects an AAB version that differs from pubspec.yaml', () {
    const manifest = BundleManifest(
      packageName: 'kr.donminzzi.ttush_push',
      version: ReleaseVersion(name: '1.1.0', code: 5),
    );

    expect(
      () => validateBundleManifest(
        manifest,
        const ReleaseVersion(name: '1.1.0', code: 6),
      ),
      throwsA(
        isA<ReleaseException>().having(
          (error) => error.message,
          'message',
          contains('AAB version 1.1.0+5 does not match pubspec.yaml 1.1.0+6'),
        ),
      ),
    );
  });

  test('accepts only the registered upload certificate', () {
    expect(
      validateUploadCertificate('SHA256: $expectedUploadCertificateSha256'),
      expectedUploadCertificateSha256,
    );

    expect(
      () => validateUploadCertificate('SHA256: 00:11:22:33:44:55:66:77'),
      throwsA(
        isA<ReleaseException>().having(
          (error) => error.message,
          'message',
          contains('Unexpected upload certificate'),
        ),
      ),
    );
  });

  test('rejects publish when the Play service-account key is missing', () {
    expect(
      () => validatePlayCredential(const {}),
      throwsA(
        isA<ReleaseException>().having(
          (error) => error.message,
          'message',
          contains('SUPPLY_JSON_KEY must point'),
        ),
      ),
    );
  });
}

final class _ReleaseFixture {
  _ReleaseFixture(this.root);

  final Directory root;

  static Future<_ReleaseFixture> create() async {
    final root = await Directory.systemTemp.createTemp('ttush-alpha-release-');
    final fixture = _ReleaseFixture(root);
    final inputTime = DateTime.utc(2026, 9, 11, 1);
    final artifactTime = inputTime.add(const Duration(minutes: 1));

    await fixture._write('pubspec.yaml', 'version: 1.1.0+6\n');
    await fixture._write(
      'fastlane/metadata/android/en-US/changelogs/6.txt',
      'English release notes.\n',
    );
    await fixture._write(
      'fastlane/metadata/android/ko-KR/changelogs/6.txt',
      '한국어 출시 노트입니다.\n',
    );
    await fixture._writeBytes(
      'build/app/outputs/bundle/productionRelease/app-production-release.aab',
      [1, 2, 3],
    );

    for (final path in [
      'pubspec.yaml',
      'fastlane/metadata/android/en-US/changelogs/6.txt',
      'fastlane/metadata/android/ko-KR/changelogs/6.txt',
    ]) {
      await File('${root.path}/$path').setLastModified(inputTime);
    }
    await fixture.aab.setLastModified(artifactTime);
    return fixture;
  }

  File get aab => File(
    '${root.path}/build/app/outputs/bundle/productionRelease/'
    'app-production-release.aab',
  );

  Future<void> removeKoreanChangelog() => File(
    '${root.path}/fastlane/metadata/android/ko-KR/changelogs/6.txt',
  ).delete();

  Future<void> _write(String relativePath, String contents) async {
    final file = File('${root.path}/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  Future<void> _writeBytes(String relativePath, List<int> contents) async {
    final file = File('${root.path}/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(contents);
  }

  Future<void> dispose() => root.delete(recursive: true);
}
