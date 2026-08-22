import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// What the board just did, stated as the event rather than the sensation.
///
/// The page reports the event; this layer alone decides how it is felt, so a
/// change of intensity, or turning sound off, happens in one place.
abstract interface class RoundFeedback {
  void pieceSelected();

  void moveApplied();

  void pushApplied();

  void roundWon();
}

/// Vibrates and plays the matching effect.
///
/// The players are created once and reused, because a round produces these
/// events far too often to build one per sound.
final class PlatformRoundFeedback implements RoundFeedback {
  PlatformRoundFeedback({AudioPlayer Function()? createPlayer})
    : _createPlayer = createPlayer ?? AudioPlayer.new;

  static const _selectSound = 'sfx/select.wav';
  static const _moveSound = 'sfx/move.wav';
  static const _pushSound = 'sfx/push.wav';
  static const _winSound = 'sfx/win.wav';

  final AudioPlayer Function() _createPlayer;
  final Map<String, AudioPlayer> _players = {};

  @override
  void pieceSelected() {
    unawaited(HapticFeedback.selectionClick());
    _play(_selectSound);
  }

  @override
  void moveApplied() {
    unawaited(HapticFeedback.lightImpact());
    _play(_moveSound);
  }

  @override
  void pushApplied() {
    unawaited(HapticFeedback.mediumImpact());
    _play(_pushSound);
  }

  @override
  void roundWon() {
    unawaited(HapticFeedback.heavyImpact());
    _play(_winSound);
  }

  /// Releases the players. Call when the page that owns this is disposed.
  Future<void> dispose() async {
    final players = _players.values.toList();
    _players.clear();
    await Future.wait(players.map((player) => player.dispose()));
  }

  void _play(String asset) {
    final player = _players.putIfAbsent(asset, () {
      final created = _createPlayer();
      unawaited(created.setReleaseMode(ReleaseMode.stop));
      // Respect the ringer switch: these are decoration, not content.
      unawaited(
        created.setAudioContext(
          AudioContext(
            iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
            android: const AudioContextAndroid(
              usageType: AndroidUsageType.game,
              audioFocus: AndroidAudioFocus.none,
            ),
          ),
        ),
      );
      return created;
    });
    unawaited(player.stop().then((_) => player.play(AssetSource(asset))));
  }
}
