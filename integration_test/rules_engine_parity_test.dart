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

    // The bot seeds itself from the round's own hash, so an agreed hash
    // ought to imply an agreed move. That is an argument, not a
    // measurement: the seed still has to survive both runtimes' integer
    // width and the policies still have to walk the position the same way.
    // These are the moves `value_api_pins_the_parity_fixture_bot_moves`
    // fixes on the host.
    const expectedByPolicy = {
      BotPolicy.random: GameMove(pieceId: 1, direction: GameDirection.down),
      BotPolicy.greedy: GameMove(pieceId: 1, direction: GameDirection.down),
      BotPolicy.minimax: GameMove(pieceId: 0, direction: GameDirection.right),
    };
    for (final entry in expectedByPolicy.entries) {
      expect(
        rulesEngine.chooseBotMove(match, entry.key),
        entry.value,
        reason: '${entry.key} chose a different move on this runtime',
      );
    }
  });
}
