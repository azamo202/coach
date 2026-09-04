/// خطأ معروف يمكن عرضه للمستخدم برسالة عربية واضحة.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.canRetry = true});

  final String message;
  final String? code;
  final bool canRetry;

  static const AppException network = AppException(
    'ما قدرنا نوصل للخدمة. تأكد من اتصالك بالإنترنت وحاول مرة ثانية.',
    code: 'network',
  );

  static const AppException aiFailed = AppException(
    'ما قدرنا نجهّز البرنامج الآن. جرّب مرة ثانية بعد لحظات.',
    code: 'ai_failed',
  );

  static const AppException aiBadFormat = AppException(
    'وصلنا رد غير مكتمل من المدرب الذكي. جرّب مرة ثانية.',
    code: 'ai_bad_format',
  );

  static const AppException unauthorized = AppException(
    'انتهت جلستك. سجّل دخولك من جديد.',
    code: 'unauthorized',
    canRetry: false,
  );

  static const AppException missingApiKey = AppException(
    'إعدادات الذكاء الاصطناعي ناقصة. راجع ملف الإعداد قبل التشغيل.',
    code: 'missing_api_key',
    canRetry: false,
  );

  @override
  String toString() => message;
}
