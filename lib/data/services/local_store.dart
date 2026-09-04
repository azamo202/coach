import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// طبقة التخزين على الجهاز.
///
/// - [SharedPreferences] للبيانات العادية (المكتبة، الإعدادات).
/// - [FlutterSecureStorage] للتوكن وبيانات الحسابات الحساسة.
class LocalStore {
  LocalStore._(this._prefs);

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String kOnboardingSeen = 'onboarding_seen';
  static const String kCurrentUserId = 'current_user_id';
  static const String kUsers = 'local_users';
  static const String kLibraryPrefix = 'library_';
  static const String kHealthSnapshot = 'health_snapshot';
  static const String kHealthEnabled = 'health_enabled';
  static const String kAuthToken = 'auth_token';
  static const String kCredentialsPrefix = 'cred_';

  final SharedPreferences _prefs;

  static LocalStore? _instance;

  static Future<LocalStore> instance() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    return _instance = LocalStore._(prefs);
  }

  // ------------------------------------------------------------------
  // أساسيات
  // ------------------------------------------------------------------

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;

  Future<void> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  /// قراءة كائن JSON مخزَّن.
  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } on FormatException catch (error) {
      debugPrint('LocalStore decode failed for $key: $error');
    }
    return null;
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  /// قراءة قائمة JSON مخزَّنة.
  List<Map<String, dynamic>> getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      }
    } on FormatException catch (error) {
      debugPrint('LocalStore list decode failed for $key: $error');
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value));

  // ------------------------------------------------------------------
  // التخزين الآمن
  // ------------------------------------------------------------------

  Future<String?> secureRead(String key) async {
    try {
      final value = await _secure.read(key: key);
      if (value != null) return value;
    } catch (error) {
      debugPrint('Secure read failed for $key: $error');
    }
    return _prefs.getString('sec_$key');
  }

  Future<void> secureWrite(String key, String? value) async {
    try {
      if (value == null) {
        await _secure.delete(key: key);
      } else {
        await _secure.write(key: key, value: value);
      }
    } catch (error) {
      debugPrint('Secure write failed for $key: $error');
    }
    if (value == null) {
      await _prefs.remove('sec_$key');
    } else {
      await _prefs.setString('sec_$key', value);
    }
  }

  // ------------------------------------------------------------------
  // مساعدات خاصة بالتطبيق
  // ------------------------------------------------------------------

  String libraryKey(String userId) => '$kLibraryPrefix$userId';

  Future<void> clearUserScopedData(String userId) async {
    await _prefs.remove(libraryKey(userId));
  }
}
