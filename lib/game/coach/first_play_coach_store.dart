import 'package:shared_preferences/shared_preferences.dart';

const firstPlayCoachVersion = 1;

abstract interface class FirstPlayCoachStore {
  Future<bool> isComplete({required int version});

  Future<void> markComplete({required int version});
}

final class SharedPreferencesFirstPlayCoachStore
    implements FirstPlayCoachStore {
  SharedPreferencesFirstPlayCoachStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> isComplete({required int version}) async {
    return await _preferences.getBool(_key(version)) ?? false;
  }

  @override
  Future<void> markComplete({required int version}) {
    return _preferences.setBool(_key(version), true);
  }

  String _key(int version) => 'ttush_push.first_play_coach.v$version.complete';
}
