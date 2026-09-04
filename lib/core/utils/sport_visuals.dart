/// اقتراحات الرياضات والمراجع الخارجية.
///
/// المستخدم حرّ في كتابة أي رياضة، والاقتراحات مجرد اختصار للأسماء الشائعة.
class SportVisuals {
  const SportVisuals._();

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
