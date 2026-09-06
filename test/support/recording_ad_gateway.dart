import 'dart:async';

import 'package:ttush_push/game/ads/ad_gateway.dart';

/// Records the moments the game reported, and can hold the new match open.
///
/// `hold` exists so a test can assert the ordering an ad imposes: while the
/// future is incomplete the interruption is still on screen, and the board
/// must not have restarted. Completing `hold` with an error, rather than a
/// value, is how a test drives the `beforeNewMatch` failure path.
///
/// `matchDecidedError`, if set, is thrown after the event is recorded, which
/// is how a test drives the `matchDecided` failure path — that call has no
/// caller-controlled future to hold open, since the page never awaits it.
final class RecordingAdGateway implements AdGateway {
  RecordingAdGateway({this.hold, this.matchDecidedError});

  final Completer<void>? hold;
  final Error? matchDecidedError;
  final List<String> events = [];

  @override
  Future<void> matchDecided() async {
    events.add('match-decided');
    final error = matchDecidedError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> beforeNewMatch() {
    events.add('before-new-match');
    return hold?.future ?? Future<void>.value();
  }
}
