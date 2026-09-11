import 'dart:convert';
import 'dart:io';

const expectedUploadCertificateSha256 =
    '84:10:5B:BF:5B:C0:3D:7C:1A:E8:16:2D:76:8D:1F:44:C1:09:4C:21:'
    '53:63:57:0C:F9:0D:AF:6E:38:C3:97:E5';

final class ReleaseException implements Exception {
  const ReleaseException(this.message);

  final String message;
}

final class ReleaseVersion {
  const ReleaseVersion({required this.name, required this.code});

  final String name;
  final int code;
}

final class AlphaReleaseInputs {
  const AlphaReleaseInputs({
    required this.version,
    required this.aab,
    required this.changelogs,
  });

  final ReleaseVersion version;
  final File aab;
  final List<File> changelogs;
}

final class BundleManifest {
  const BundleManifest({required this.packageName, required this.version});

  final String packageName;
  final ReleaseVersion version;
}

ReleaseVersion parseReleaseVersion(String pubspec) {
  final match = RegExp(
    r'^version:\s*([^\s+]+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) {
    throw const ReleaseException(
      'pubspec.yaml must contain version: <name>+<code>.',
    );
  }

  return ReleaseVersion(
    name: match.group(1)!,
    code: int.parse(match.group(2)!),
  );
}

AlphaReleaseInputs inspectAlphaRelease(Directory root) {
  final pubspec = File('${root.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    throw ReleaseException('Missing pubspec.yaml at ${pubspec.path}.');
  }

  final version = parseReleaseVersion(pubspec.readAsStringSync());
  final changelogs = [
    for (final locale in ['en-US', 'ko-KR'])
      File(
        '${root.path}/fastlane/metadata/android/$locale/changelogs/'
        '${version.code}.txt',
      ),
  ];
  for (final changelog in changelogs) {
    if (!changelog.existsSync()) {
      throw ReleaseException('Missing Play changelog at ${changelog.path}.');
    }
    final notes = changelog.readAsStringSync().trim();
    if (notes.isEmpty) {
      throw ReleaseException('Play changelog is empty: ${changelog.path}.');
    }
    if (notes.runes.length > 500) {
      throw ReleaseException(
        'Play changelog exceeds 500 characters: ${changelog.path}.',
      );
    }
  }

  final aab = File(
    '${root.path}/build/app/outputs/bundle/productionRelease/'
    'app-production-release.aab',
  );
  if (!aab.existsSync() || aab.lengthSync() == 0) {
    throw ReleaseException('Missing production AAB at ${aab.path}.');
  }

  return AlphaReleaseInputs(version: version, aab: aab, changelogs: changelogs);
}

BundleManifest parseBundleManifest(String decodedManifest) {
  final packageName = _manifestAttribute(decodedManifest, 'package');
  final versionName = _manifestAttribute(decodedManifest, 'versionName');
  final versionCode = int.tryParse(
    _manifestAttribute(decodedManifest, 'versionCode'),
  );
  if (versionCode == null) {
    throw const ReleaseException('The AAB versionCode is not an integer.');
  }

  return BundleManifest(
    packageName: packageName,
    version: ReleaseVersion(name: versionName, code: versionCode),
  );
}

void validateBundleManifest(
  BundleManifest manifest,
  ReleaseVersion expectedVersion,
) {
  if (manifest.packageName != 'kr.donminzzi.ttush_push') {
    throw ReleaseException(
      'AAB package ${manifest.packageName} is not kr.donminzzi.ttush_push.',
    );
  }
  if (manifest.version.name != expectedVersion.name ||
      manifest.version.code != expectedVersion.code) {
    throw ReleaseException(
      'AAB version ${manifest.version.name}+${manifest.version.code} does not '
      'match pubspec.yaml ${expectedVersion.name}+${expectedVersion.code}.',
    );
  }
}

Future<String> decodeBundleManifest(File aab) async {
  final unzip = await Process.start('unzip', [
    '-p',
    aab.path,
    'base/manifest/AndroidManifest.xml',
  ]);
  final protoc = await Process.start('protoc', ['--decode_raw']);
  final unzipError = unzip.stderr.transform(utf8.decoder).join();
  final protocOutput = protoc.stdout.transform(utf8.decoder).join();
  final protocError = protoc.stderr.transform(utf8.decoder).join();

  await unzip.stdout.pipe(protoc.stdin);
  final unzipExit = await unzip.exitCode;
  final protocExit = await protoc.exitCode;
  final decodedManifest = await protocOutput;
  if (unzipExit != 0) {
    throw ReleaseException(
      'unzip failed to read the AAB manifest: ${await unzipError}',
    );
  }
  if (protocExit != 0) {
    throw ReleaseException(
      'protoc failed to decode the AAB manifest: ${await protocError}',
    );
  }
  return decodedManifest;
}

