import 'package:flutter/foundation.dart';

import '../core/utils/app_exception.dart';
import '../data/models/app_user.dart';
import '../data/models/fitness_level.dart';
import '../data/repositories/auth_repository.dart';
import '../data/services/local_store.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// يدير جلسة المستخدم وبياناته الشخصية.
class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required LocalStore store,
  })  : _repository = repository,
        _store = store;

  final AuthRepository _repository;
  final LocalStore _store;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _busy = false;
  String? _error;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isBusy => _busy;
  String? get error => _error;
  bool get isSignedIn => _status == AuthStatus.signedIn && _user != null;

  bool get hasSeenOnboarding => _store.getBool(LocalStore.kOnboardingSeen);

  Future<void> markOnboardingSeen() async {
    await _store.setBool(LocalStore.kOnboardingSeen, value: true);
    notifyListeners();
  }

  /// يُستدعى عند إقلاع التطبيق لاستعادة الجلسة.
  Future<void> bootstrap() async {
    try {
      final user = await _repository.currentUser();
      _user = user;
      _status = user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    } catch (error) {
      debugPrint('Bootstrap failed: $error');
      _status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) =>
      _run(() async {
        _user = await _repository.signUp(
          name: name,
          email: email,
          password: password,
        );
        _status = AuthStatus.signedIn;
      });

  Future<bool> signIn({
    required String email,
    required String password,
  }) =>
      _run(() async {
        _user = await _repository.signIn(email: email, password: password);
        _status = AuthStatus.signedIn;
      });

  Future<bool> requestPasswordReset(String email) =>
      _run(() => _repository.requestPasswordReset(email));

  /// حفظ المستوى والهدف — الخطوة التي تحدد شكل البرامج المولَّدة.
  Future<bool> completeProfileSetup({
    required FitnessLevel level,
    required TrainingGoal goal,
    int? age,
    double? weightKg,
    double? heightCm,
    String? gender,
  }) =>
      _run(() async {
        final current = _user;
        if (current == null) throw AppException.unauthorized;
        _user = await _repository.updateProfile(
          current.copyWith(
            level: level,
            goal: goal,
            age: age,
            weightKg: weightKg,
            heightCm: heightCm,
            gender: gender,
            hasCompletedOnboarding: true,
          ),
        );
      });

  Future<bool> updateProfile(AppUser updated) => _run(() async {
        _user = await _repository.updateProfile(updated);
      });

  Future<bool> setHealthSync({required bool enabled}) => _run(() async {
        final current = _user;
        if (current == null) throw AppException.unauthorized;
        _user = await _repository.updateProfile(
          current.copyWith(healthSyncEnabled: enabled),
        );
      });

  Future<void> signOut() async {
    await _repository.signOut();
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<bool> deleteAccount() => _run(() async {
        await _repository.deleteAccount();
        _user = null;
        _status = AuthStatus.signedOut;
      });

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AppException catch (error) {
      _error = error.message;
      return false;
    } catch (error) {
      debugPrint('Auth action failed: $error');
      _error = 'صار خطأ غير متوقع. حاول مرة ثانية.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
