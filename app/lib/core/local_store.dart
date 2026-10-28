import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small persistent key-value cache: last loaded lists are shown instantly on the next start.
class LocalStore {
  static late SharedPreferences _p;
  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  static String? getString(String k) => _p.getString(k);
  static Future<void> setString(String k, String v) => _p.setString(k, v);
  static bool? getBool(String k) => _p.getBool(k);
  static Future<void> setBool(String k, bool v) => _p.setBool(k, v);
  static Future<void> remove(String k) => _p.remove(k);

  static dynamic getJson(String k) {
    final s = _p.getString(k);
    if (s == null) return null;
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setJson(String k, Object? v) => _p.setString(k, jsonEncode(v));

  /// Removes everything that belongs to the signed-in user (keeps app-wide prefs like the language).
  static Future<void> clearUserData() async {
    for (final k in _p.getKeys().where((k) => k.startsWith('u:')).toList()) {
      await _p.remove(k);
    }
  }
}
