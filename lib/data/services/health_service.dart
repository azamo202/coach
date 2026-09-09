import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../models/health_snapshot.dart';

/// تكامل بيانات الصحة:
/// - iOS: Apple HealthKit
/// - Android: Health Connect (الواجهة الرسمية التي حلّت محل Google Fit APIs)
///
/// كل الاستدعاءات محاطة بمعالجة أخطاء، فإذا لم تتوفر الخدمة على الجهاز
/// يستمر التطبيق بالعمل طبيعياً بدون بيانات صحية.
class HealthService {
  HealthService();

  final Health _health = Health();

  bool _configured = false;

  static final List<HealthDataType> _readTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WORKOUT,
  ];

  List<HealthDataAccess> get _readPermissions =>
      _readTypes.map((_) => HealthDataAccess.READ).toList();

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// هل الجهاز يدعم قراءة البيانات الصحية؟
  Future<bool> isAvailable() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;
    try {
      await _ensureConfigured();
      if (!kIsWeb && Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        return status == HealthConnectSdkStatus.sdkAvailable;
      }
      return true;
    } catch (error) {
      debugPrint('Health availability check failed: $error');
      return false;
    }
  }

  /// طلب صلاحيات القراءة من المستخدم.
  ///
  /// يُرجع `true` للموافقة، و`false` للرفض، و**`null` حين لا تكون خدمة
  /// الصحة موجودة على الجهاز أصلاً**.
  ///
  /// التمييز الثالث ليس ترفاً: HealthKit غير متاح على iPad قبل iOS 17،
  /// و[isAvailable] لا يكشف ذلك لأن حزمة `health` لا تعرض فحص توفّر
  /// لـiOS. بلا هذا التمييز يرى مستخدم iPad رسالة «ما وافقت على
  /// الصلاحيات» بعد أن لم يُسأل شيئاً — يلومه على رفضٍ لم يقع، ويدعوه
  /// لإعادة محاولة لن تنجح أبداً.
  Future<bool?> requestAuthorization() async {
    try {
      await _ensureConfigured();
      return await _health.requestAuthorization(
        _readTypes,
        permissions: _readPermissions,
      );
    } catch (error) {
      debugPrint('Health authorization unavailable: $error');
      return null;
    }
  }

  Future<bool> hasPermissions() async {
    try {
      await _ensureConfigured();
      return await _health.hasPermissions(
            _readTypes,
            permissions: _readPermissions,
          ) ??
          false;
    } catch (error) {
      debugPrint('Health permission check failed: $error');
      return false;
    }
  }

  /// يفتح شاشة تثبيت Health Connect على أندرويد عند الحاجة.
  Future<void> installHealthConnect() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _health.installHealthConnect();
    } catch (error) {
      debugPrint('Health Connect install prompt failed: $error');
    }
  }

  /// يقرأ ملخّص نشاط المستخدم لآخر [days] أيام.
  Future<HealthSnapshot> fetchSnapshot({int days = 7}) async {
    final available = await isAvailable();
    if (!available) {
      return const HealthSnapshot(isAvailable: false);
    }

    final authorized = await hasPermissions();
    if (!authorized) {
      return const HealthSnapshot(isAuthorized: false);
    }

    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));

    var steps = 0;
    var activeCalories = 0.0;
    var distance = 0.0;
    var workoutMinutes = 0;
    double? restingHr;

    try {
      steps = await _health.getTotalStepsInInterval(start, now) ?? 0;
    } catch (error) {
      debugPrint('Steps read failed: $error');
    }

    try {
      final points = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: _readTypes,
      );
      final unique = _health.removeDuplicates(points);

      final restingValues = <double>[];

      for (final point in unique) {
        final value = point.value;
        switch (point.type) {
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            activeCalories += _numeric(value);
          case HealthDataType.DISTANCE_DELTA:
            distance += _numeric(value);
          case HealthDataType.RESTING_HEART_RATE:
            final v = _numeric(value);
            if (v > 0) restingValues.add(v);
          case HealthDataType.WORKOUT:
            workoutMinutes +=
                point.dateTo.difference(point.dateFrom).inMinutes.abs();
          default:
            break;
        }
      }

      if (restingValues.isNotEmpty) {
        restingHr =
            restingValues.reduce((a, b) => a + b) / restingValues.length;
      }
    } catch (error) {
      debugPrint('Health data read failed: $error');
    }

    return HealthSnapshot(
      steps: days > 0 ? (steps / days).round() : steps,
      activeCalories: activeCalories,
      workoutMinutes: workoutMinutes,
      restingHeartRate: restingHr,
      distanceMeters: distance,
      updatedAt: DateTime.now(),
      isAuthorized: true,
    );
  }

  static double _numeric(HealthValue value) {
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return 0;
  }
}
