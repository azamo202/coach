/// المقاييس الثابتة للتصميم: المسافات، الاستدارات، أحجام الأيقونات،
/// ومدّة الحركة.
///
/// كل قيمة في الواجهة تأتي من هنا. لا أرقام عشوائية داخل الشاشات — إذا احتجت
/// قيمة غير موجودة، فالغالب أن التصميم هو الذي يحتاج مراجعة، لا المقياس.
library;

/// سلّم المسافات — مضاعفات الأربعة.
///
/// | الرمز | القيمة | الاستخدام |
/// |-------|--------|-----------|
/// | `xxs` | 2  | فروق بصرية دقيقة داخل سطر واحد |
/// | `xs`  | 4  | بين أيقونة ونصّها |
/// | `sm`  | 8  | بين عناصر مرتبطة بشدة |
/// | `md`  | 12 | داخل البطاقات المدمجة |
/// | `lg`  | 16 | الحشو الافتراضي للبطاقات |
/// | `xl`  | 20 | الهامش الأفقي للشاشات |
/// | `xxl` | 24 | بين مجموعتين داخل قسم |
/// | `x3`  | 32 | بين قسمين |
/// | `x4`  | 40 | قبل خاتمة الشاشة |
/// | `x5`  | 48 | الفراغ حول الحالات الفارغة |
/// | `x6`  | 64 | الفراغ في الشاشات المتمركزة |
class Space {
  const Space._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double x3 = 32;
  static const double x4 = 40;
  static const double x5 = 48;
  static const double x6 = 64;

  /// الهامش الأفقي الموحّد لكل شاشة.
  static const double screenInset = xl;

  /// مساحة يتركها المحتوى أسفل الشاشات ذات شريط التنقّل العائم.
  static const double bottomBarClearance = 112;
}

/// سلّم الاستدارات.
///
/// أربع درجات فقط، ولكل واحدة دور واضح — الخلط بينها هو أسرع طريق لواجهة
/// تبدو غير مقصودة.
class Radii {
  const Radii._();

  /// الشارات والعناصر الصغيرة جداً.
  static const double xs = 8;

  /// الحقول الداخلية، مربعات القيم، أزرار الأيقونات.
  static const double sm = 12;

  /// الحقول والأزرار والبطاقات الداخلية.
  static const double md = 16;

  /// البطاقات الرئيسية وحوارات التأكيد.
  static const double lg = 20;

  /// الأوراق السفلية والأسطح الكبيرة.
  static const double xl = 28;

  /// الشرائح والحبوب — استدارة كاملة.
  static const double pill = 999;
}

/// أحجام الأيقونات. ثلاثة أحجام تغطي كل الواجهة.
class IconSizes {
  const IconSizes._();

  /// داخل الشرائح والشارات وبجانب النصوص الصغيرة.
  static const double sm = 16;

  /// الحجم الافتراضي — القوائم، الأزرار، شريط التنقّل.
  static const double md = 20;

  /// العناوين وأزرار الإجراءات الرئيسية.
  static const double lg = 24;

  /// أيقونة الحالة الفارغة أو الخطأ.
  static const double xl = 28;
}

/// أصغر مساحة لمس مقبولة (Apple HIG 44pt / Material 48dp).
class Touch {
  const Touch._();

  static const double min = 48;

  /// ارتفاع الأزرار الأساسية.
  static const double button = 52;

  /// ارتفاع الحقول.
  static const double field = 52;
}

/// مدد الحركة. ثلاث مدد فقط، تُختار حسب المسافة التي يقطعها العنصر.
class Motion {
  const Motion._();

  /// تغيّر حالة في مكانه: ضغط، تحديد، تلوين.
  static const Duration fast = Duration(milliseconds: 150);

  /// حركة قصيرة: فتح قسم، ظهور عنصر.
  static const Duration base = Duration(milliseconds: 220);

  /// انتقال بين الشاشات أو تمدّد كبير.
  static const Duration slow = Duration(milliseconds: 320);

  /// تعبئة أشرطة التقدّم — أبطأ عمداً حتى تُقرأ الزيادة.
  static const Duration progress = Duration(milliseconds: 560);
}
