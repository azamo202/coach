import 'package:coachmint/core/utils/ar_plural.dart';
import 'package:flutter_test/flutter_test.dart';

/// حارس صياغة العدد.
///
/// الشاشات كانت تكتب قاعدتها بنفسها، فظهر «2 جلسة» في مكان و«جلستان» في آخر.
/// هذه الاختبارات تثبّت القاعدة الواحدة في نقاط انكسارها: الصفر، المثنّى،
/// وحدّ جمع القلّة عند 10 و11.
void main() {
  group('صيغة العدد', () {
    test('الصفر يقول «لا» ولا يكتب رقماً', () {
      expect(Ar.session(0), 'لا جلسات');
      expect(Ar.week(0), 'بلا أسابيع');
    });

    test('المفرد والمثنّى بلا رقم', () {
      expect(Ar.session(1), 'جلسة واحدة');
      expect(Ar.session(2), 'جلستان');
      expect(Ar.week(1), 'أسبوع واحد');
      expect(Ar.week(2), 'أسبوعان');
      expect(Ar.exercise(2), 'تمرينان');
    });

    test('جمع القلّة من 3 إلى 10', () {
      expect(Ar.session(3), '3 جلسات');
      expect(Ar.session(10), '10 جلسات');
      expect(Ar.week(4), '4 أسابيع');
    });

    test('تمييز الكثرة منصوب مفرداً من 11 فأعلى', () {
      expect(Ar.session(11), '11 جلسة');
      expect(Ar.week(12), '12 أسبوعاً');
      expect(Ar.exercise(72), '72 تمريناً');
    });

    test('الاسم المجرّد يتبع العدد نفسه', () {
      expect(Ar.session.unit(6), 'جلسات');
      expect(Ar.session.unit(18), 'جلسة');
      expect(Ar.week.unit(2), 'أسبوعاً');
    });

    test('«س من ص» يميّز بالإجمالي لا بالمنجز', () {
      // المعدود في الجملة هو 18، فالتمييز يتبعه وإن كان المنجز 6.
      expect(Ar.outOf(6, 18, Ar.session), '6 من 18 جلسة');
      expect(Ar.outOf(2, 6, Ar.session), '2 من 6 جلسات');
    });
  });
}
