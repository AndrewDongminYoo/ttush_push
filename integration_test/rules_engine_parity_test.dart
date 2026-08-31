import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/src/rust/frb_generated.dart';

import '../test/support/rules_engine_parity.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RulesEngine returns the cross-platform push fixture', (
    _,
  ) async {
    await RustLib.init();
    addTearDown(RustLib.dispose);

    expectRulesEngineParity(const FrbRulesEngine());
  });

  testWidgets('RulesEngine returns an irregular board definition', (_) async {
    await RustLib.init();
    addTearDown(RustLib.dispose);

    expectIrregularBoardDefinition(const FrbRulesEngine());
  });

  testWidgets('RulesEngine rejects an invalid board definition', (_) async {
    await RustLib.init();
    addTearDown(RustLib.dispose);

    expectInvalidBoardDefinitionIsRejected(const FrbRulesEngine());
  });
}
