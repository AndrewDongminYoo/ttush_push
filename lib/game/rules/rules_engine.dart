import 'package:ttush_push/src/rust/api.dart' as rust;

export 'package:ttush_push/src/rust/api.dart' show GameMove, GameSnapshot;

abstract interface class RulesEngine {
  rust.GameSnapshot initialState();

  List<rust.GameMove> legalMoves(rust.GameSnapshot state);

  rust.GameSnapshot applyMove(rust.GameSnapshot state, rust.GameMove move);
}

final class FrbRulesEngine implements RulesEngine {
  const FrbRulesEngine();

  @override
  rust.GameSnapshot initialState() => rust.initialState();

  @override
  List<rust.GameMove> legalMoves(rust.GameSnapshot state) =>
      rust.legalMoves(snapshot: state);

  @override
  rust.GameSnapshot applyMove(rust.GameSnapshot state, rust.GameMove move) =>
      rust.applyMove(snapshot: state, gameMove: move);
}
