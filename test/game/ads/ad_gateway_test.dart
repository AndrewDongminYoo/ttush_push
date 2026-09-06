import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/game/ads/ad_gateway.dart';

void main() {
  test('the shipped default completes both moments', () async {
    const gateway = NoAdGateway();

    await expectLater(gateway.matchDecided(), completes);
    await expectLater(gateway.beforeNewMatch(), completes);
  });

  test('the shipped default is a compile-time constant', () {
    expect(identical(const NoAdGateway(), const NoAdGateway()), isTrue);
  });
}
