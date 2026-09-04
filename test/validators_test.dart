import 'package:flutter_test/flutter_test.dart';
import 'package:coachmint/core/utils/sport_visuals.dart';
import 'package:coachmint/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('يقبل البريد الصحيح', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email('  a.b+c@sub.domain.sa  '), isNull);
    });

    test('يرفض البريد غير الصحيح', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('user@'), isNotNull);
      expect(Validators.email('user.com'), isNotNull);
      expect(Validators.email('@example.com'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('يشترط 8 أحرف مع أرقام وحروف', () {
      expect(Validators.password('Passw0rd'), isNull);
      expect(Validators.password('abc123'), isNotNull); // قصيرة
      expect(Validators.password('abcdefgh'), isNotNull); // بدون أرقام
      expect(Validators.password('12345678'), isNotNull); // بدون حروف
    });

    test('التأكيد يطابق كلمة المرور', () {
      expect(Validators.confirmPassword('Passw0rd', 'Passw0rd'), isNull);
      expect(Validators.confirmPassword('Passw0rd', 'Other123'), isNotNull);
      expect(Validators.confirmPassword('', 'Passw0rd'), isNotNull);
    });
  });

  group('Validators.sport', () {
    test('يقبل أي رياضة معقولة', () {
      expect(Validators.sport('كرة سلة'), isNull);
      expect(Validators.sport('تسلق صخور'), isNull);
    });

    test('يرفض الفارغ والطويل جداً', () {
      expect(Validators.sport(''), isNotNull);
      expect(Validators.sport('ك'), isNotNull);
      expect(Validators.sport('ا' * 50), isNotNull);
    });
  });

  group('Validators.optionalNumber', () {
    test('الحقل الفارغ مقبول', () {
      expect(
        Validators.optionalNumber('', min: 10, max: 90, label: 'العمر'),
        isNull,
      );
    });

    test('يتحقق من المدى', () {
      expect(
        Validators.optionalNumber('25', min: 10, max: 90, label: 'العمر'),
        isNull,
      );
      expect(
        Validators.optionalNumber('5', min: 10, max: 90, label: 'العمر'),
        isNotNull,
      );
      expect(
        Validators.optionalNumber('abc', min: 10, max: 90, label: 'العمر'),
        isNotNull,
      );
    });
  });

  group('SportVisuals', () {
    test('يأخذ أول حرف من اسم الرياضة', () {
      expect(SportVisuals.initialFor('كرة قدم'), 'ك');
      expect(SportVisuals.initialFor('سباحة'), 'س');
      expect(SportVisuals.initialFor('ملاكمة'), 'م');
    });

    test('يعمل مع أي اسم، حتى غير العربي أو المسبوق بمسافات', () {
      expect(SportVisuals.initialFor('  Padel'), 'P');
      expect(SportVisuals.initialFor('«تسلق»'), 'ت');
    });

    test('يرجع علامة بديلة حين لا يوجد حرف أصلاً', () {
      expect(SportVisuals.initialFor('   '), '؟');
    });

    test('روابط المرجع السريع تحتوي اسم التمرين', () {
      final uri = SportVisuals.howToVideoUrl('سكوات', 'كرة قدم');
      expect(uri.toString(), contains('youtube.com'));
      expect(Uri.decodeFull(uri.toString()), contains('سكوات'));
    });
  });
}
