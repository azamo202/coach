import 'package:flutter/foundation.dart';

import '../data/models/health_snapshot.dart';
import '../data/services/health_service.dart';
import '../data/services/local_store.dart';

/// يدير ربط التطبيق ببيانات الصحة على الجهاز.
class HealthController extends ChangeNotifier {
  HealthController({
    required HealthService service,
    required LocalStore store,
  })  : _service = service,
        _store = store;

  final HealthService _service;
  final LocalStore _store;

  HealthSnapshot _snapshot = HealthSnapshot.empty;
  bool _busy = false;
  bool _checked = false;

  HealthSnapshot get snapshot => _snapshot;
  bool get isBusy => _busy;
  bool get isConnected => _snapshot.isAuthorized && _snapshot.isAvailable;
  bool get isAvailable => _snapshot.isAvailable;

  bool get isEnabled => _store.getBool(LocalStore.kHealthEnabled);

  /// يُستدعى عند الإقلاع: يقرأ آخر لقطة مخزّنة ثم يحدّثها في الخلفية.
  Future<void> bootstrap() async {
    if (_checked) return;
    _checked = true;

    final cached = _store.getJson(LocalStore.kHealthSnapshot);
    if (cached != null) {
      _snapshot = HealthSnapshot.fromJson(cached);
      notifyListeners();
    }

    if (isEnabled) {
      await refresh();
    }
  }

  /// يطلب الصلاحيات ثم يقرأ البيانات. يُرجع true إذا نجح الربط.
  Future<bool> connect() async {
    _busy = true;
    notifyListeners();
    try {
      final available = await _service.isAvailable();
      if (!available) {
        _snapshot = const HealthSnapshot(isAvailable: false);
        await _persist();
        return false;
      }

      final granted = await _service.requestAuthorization();
      await _store.setBool(LocalStore.kHealthEnabled, value: granted);
      if (!granted) {
        _snapshot = _snapshot.copyWith(isAuthorized: false);
        await _persist();
        return false;
      }

      _snapshot = await _service.fetchSnapshot();
      await _persist();
      return true;
    } catch (error) {
      debugPrint('Health connect failed: $error');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      _snapshot = await _service.fetchSnapshot();
      await _persist();
    } catch (error) {
      debugPrint('Health refresh failed: $error');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _store.setBool(LocalStore.kHealthEnabled, value: false);
    _snapshot = HealthSnapshot.empty;
    await _persist();
    notifyListeners();
  }

  Future<void> openHealthConnectInstall() => _service.installHealthConnect();

  Future<void> _persist() =>
      _store.setJson(LocalStore.kHealthSnapshot, _snapshot.toJson());
}
