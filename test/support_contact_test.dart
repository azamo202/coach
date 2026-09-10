import 'dart:io';

import 'package:coachmint/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// حارس التطابق بين ما تَعِد به الصفحات المنشورة وما يقدّمه التطبيق.
///
/// سياسة الخصوصية وشروط الاستخدام منشورتان على الإنترنت وتَعِدان صراحةً
/// بوسيلتَي تواصل: بريد الدعم، ومدخل داخل التطبيق في «حسابي ← الدعم
/// والمساعدة». وقد كانت الصفحتان تَعِدان بمدخل داخل التطبيق **لم يكن
/// موجوداً أصلاً** — وهو تعارض يقرؤه مراجع App Store لأنه يفتح السياسة
/// ويقارنها بالتطبيق، وتطلب Apple وسيلة تواصل فعّالة (إرشاد 1.5).
///
/// هذه الاختبارات تجعل حذف المدخل أو تغيير البريد كسراً صريحاً بدل
/// تعارض صامت يُكتشف عند الرفض.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('وعود صفحات الويب مقابل التطبيق', () {
    test('بريد الدعم في الإعدادات يطابق المنشور في الصفحتين', () {
      for (final page in <String>[
        'backend/public/privacy.html',
        'backend/public/terms.html',
        // صفحة الهبوط هي Support URL المسجَّل في App Store.
        'backend/public/index.html',
      ]) {
        expect(
          read(page),
          contains(AppConfig.supportEmail),
          reason: '$page ينشر بريد دعم مختلفاً عمّا يعرضه التطبيق',
        );
      }
    });

    test('مدخل الدعم الموعود به موجود فعلاً في شاشة الحساب', () {
      final profile = read('lib/features/profile/profile_screen.dart');

      expect(
        profile,
        contains('الدعم والمساعدة'),
        reason: 'الصفحتان تَعِدان بـ«حسابي ← الدعم والمساعدة»',
      );
      expect(
        profile,
        contains('AppConfig.supportEmail'),
        reason: 'المدخل يجب أن يفتح بريد الدعم لا عنواناً مكتوباً يدوياً',
      );
    });
  });

  group('أذونات iOS تطابق ما يفعله التطبيق', () {
    test('لا نطلب إذن الكتابة في تطبيق الصحة ما دمنا لا نكتب', () {
      final plist = read('ios/Runner/Info.plist');
      final service = read('lib/data/services/health_service.dart');

      expect(
        service,
        isNot(contains('HealthDataAccess.WRITE')),
        reason: 'إن صار التطبيق يكتب فعلاً، أعد النصّ إلى Info.plist',
      );
      expect(
        plist,
        isNot(contains('NSHealthUpdateUsageDescription')),
        reason: 'نصّ إذن يَعِد بتسجيل الجلسات في تطبيق الصحة بينما نقرأ فقط',
      );
      expect(
        plist,
        contains('NSHealthShareUsageDescription'),
        reason: 'إذن القراءة مطلوب — التطبيق يقرأ النشاط فعلاً',
      );
    });
  });
}
