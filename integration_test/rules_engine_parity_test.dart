import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/api.dart';
import 'package:ttush_push/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RulesEngine returns the cross-platform push fixture', (
    tester,
  ) async {
    await RustLib.init();
    const rulesEngine = FrbRulesEngine();

    var match = rulesEngine.initialMatch();
    const fixtureMoves = [
      GameMove(pieceId: 0, direction: GameDirection.down),
      GameMove(pieceId: 2, direction: GameDirection.up),
      GameMove(pieceId: 0, direction: GameDirection.down),
      GameMove(pieceId: 2, direction: GameDirection.up),
    ];

    for (final move in fixtureMoves) {
      expect(rulesEngine.legalMoves(match), contains(move));
      match = rulesEngine.applyMove(match, move);
    }

    // The round hash is the parity evidence: both native runtimes must
    // derive the same canonical state from the same moves.
    expect(match.round.snapshotHash, '7044880ea390e9a8');
    expect(match.phase, GameMatchPhase.playing);
    expect(
      rulesEngine.legalMoves(match),
      isNot(
        contains(
          const GameMove(pieceId: 0, direction: GameDirection.down),
        ),
      ),
    );
  });
}
