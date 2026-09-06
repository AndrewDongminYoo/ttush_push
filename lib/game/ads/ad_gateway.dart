/// A moment the game reached, stated as the event rather than as an ad
/// request.
///
/// The page reports what happened; this layer alone decides whether anything
/// is shown. A frequency policy, a consent step, or a change of provider
/// therefore never reaches game code.
abstract interface class AdGateway {
  /// The match is decided. Prepare whatever the next interruption needs.
  ///
  /// The caller does not wait for this, because nothing may delay the result
  /// the player is reading.
  Future<void> matchDecided();

  /// The player asked for a new match.
  ///
  /// Completes when the interruption, if any, is over. The caller starts the
  /// new match afterwards, so an implementation that shows nothing simply
  /// completes.
  Future<void> beforeNewMatch();
}

/// What ships until a provider is chosen: it performs no work and shows
/// nothing.
final class NoAdGateway implements AdGateway {
  const NoAdGateway();

  @override
  Future<void> matchDecided() async {}

  @override
  Future<void> beforeNewMatch() async {}
}
