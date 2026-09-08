import 'package:flutter/material.dart';

/// اقتراحات الرياضات والمراجع الخارجية.
///
/// المستخدم حرّ في كتابة أي رياضة، والاقتراحات مجرد اختصار للأسماء الشائعة.
class SportVisuals {
  const SportVisuals._();

  /// الأيقونة المتجهة المناسبة للرياضة لسرعة التعرّف البصري عليها.
  static IconData iconFor(String sport) {
    final s = sport.trim().toLowerCase();
    if (s.contains('جر') || s.contains('ركض') || s.contains('عدو') || s.contains('run')) {
      return Icons.directions_run_rounded;
    }
    if (s.contains('مش') || s.contains('walk')) {
      return Icons.directions_walk_rounded;
    }
    if (s.contains('قدم') || s.contains('كورة') || s.contains('soccer') || s.contains('football')) {
      return Icons.sports_soccer_rounded;
    }
    if (s.contains('سل') || s.contains('basket')) {
      return Icons.sports_basketball_rounded;
    }
    if (s.contains('سباح') || s.contains('غوص') || s.contains('swim')) {
      return Icons.pool_rounded;
    }
    if (s.contains('بادل') || s.contains('تنس') || s.contains('مضرب') || s.contains('tennis') || s.contains('padel')) {
      return Icons.sports_tennis_rounded;
    }
    if (s.contains('طائر') || s.contains('volley')) {
      return Icons.sports_volleyball_rounded;
    }
    if (s.contains('دراج') || s.contains('سيكل') || s.contains('bike') || s.contains('cycl')) {
      return Icons.directions_bike_rounded;
    }
    if (s.contains('ثقال') || s.contains('حديد') || s.contains('جيم') || s.contains('كمال') || s.contains('فتنس') || s.contains('لياق') || s.contains('قوة') || s.contains('gym') || s.contains('fit')) {
      return Icons.fitness_center_rounded;
    }
    if (s.contains('ملاكم') || s.contains('بوكس') || s.contains('قتال') || s.contains('box') || s.contains('mma')) {
      return Icons.sports_mma_rounded;
    }
    if (s.contains('كارات') || s.contains('تايكوند') || s.contains('جودو') || s.contains('كونغ') || s.contains('دفاع')) {
      return Icons.sports_kabaddi_rounded;
    }
    if (s.contains('يوغ') || s.contains('بيلات') || s.contains('مرون') || s.contains('استرخ') || s.contains('yoga')) {
      return Icons.self_improvement_rounded;
    }
    if (s.contains('جمباز') || s.contains('كروس') || s.contains('كاليست') || s.contains('crossfit')) {
      return Icons.sports_gymnastics_rounded;
    }
    if (s.contains('تسلق') || s.contains('هايك') || s.contains('جبال') || s.contains('climb') || s.contains('hike')) {
      return Icons.hiking_rounded;
    }
    if (s.contains('سهم') || s.contains('رماي') || s.contains('قوس') || s.contains('archery')) {
      return Icons.track_changes_rounded;
    }
    if (s.contains('يد') && (s.contains('كر') || s.contains('handball'))) {
      return Icons.sports_handball_rounded;
    }
    if (s.contains('تزلج') || s.contains('جليد') || s.contains('ski')) {
      return Icons.downhill_skiing_rounded;
    }
    if (s.contains('تجديف') || s.contains('قارب') || s.contains('row')) {
      return Icons.rowing_rounded;
    }
    if (s.contains('بيسبول') || s.contains('baseball')) {
      return Icons.sports_baseball_rounded;
    }
    if (s.contains('رجبي') || s.contains('rugby')) {
      return Icons.sports_football_rounded;
    }
    if (s.contains('قوى') || s.contains('سرع') || s.contains('athletic')) {
      return Icons.speed_rounded;
    }
    return Icons.fitness_center_rounded;
  }


  /// الاقتراحات السريعة في شاشة اختيار الرياضة.
  static const List<String> suggestions = <String>[
    'كرة قدم',
    'كرة سلة',
    'سباحة',
    'جري',
    'بادل',
    'تنس',
    'رفع أثقال',
    'ملاكمة',
    'يوغا',
    'كرة طائرة',
    'دراجات',
    'كروس فت',
    'كاراتيه',
    'تنس طاولة',
    'قوس وسهم',
    'تسلق',
    'جمباز',
    'ألعاب قوى',
  ];

  /// الحرف الذي يمثّل الرياضة في شارتها.
  ///
  /// نأخذ أول حرف فعلي من الاسم — أي حرف، بأي لغة. التطبيق يَعِد بأن يقبل
  /// **أي** رياضة، ولا توجد مجموعة أيقونات أو رموز تعبيرية تغطي هذا الوعد؛
  /// أما الحرف فيعمل مع كل اسم يكتبه المستخدم.
  static String initialFor(String sport) {
    for (final rune in sport.trim().runes) {
      final char = String.fromCharCode(rune);
      // نتخطّى المسافات وعلامات الترقيم حتى نصل لأول حرف حقيقي.
      if (char.trim().isEmpty) continue;
      if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(char)) return char;
    }
    // اسم بلا حروف — نعرض علامة تبقي الشارة متّزنة بدل أن تفرغ.
    return '؟';
  }

  /// رابط بحث بالصور لتوضيح طريقة أداء التمرين (المرجع السريع).
  static Uri howToImagesUrl(String exercise, String sport) {
    final query = Uri.encodeComponent('$exercise $sport طريقة الأداء الصحيحة');
    return Uri.parse('https://www.google.com/search?tbm=isch&q=$query');
  }

  /// رابط فيديو يوضح الحركة.
  static Uri howToVideoUrl(String exercise, String sport) {
    final query = Uri.encodeComponent('$exercise $sport شرح التمرين');
    return Uri.parse('https://www.youtube.com/results?search_query=$query');
  }
}
