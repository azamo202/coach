import 'package:flutter/material.dart';

/// ألوان هوية CoachMint البصرية.
///
/// كل قيمة هنا مأخوذة حرفياً من دليل الهوية. لا تُضاف ألوان خارج هذه اللوحة.
///
/// | اللون        | القيمة    | الاستخدام                        |
/// |--------------|-----------|----------------------------------|
/// | Spruce       | `#132420` | الخلفية الأساسية                  |
/// | Spruce Deep  | `#1B342D` | خلفية البطاقات والعناصر           |
/// | Mint         | `#8BFFCB` → `#16A97A` | لون العلامة الأساسي |
/// | Coral        | `#FF7A50` | لمسة طاقة — تُستخدم بحذر          |
/// | Off White    | `#F5F7F4` | النصوص على الخلفية الداكنة        |
/// | Sage         | `#8FA69B` | النصوص الثانوية                   |
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------------
  // ألوان الهوية الأساسية
  // ---------------------------------------------------------------------

  /// Spruce — الخلفية الأساسية للتطبيق.
  static const Color spruce = Color(0xFF132420);

  /// Spruce Deep — خلفية البطاقات والعناصر.
  static const Color spruceDeep = Color(0xFF1B342D);

  /// أعمق درجة — تُستخدم خلف الطبقات وشريط النظام.
  static const Color spruceBlack = Color(0xFF05100D);

  /// بداية تدرّج النعناع.
  static const Color mintLight = Color(0xFF8BFFCB);

  /// نعناع الهوية — اللون المميّز الأساسي.
  static const Color mint = Color(0xFF4FE3A6);

  /// نهاية تدرّج النعناع.
  static const Color mintDark = Color(0xFF16A97A);

  /// Coral — لمسة الطاقة. لا تستخدمه كلون واجهة عام.
  static const Color coral = Color(0xFFFF7A50);

  /// Off White — النصوص الأساسية.
  static const Color offWhite = Color(0xFFF5F7F4);

  /// Sage — النصوص الثانوية.
  static const Color sage = Color(0xFF8FA69B);

  /// Sage باهت — النصوص المساعدة.
  static const Color sageMuted = Color(0xFF6B7D76);

  // ---------------------------------------------------------------------
  // أسماء دلالية مشتقة من اللوحة أعلاه
  // ---------------------------------------------------------------------

  static const Color background = spruce;
  static const Color surface = spruceDeep;

  /// طبقات أعلى مشتقة من Spruce Deep بنفس درجة اللون.
  static const Color surfaceElevated = Color(0xFF204039);
  static const Color surfaceHigh = Color(0xFF2A4E45);

  static const Color border = Color(0xFF264A41);
  static const Color borderSoft = Color(0xFF1E3A33);

  // ---------------------------------------------------------------------
  // النصوص — ثلاث درجات فقط
  // ---------------------------------------------------------------------
  //
  // ثلاث درجات تكفي لأي تسلسل بصري. الدرجة الرابعة تُغري بترقيع الفوارق
  // بدل ترتيب المحتوى، ولذلك حُذفت.
  //
  // كل درجة تتجاوز 4.5:1 فوق كل أسطح التطبيق — من Spruce حتى Surface High —
  // وليس فوق الخلفية الأساسية وحدها.

  /// النص الأساسي: العناوين والقيم والمحتوى الذي يُقرأ فعلاً.
  static const Color textPrimary = offWhite;

  /// النص الثانوي: الفقرات الشارحة والوصف المطوّل.
  static const Color textSecondary = Color(0xFFC3D2CA);

  /// النص المساعد: التسميات، الوحدات، البيانات الوصفية.
  ///
  /// أفتح من Sage الخام عمداً — النص بلون Sage فوق Surface High يهبط تحت
  /// حدّ 4.5:1، وهو أكثر تركيبة يتكرّر فيها هذا النص.
  static const Color textTertiary = Color(0xFFAEBFB6);

  // ---------------------------------------------------------------------
  // طبقات وحالات
  // ---------------------------------------------------------------------

  /// حجاب خلف الحوارات والأوراق السفلية — يعزل ما تحته بصرياً.
  static const Color scrim = Color(0xCC05100D);

  /// حلقة التركيز للوحة المفاتيح والقارئ الصوتي.
  static const Color focus = mint;

  /// لون العناصر المعطّلة (نص وأيقونة).
  static const Color disabled = Color(0xFF5F7268);

  /// اللون المميّز الأساسي في الواجهة.
  static const Color primary = mint;
  static const Color primaryLight = mintLight;
  static const Color primaryDark = mintDark;

  /// النص فوق الأسطح النعناعية — دائماً Spruce وليس أبيض.
  static const Color onPrimary = spruce;

  // حالات
  static const Color success = mint;
  static const Color warning = coral;
  static const Color danger = Color(0xFFF2555A);
  static const Color info = Color(0xFF6FD9C9);

  // مستويات اللياقة — تدرّج طاقة من النعناع الفاتح إلى المرجاني
  static const Color levelBeginner = mintLight;
  static const Color levelIntermediate = mint;
  static const Color levelAdvanced = coral;

  /// تدرّج النعناع الرسمي للعلامة. الاتجاه ثابت ولا يُعكس.
  static const List<Color> mintGradient = <Color>[mintLight, mintDark];

  // ---------------------------------------------------------------------
  // اشتقاقات محسوبة على التباين
  // ---------------------------------------------------------------------

  /// يبني تدرّجاً من أي لون هوية للاستخدام خلف نصّ Spruce.
  ///
  /// كان الاشتقاق سابقاً يغمّق اللون نحو Spruce، فيهبط تباين نص الزرّ فوق
  /// اللون المرجاني إلى 3.3:1. الآن يقع التفتيح على الطرف العلوي ويبقى
  /// الطرف السفلي هو اللون نفسه، فلا ينزل أي جزء من الزرّ تحت 4.5:1.
  static List<Color> accentGradient(Color base) =>
      <Color>[Color.lerp(base, offWhite, 0.28)!, base];

  /// يفتّح لون هوية ليصلح **نصّاً صغيراً** فوق أسطح المحتوى.
  ///
  /// القاعدة في الوضع الداكن: اللون كسطح يبقى كما هو، واللون كنصّ يُفتَّح.
  /// المرجاني الخام يعطي 4.4:1 فوق Surface Elevated — أقل من الحد بقليل،
  /// والتفتيح يرفعه فوق 4.5:1 دون أن يغيّر الإحساس باللون.
  ///
  /// الضمان يشمل [background] و[surface] و[surfaceElevated]. لا يشمل
  /// [surfaceHigh] لأنه ليس سطح محتوى: مسار شريط التقدّم وخلفية الرسالة
  /// السريعة، ولا يقع فوقه نصّ ملوّن أصلاً.
  static Color asText(Color base) => Color.lerp(base, offWhite, 0.32)!;
}

