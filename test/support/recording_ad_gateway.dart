import 'dart:async';

import 'package:ttush_push/game/ads/ad_gateway.dart';

/// Records the moments the game reported, and can hold the new match open.
///
/// `hold` exists so a test can assert the ordering an ad imposes: while the
/// future is incomplete the interruption is still on screen, and the board
/// must not have restarted. Completing `hold` with an error, rather than a
/// value, is how a test drives the `beforeNewMatch` failure path.
///
/// `matchDecidedError`, if set, is raised after the event is recorded, which
/// is how a test drives the `matchDecided` failure path — that call has no
/// caller-controlled future to hold open, since the page never awaits it.
/// `matchDecidedFailsSynchronously` chooses which of the two shapes it takes:
/// a returned failed future, or a throw that happens before any future
/// exists. The interface permits both, and an adapter over an uninitialized
/// SDK raises the second one, so the page has to survive either.
///
/// `onMatchDecided` runs at the instant the call arrives, before anything is
/// recorded, which is how a test reads the state of the frame the page called
/// from. The recorded event alone cannot answer that: the call and the frame
/// that paints the result fall inside the same `pump`, so only what is true
/// *during* the call separates a pre-paint caller from a post-paint one.
final class RecordingAdGateway implements AdGateway {
  RecordingAdGateway({
    this.hold,
    this.matchDecidedError,
    this.matchDecidedFailsSynchronously = false,
    this.onMatchDecided,
  });

  final Completer<void>? hold;
  final Error? matchDecidedError;
  final bool matchDecidedFailsSynchronously;
  final void Function()? onMatchDecided;
  final List<String> events = [];

  @override
  Future<void> matchDecided() {
    onMatchDecided?.call();
    events.add('match-decided');
    final error = matchDecidedError;
    if (error == null) {
      return Future<void>.value();
    }
    if (matchDecidedFailsSynchronously) {
      throw error;
    }
    return Future<void>.error(error, StackTrace.current);
  }

  @override
  Future<void> beforeNewMatch() {
    events.add('before-new-match');
    return hold?.future ?? Future<void>.value();
  }
}
