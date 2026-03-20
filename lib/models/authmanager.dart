import 'package:shared_preferences/shared_preferences.dart';

class AuthManager {
  static const _guestKey = 'isGuestUser';
  static const _guestIdKey = 'guestId';

  static Future<void> setGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, true);
    await getOrCreateGuestId();
  }

  static Future<void> setLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, false);
  }

  static Future<bool> isGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestKey) ?? false;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<String> getOrCreateGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_guestIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final newId = _generateToken();
    await prefs.setString(_guestIdKey, newId);
    return newId;
  }

  static Future<String?> getGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_guestIdKey);
  }

  static String _generateToken() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final rand = (millis ^ 0x5f3759df).toRadixString(36);
    return 'guest_$millis$rand';
  }
}