String _manifestAttribute(String decodedManifest, String name) {
  final attribute = RegExp(
    '4 \\{\\s+(?:1: "[^"]+"\\s+)?2: "$name"\\s+3: "([^"]+)"',
  ).firstMatch(decodedManifest);
  if (attribute == null) {
    throw ReleaseException('The AAB manifest has no $name attribute.');
  }
  return attribute.group(1)!;
}

String validateUploadCertificate(String keytoolOutput) {
  final match = RegExp(r'SHA256:\s*([0-9A-Fa-f:]+)').firstMatch(keytoolOutput);
  if (match == null) {
    throw const ReleaseException(
      'keytool did not report an SHA256 certificate fingerprint.',
    );
  }

  final fingerprint = match.group(1)!.toUpperCase();
  if (fingerprint != expectedUploadCertificateSha256) {
    throw ReleaseException(
      'Unexpected upload certificate: $fingerprint. '
      'Expected $expectedUploadCertificateSha256.',
    );
  }
  return fingerprint;
}

String validatePlayCredential(Map<String, String> environment) {
  final jsonKey = environment['SUPPLY_JSON_KEY'];
  if (jsonKey == null || jsonKey.isEmpty) {
    throw const ReleaseException(
      'SUPPLY_JSON_KEY must point to the Play service-account JSON file.',
    );
  }
  if (!File(jsonKey).existsSync()) {
    throw ReleaseException('SUPPLY_JSON_KEY does not exist: $jsonKey.');
  }
  return jsonKey;
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 ||
      !{'check', 'publish'}.contains(arguments.single)) {
    stderr.writeln(
      'Usage: dart run tool/release_android_alpha.dart <check|publish>',
    );
    exitCode = 64;
    return;
  }

  final command = arguments.single;
  final root = File.fromUri(Platform.script).parent.parent;
  const bundleEnvironment = {'BUNDLE_PATH': 'vendor/bundle'};
  try {
    await _run(
      'bundle',
      ['check'],
      workingDirectory: '${root.path}/android',
      environment: bundleEnvironment,
    );
    if (command == 'publish') {
      validatePlayCredential(Platform.environment);
      await _run('flutter', [
        'build',
        'appbundle',
        '--release',
        '--flavor',
        'production',
        '--target',
        'lib/main_production.dart',
      ], workingDirectory: root.path);
    }

    final inputs = inspectAlphaRelease(root);
    final bundleManifest = parseBundleManifest(
      await decodeBundleManifest(inputs.aab),
    );
    validateBundleManifest(bundleManifest, inputs.version);
    final keytool = await Process.run('keytool', [
      '-printcert',
      '-jarfile',
      inputs.aab.path,
    ]);
    if (keytool.exitCode != 0) {
      throw ReleaseException(
        'keytool failed with status ${keytool.exitCode}: ${keytool.stderr}',
      );
    }
    final fingerprint = validateUploadCertificate(
      '${keytool.stdout}\n${keytool.stderr}',
    );

    stdout
      ..writeln('Google Play target: kr.donminzzi.ttush_push / alpha')
      ..writeln(
        'Release: ${inputs.version.name} (${inputs.version.code}), completed, '
        'rollout 100%',
      )
      ..writeln('AAB: ${inputs.aab.path}')
      ..writeln('Upload certificate SHA256: $fingerprint')
      ..writeln('Changelogs: en-US, ko-KR');

    if (command == 'check') {
      stdout.writeln(
        'Alpha release preflight passed. No Play changes were made.',
      );
      return;
    }

    await _run(
      'bundle',
      ['exec', 'fastlane', 'android', 'alpha'],
      workingDirectory: '${root.path}/android',
      environment: bundleEnvironment,
    );
  } on ReleaseException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on ProcessException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
  );
  final commandExit = await process.exitCode;
  if (commandExit != 0) {
    throw ReleaseException(
      '$executable ${arguments.join(' ')} failed with status $commandExit.',
    );
  }
}
