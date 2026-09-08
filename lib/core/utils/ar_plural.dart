/// صياغة العدد بالعربية.
///
/// العربية لا تعرف «مفرد وجمع» فقط: لها مفرد ومثنّى وجمع قلّة (٣–١٠) وجمع
/// كثرة (١١ فأكثر) ينصب تمييزه. كانت كل شاشة تكتب قاعدتها بنفسها — ستّ نسخ
/// متفرّقة اختلفت في المثنّى وفي الحد الأعلى — فظهرت «٢ جلسة» في شاشة
/// و«جلستان» في أخرى للعدد نفسه.
///
/// القاعدة هنا واحدة، والأرقام تبقى لاتينية كما في بقية التطبيق:
///
/// | العدد | الصيغة        |
/// |-------|---------------|
/// | 0     | لا جلسات      |
/// | 1     | جلسة واحدة    |
/// | 2     | جلستان        |
/// | 3–10  | 5 جلسات       |
/// | 11+   | 12 جلسة       |
library;

/// صيغ الاسم الأربع التي تحتاجها العربية للعدّ.
class ArNoun {
  const ArNoun({
    required this.none,
    required this.one,
    required this.two,
    required this.few,
    required this.many,
  });

  /// «لا جلسات» — تُستخدم عند الصفر.
  final String none;

  /// «جلسة واحدة».
  final String one;

  /// «جلستان».
  final String two;

  /// جمع القلّة الذي يلي العدد ٣–١٠: «جلسات».
  final String few;

  /// تمييز جمع الكثرة المنصوب بعد ١١: «جلسة».
  final String many;

  /// النصّ الكامل مع عدده: «5 جلسات».
  String call(int count) {
    if (count <= 0) return none;
    if (count == 1) return one;
    if (count == 2) return two;
    if (count <= 10) return '$count $few';
    return '$count $many';
  }

  /// الاسم وحده بلا عدد — للتسميات تحت رقم كبير في بطاقة إحصائية.
  ///
  /// المفرد والمثنّى يشتركان في الاسم المجرّد، فالبطاقة تعرض الرقم فوقه.
  String unit(int count) {
    if (count >= 3 && count <= 10) return few;
    return many;
  }
}

/// أسماء التطبيق المعدودة. لا تُكتب صيغة عدد خارج هذه القائمة.
class Ar {
  const Ar._();

  static const ArNoun session = ArNoun(
    none: 'لا جلسات',
    one: 'جلسة واحدة',
    two: 'جلستان',
    few: 'جلسات',
    many: 'جلسة',
  );

  static const ArNoun week = ArNoun(
    none: 'بلا أسابيع',
    one: 'أسبوع واحد',
    two: 'أسبوعان',
    few: 'أسابيع',
    many: 'أسبوعاً',
  );

  static const ArNoun exercise = ArNoun(
    none: 'بلا تمارين',
    one: 'تمرين واحد',
    two: 'تمرينان',
    few: 'تمارين',
    many: 'تمريناً',
  );

  static const ArNoun sport = ArNoun(
    none: 'لا رياضات',
    one: 'رياضة واحدة',
    two: 'رياضتان',
    few: 'رياضات',
    many: 'رياضة',
  );

  static const ArNoun day = ArNoun(
    none: 'لا أيام',
    one: 'يوم واحد',
    two: 'يومان',
    few: 'أيام',
    many: 'يوماً',
  );

  static const ArNoun set = ArNoun(
    none: 'بلا مجموعات',
    one: 'مجموعة واحدة',
    two: 'مجموعتان',
    few: 'مجموعات',
    many: 'مجموعة',
  );

  static const ArNoun minute = ArNoun(
    none: 'بلا وقت',
    one: 'دقيقة واحدة',
    two: 'دقيقتان',
    few: 'دقائق',
    many: 'دقيقة',
  );

  /// «6 من 18 جلسة» — الصيغة المتكرّرة في بطاقات التقدّم.
  ///
  /// التمييز يتبع **الإجمالي** لا المنجز، لأنه هو المعدود في الجملة.
  static String outOf(int done, int total, ArNoun noun) =>
      '$done من $total ${noun.unit(total)}';
}
