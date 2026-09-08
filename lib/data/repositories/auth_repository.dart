import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../core/utils/app_exception.dart';
import '../models/app_user.dart';
import '../models/fitness_level.dart';
import '../services/api_client.dart';
import '../services/local_store.dart';

/// عقد المصادقة — التطبيق لا يعرف إن كان الحساب محلياً أم على السيرفر.
abstract class AuthRepository {
  Future<AppUser?> currentUser();

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> updateProfile(AppUser user);

  Future<void> requestPasswordReset(String email);

  Future<void> signOut();

  Future<void> deleteAccount();
}

// ---------------------------------------------------------------------------
// تنفيذ محلي — يعمل بدون سيرفر (وضع العرض والتجربة)
// ---------------------------------------------------------------------------

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._store);

  final LocalStore _store;

  @override
  Future<AppUser?> currentUser() async {
    final id = _store.getString(LocalStore.kCurrentUserId);
    if (id == null || id.isEmpty) return null;
    final record = _findById(id);
    return record == null ? null : AppUser.fromJson(record);
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final users = _store.getJsonList(LocalStore.kUsers);

    final exists = users.any(
      (u) => (u['email'] ?? '').toString().toLowerCase() == normalizedEmail,
    );
    if (exists) {
      throw const AppException(
        'هذا البريد مسجّل من قبل. سجّل دخولك بدل إنشاء حساب جديد.',
        code: 'email_taken',
        canRetry: false,
      );
    }

    final id = 'u_${DateTime.now().microsecondsSinceEpoch}';
    final salt = _generateSalt();
    final user = AppUser(
      id: id,
      name: name.trim(),
      email: normalizedEmail,
      createdAt: DateTime.now(),
    );

    users.add(<String, dynamic>{
      ...user.toJson(),
      'salt': salt,
      'passwordHash': _hash(password, salt),
    });

    await _store.setJsonList(LocalStore.kUsers, users);
    await _store.setString(LocalStore.kCurrentUserId, id);
    return user;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final users = _store.getJsonList(LocalStore.kUsers);

    final record = users.cast<Map<String, dynamic>?>().firstWhere(
          (u) =>
              (u?['email'] ?? '').toString().toLowerCase() == normalizedEmail,
          orElse: () => null,
        );

    final salt = (record?['salt'] ?? '').toString();
    if (record == null || _hash(password, salt) != record['passwordHash']) {
      throw const AppException(
        'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
        code: 'invalid_credentials',
        canRetry: false,
      );
    }

    final user = AppUser.fromJson(record);
    await _store.setString(LocalStore.kCurrentUserId, user.id);
    return user;
  }

  @override
  Future<AppUser> updateProfile(AppUser user) async {
    final users = _store.getJsonList(LocalStore.kUsers);
    final index = users.indexWhere((u) => u['id'] == user.id);
    if (index == -1) {
      throw const AppException('ما لقينا حسابك.', code: 'user_not_found');
    }
    users[index] = <String, dynamic>{
      ...users[index],
      ...user.toJson(),
    };
    await _store.setJsonList(LocalStore.kUsers, users);
    return user;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    // في الوضع المحلي لا يوجد بريد؛ نتحقق فقط من وجود الحساب.
    final normalizedEmail = email.trim().toLowerCase();
    final users = _store.getJsonList(LocalStore.kUsers);
    final exists = users.any(
      (u) => (u['email'] ?? '').toString().toLowerCase() == normalizedEmail,
    );
    if (!exists) {
      throw const AppException(
        'ما لقينا حساباً بهذا البريد.',
        code: 'user_not_found',
        canRetry: false,
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _store.remove(LocalStore.kCurrentUserId);
  }

  @override
  Future<void> deleteAccount() async {
    final id = _store.getString(LocalStore.kCurrentUserId);
    if (id == null) return;
    final users = _store.getJsonList(LocalStore.kUsers)
      ..removeWhere((u) => u['id'] == id);
    await _store.setJsonList(LocalStore.kUsers, users);
    await _store.clearUserScopedData(id);
    await _store.remove(LocalStore.kCurrentUserId);
  }

  Map<String, dynamic>? _findById(String id) {
    for (final user in _store.getJsonList(LocalStore.kUsers)) {
      if (user['id'] == id) return user;
    }
    return null;
  }

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt::$password')).toString();
}

// ---------------------------------------------------------------------------
// تنفيذ عبر الباك إند
// ---------------------------------------------------------------------------

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._api, this._store);

  final ApiClient _api;
  final LocalStore _store;

  @override
  Future<AppUser?> currentUser() async {
    final token = await _store.secureRead(LocalStore.kAuthToken);
    if (token == null || token.isEmpty) return null;
    _api.setToken(token);
    try {
      final response = await _api.get('/auth/me');
      return _userFrom(response);
    } on AppException catch (error) {
      if (error.code == 'unauthorized') {
        await signOut();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '/auth/register',
      body: <String, dynamic>{
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );
    return _persistSession(response);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '/auth/login',
      body: <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );
    return _persistSession(response);
  }

  @override
  Future<AppUser> updateProfile(AppUser user) async {
    final response = await _api.put(
      '/auth/me',
      body: <String, dynamic>{
        'name': user.name,
        'level': user.level.id,
        'goal': user.goal.id,
        'age': user.age,
        'weightKg': user.weightKg,
        'heightCm': user.heightCm,
        'gender': user.gender,
        'hasCompletedOnboarding': user.hasCompletedOnboarding,
        'healthSyncEnabled': user.healthSyncEnabled,
      },
    );
    return _userFrom(response);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _api.post(
      '/auth/forgot-password',
      body: <String, dynamic>{'email': email.trim().toLowerCase()},
    );
  }

  @override
  Future<void> signOut() async {
    _api.setToken(null);
    await _store.secureWrite(LocalStore.kAuthToken, null);
    await _store.remove(LocalStore.kCurrentUserId);
  }

  @override
  Future<void> deleteAccount() async {
    await _api.delete('/auth/me');
    await signOut();
  }

  Future<AppUser> _persistSession(Map<String, dynamic> response) async {
    final token = response['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const AppException('رد غير متوقع من الخدمة.', code: 'bad_response');
    }
    _api.setToken(token);
    await _store.secureWrite(LocalStore.kAuthToken, token);
    final user = _userFrom(response);
    await _store.setString(LocalStore.kCurrentUserId, user.id);
    return user;
  }

  AppUser _userFrom(Map<String, dynamic> response) {
    final raw = response['user'];
    if (raw is! Map) {
      throw const AppException('رد غير متوقع من الخدمة.', code: 'bad_response');
    }
    return AppUser.fromJson(raw.map((k, v) => MapEntry(k.toString(), v)));
  }
}

/// امتداد يبني مستخدماً افتراضياً — يُستخدم في الاختبارات والمعاينة.
AppUser demoUser() => AppUser(
      id: 'demo',
      name: 'متدرب',
      email: 'demo@coachmin.tech',
      level: FitnessLevel.beginner,
      createdAt: DateTime.now(),
    );