/// تدرّجات تمييز الرياضات المحفوظة.
///
/// كلها من عائلة النعناع نفسها — تختلف بدرجة بسيطة في درجة اللون فقط، حتى
/// تبقى الواجهة ضمن الهوية ولا تتحول إلى ألوان قوس قزح. اللون المرجاني
/// محجوز للطاقة (السلسلة اليومية، مستوى المحترف) ولا يدخل هنا.
class AccentPalette {
  const AccentPalette._();

  /// نعناع الهوية — التدرّج الافتراضي.
  static const List<Color> mint = AppColors.mintGradient;

  /// نعناع مائل للتركوازي.
  static const List<Color> teal = <Color>[
    Color(0xFF7DF3D5),
    Color(0xFF109B8E),
  ];

  /// نعناع مائل للأخضر.
  static const List<Color> spring = <Color>[
    Color(0xFFA5FFC4),
    Color(0xFF23A667),
  ];

  /// أكوا.
  static const List<Color> aqua = <Color>[
    Color(0xFF7FEFE4),
    Color(0xFF0F8F8C),
  ];

  static const List<List<Color>> gradients = <List<Color>>[
    mint,
    teal,
    spring,
    aqua,
  ];

  static List<Color> byIndex(int index) =>
      gradients[index.abs() % gradients.length];

  /// اختيار تدرّج ثابت لكل اسم رياضة (نفس الاسم = نفس التدرّج دائماً).
  static List<Color> byName(String name) {
    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return byIndex(hash);
  }
}
