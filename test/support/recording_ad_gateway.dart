import 'dart:async';

import 'package:ttush_push/game/ads/ad_gateway.dart';

/// Records the moments the game reported, and can hold the new match open.
///
/// `hold` exists so a test can assert the ordering an ad imposes: while the
/// future is incomplete the interruption is still on screen, and the board
/// must not have restarted.
final class RecordingAdGateway implements AdGateway {
  RecordingAdGateway({this.hold});

  final Completer<void>? hold;
  final List<String> events = [];

  @override
  Future<void> matchDecided() async {
    events.add('match-decided');
  }

  @override
  Future<void> beforeNewMatch() {
    events.add('before-new-match');
    return hold?.future ?? Future<void>.value();
  }
}
