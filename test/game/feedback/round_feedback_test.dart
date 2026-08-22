import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/feedback/round_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('pairs each event with its own vibration and effect', () async {
    final (feedback, players) = _feedbackWithFakePlayers();

    feedback
      ..pieceSelected()
      ..moveApplied()
      ..pushApplied()
      ..roundWon();
    // The players stop before playing, so let those futures settle.
    await Future<void>.delayed(Duration.zero);

    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
    expect(players.map((player) => player.played).toList(), [
      ['sfx/select.wav'],
      ['sfx/move.wav'],
      ['sfx/push.wav'],
      ['sfx/win.wav'],
    ]);
    // Decoration, not content: the ringer switch has to win. Asserting the
    // routing rather than merely that some context was set, because the wrong
    // routing is silent on every gate but audible on the device.
    for (final player in players) {
      final context = player.context;
      expect(context, isNotNull);
      expect(context!.iOS.category, AVAudioSessionCategory.ambient);
      expect(context.android.usageType, AndroidUsageType.notificationEvent);
      expect(context.android.contentType, AndroidContentType.sonification);
    }
  });

  test('reuses one player per effect and releases them on dispose', () async {
    final (feedback, players) = _feedbackWithFakePlayers();

    feedback
      ..moveApplied()
      ..moveApplied()
      ..moveApplied();
    await Future<void>.delayed(Duration.zero);

    expect(players, hasLength(1));
    expect(players.single.played, hasLength(3));
    // A repeat cuts the previous one rather than layering over it.
    expect(players.single.stopCount, 3);

    await feedback.dispose();

    expect(players.single.disposed, isTrue);
  });
}

(PlatformRoundFeedback, List<_FakeAudioPlayer>) _feedbackWithFakePlayers() {
  final players = <_FakeAudioPlayer>[];
  return (
    PlatformRoundFeedback(
      createPlayer: () {
        players.add(_FakeAudioPlayer());
        return players.last;
      },
    ),
    players,
  );
}

final class _FakeAudioPlayer implements AudioPlayer {
  final List<String> played = [];
  AudioContext? context;
  bool disposed = false;
  int stopCount = 0;

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {}

  @override
  Future<void> setAudioContext(AudioContext ctx) async {
    context = ctx;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    played.add((source as AssetSource).path);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
