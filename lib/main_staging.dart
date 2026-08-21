import 'package:ttush_push/app/app.dart';
import 'package:ttush_push/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
