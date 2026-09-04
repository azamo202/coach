import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// سلّم الخطوط.
///
/// خطّان فقط:
/// - **IBM Plex Sans Arabic** لكل النصوص العربية — احترافي، هادئ، وفائق الأناقة والوضوح.
/// - **Plus Jakarta Sans** للأرقام والأسماء اللاتينية فقط (النِّسب، العدّادات،
///   اسم العلامة). أرقامه جدولية العرض فلا يقفز التخطيط عند تغيّر القيمة.
///
/// العربية تحتاج ارتفاع سطر أعلى من اللاتينية حتى لا تتلامس الحركات
/// والنقاط — لذلك ارتفاعات الأسطر هنا أسخى من المعتاد.
///
/// **أقصى وزن مسموح هو `w700`.** الوزن الأثقل من ذلك يجعل كل شيء يصرخ،
/// فيختفي التسلسل البصري تماماً.
class AppType {
  const AppType._();

  // ---------------------------------------------------------------------
  // أوزان الخط — الأسماء بدل الأرقام حتى تبقى النية واضحة
  // ---------------------------------------------------------------------

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static TextStyle _ar({
    required double size,
    required double lineHeight,
    FontWeight weight = regular,
    Color color = AppColors.textPrimary,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  // ---------------------------------------------------------------------
  // العناوين
  // ---------------------------------------------------------------------

  /// شاشة الإقلاع والحالات المتمركزة الكبيرة فقط.
  static TextStyle get display =>
      _ar(size: 30, lineHeight: 40, weight: bold, letterSpacing: -0.4);

  /// عنوان الشاشة — واحد فقط في كل شاشة.
  static TextStyle get h1 =>
      _ar(size: 24, lineHeight: 34, weight: bold, letterSpacing: -0.3);

  /// عنوان بطاقة رئيسية أو قسم بارز.
  static TextStyle get h2 =>
      _ar(size: 20, lineHeight: 29, weight: bold, letterSpacing: -0.2);

  /// عنوان قسم داخل الشاشة.
  static TextStyle get h3 => _ar(size: 17, lineHeight: 25, weight: bold);

  /// عنوان صفّ في قائمة أو بطاقة صغيرة.
  static TextStyle get h4 => _ar(size: 15, lineHeight: 22, weight: semiBold);

  // ---------------------------------------------------------------------
  // النصوص
  // ---------------------------------------------------------------------

  /// فقرة تُقرأ بتأنٍّ — شرح طريقة الأداء، نصّ الإعداد.
  static TextStyle get bodyLg => _ar(size: 16, lineHeight: 28);

  /// النص الافتراضي في التطبيق.
  static TextStyle get body => _ar(size: 14, lineHeight: 25);

  /// نص مساعد أو ثانوي.
  static TextStyle get bodySm => _ar(
        size: 13,
        lineHeight: 22,
        color: AppColors.textTertiary,
      );

  /// نصّ وصفي قصير تحت عنوان أو رقم.
  static TextStyle get caption => _ar(
        size: 12,
        lineHeight: 18,
        weight: medium,
        color: AppColors.textTertiary,
      );

  /// عنوان حقل، اسم شريحة، نص زر.
  static TextStyle get label => _ar(size: 13, lineHeight: 18, weight: semiBold);

  /// نصّ الأزرار — أكبر قليلاً من [label] لأنه هدف لمس لا وصف.
  static TextStyle get button =>
      _ar(size: 15, lineHeight: 20, weight: semiBold);

  /// عنوان قسم صغير فوق مجموعة — يُستخدم مع تباعد حروف موجب.
  static TextStyle get overline => _ar(
        size: 11,
        lineHeight: 16,
        weight: semiBold,
        color: AppColors.textTertiary,
        letterSpacing: 0.6,
      );

  // ---------------------------------------------------------------------
  // الأرقام — لاتينية دائماً، بعرض جدولي ثابت
  // ---------------------------------------------------------------------

  /// رقم بحجم قابل للتحكّم. يُستخدم للنِّسب والعدّادات والإحصاءات.
  ///
  /// `tabular figures` تمنع اهتزاز التخطيط حين تتغيّر القيمة من ٩ إلى ١٠.
  static TextStyle number({
    double size = 22,
    FontWeight weight = bold,
    Color color = AppColors.textPrimary,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.15,
        letterSpacing: -0.5,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );

  /// اسم العلامة «CoachMint» — لاتيني دائماً.
  static TextStyle brand({
    double size = 28,
    Color color = AppColors.textPrimary,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: bold,
        color: color,
        height: 1.1,
        letterSpacing: -0.6,
      );

  /// يبني `TextTheme` كامل من السلّم أعلاه ليصل لكل عناصر Material.
  static TextTheme get textTheme => TextTheme(
        displayLarge: display,
        displayMedium: display,
        displaySmall: h1,
        headlineLarge: h1,
        headlineMedium: h1,
        headlineSmall: h2,
        titleLarge: h2,
        titleMedium: h3,
        titleSmall: h4,
        bodyLarge: bodyLg,
        bodyMedium: body,
        bodySmall: bodySm,
        labelLarge: label,
        labelMedium: label,
        labelSmall: caption,
      );
}
