import 'package:ttush_push/src/rust/api.dart' as rust;

export 'package:ttush_push/src/rust/api.dart'
    show BotPolicy, GameMatchPhase, GameMove, GameSnapshot, MatchSnapshot;

/// The Dart-side boundary over the Rust match rules.
///
/// Every value crossing it is a snapshot Rust produced and can re-verify, so
/// Dart cannot fabricate a position, a score, or a result.
abstract interface class RulesEngine {
  rust.MatchSnapshot initialMatch();

  List<rust.GameMove> legalMoves(rust.MatchSnapshot state);

  rust.MatchSnapshot applyMove(rust.MatchSnapshot state, rust.GameMove move);

  rust.MatchSnapshot advanceRound(rust.MatchSnapshot state);

  /// The move the given policy would play, or null when the round offers
  /// none. Which move is the engine's answer; Dart never picks one.
  rust.GameMove? chooseBotMove(rust.MatchSnapshot state, rust.BotPolicy policy);
}

final class FrbRulesEngine implements RulesEngine {
  const FrbRulesEngine();

  @override
  rust.MatchSnapshot initialMatch() => rust.initialMatch();

  @override
  List<rust.GameMove> legalMoves(rust.MatchSnapshot state) =>
      rust.matchLegalMoves(snapshot: state);

  @override
  rust.MatchSnapshot applyMove(rust.MatchSnapshot state, rust.GameMove move) =>
      rust.matchApplyMove(snapshot: state, gameMove: move);

  @override
  rust.MatchSnapshot advanceRound(rust.MatchSnapshot state) =>
      rust.advanceRound(snapshot: state);

  @override
  rust.GameMove? chooseBotMove(
    rust.MatchSnapshot state,
    rust.BotPolicy policy,
  ) => rust.chooseBotMove(snapshot: state, policy: policy);
}
