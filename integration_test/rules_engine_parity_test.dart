import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RulesEngine returns the cross-platform snapshot fingerprints', (
    tester,
  ) async {
    await RustLib.init();
    const rulesEngine = FrbRulesEngine();

    final initial = rulesEngine.initialState();
    final firstMove = rulesEngine
        .legalMoves(initial)
        .singleWhere(
          (move) => move.pieceId == 0 && move.direction.name == 'down',
        );
    final afterFirstMove = rulesEngine.applyMove(initial, firstMove);

    expect(initial.snapshotHash, '008d1d43a9eefe72');
    expect(afterFirstMove.snapshotHash, '540736b5048c5f9f');
  });
}
