import 'package:coachmint/data/models/health_snapshot.dart';
import 'package:coachmint/data/services/health_service.dart';
import 'package:coachmint/data/services/local_store.dart';
import 'package:coachmint/state/health_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حارس التمييز بين «الجهاز لا يدعم» و«المستخدم رفض».
///
/// الحالتان تنتهيان بـ`connect()` راجعةً `false`، لكن ما يراه المستخدم
/// بعدهما يجب أن يختلف: الأولى «خدمة الصحة غير متاحة على هذا الجهاز»،
/// والثانية دعوة لإعادة المحاولة بعد الموافقة.
///
/// خلطهما ليس فرضاً نظرياً: HealthKit غير متاح على iPad قبل iOS 17 —
/// والتطبيق يُنشر لـiPad — وحزمة `health` لا تعرض فحص توفّر لـiOS، فكان
/// كل مستخدم iPad قديم يُلام على رفضٍ لم يقع ويُدعى لمحاولة لن تنجح.
void main() {
  Future<HealthController> controllerWith(HealthService service) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await LocalStore.instance();
    return HealthController(service: service, store: store);
  }

  test('خدمة غائبة عن الجهاز تُعرض كعدم توفّر لا كرفض', () async {
    final controller = await controllerWith(_UnavailableService());

    final connected = await controller.connect();

    expect(connected, isFalse);
    expect(
      controller.isAvailable,
      isFalse,
      reason: 'الواجهة تقرأ هذا لتقول «غير متاحة على هذا الجهاز»',
    );
    expect(controller.isConnected, isFalse);
    expect(
      controller.isEnabled,
      isFalse,
      reason: 'لا يجوز تفعيل مزامنة لخدمة لا توجد',
    );
  });

  test('رفض المستخدم يبقي الخدمة متاحة والصلاحية مرفوضة', () async {
    final controller = await controllerWith(_DeniedService());

    final connected = await controller.connect();

    expect(connected, isFalse);
    expect(
      controller.isAvailable,
      isTrue,
      reason: 'الجهاز يدعم الخدمة — المستخدم وحده هو من رفض',
    );
    expect(controller.isConnected, isFalse);
    expect(controller.isEnabled, isFalse);
  });

  test('الموافقة تربط الخدمة وتقرأ اللقطة', () async {
    final controller = await controllerWith(_GrantedService());

    final connected = await controller.connect();

    expect(connected, isTrue);
    expect(controller.isConnected, isTrue);
    expect(controller.isEnabled, isTrue);
    expect(controller.snapshot.steps, 8000);
  });
}

/// جهاز بلا خدمة صحة — `requestAuthorization` ترجع `null`.
///
/// [isAvailable] ترجع `true` عمداً: هذا هو بالضبط ما يحدث على iPad، إذ
/// لا تملك الحزمة فحص توفّر لـiOS فتقول «متاح» ثم يفشل الطلب.
class _UnavailableService extends HealthService {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool?> requestAuthorization() async => null;
}

class _DeniedService extends HealthService {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool?> requestAuthorization() async => false;
}

class _GrantedService extends HealthService {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool?> requestAuthorization() async => true;

  @override
  Future<HealthSnapshot> fetchSnapshot({int days = 7}) async => HealthSnapshot(
        steps: 8000,
        activeCalories: 420,
        workoutMinutes: 150,
        updatedAt: DateTime(2026, 9, 9),
        isAuthorized: true,
      );
}
