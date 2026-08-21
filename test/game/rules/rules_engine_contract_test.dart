import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';

void main() {
  test('FrbRulesEngine implements the synchronous RulesEngine contract', () {
    const RulesEngine rulesEngine = FrbRulesEngine();

    expect(rulesEngine, isA<FrbRulesEngine>());
  });
}
