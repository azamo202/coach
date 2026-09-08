/// إعدادات التطبيق المركزية.
///
/// جميع العمليات الذكية تمر حصراً عبر خادم الباك إند الآمن (Production Architecture)
/// لحماية مفاتيح الذكاء الاصطناعي وتطبيق قواعد التحقق وتتبع الاستهلاك.
///
/// يمكن تمرير عنوان السيرفر وقت البناء أو التشغيل:
/// flutter run --dart-define=API_BASE_URL=https://api.coachmint.app
class AppConfig {
  const AppConfig._();

  static const String appName = 'CoachMint';
  static const String appTagline = 'مدربك الرياضي بالذكاء الاصطناعي';
  static const String supportEmail = 'support@coachmint.app';
  static const String privacyPolicyUrl = 'https://coachmint.app/privacy';
  static const String termsUrl = 'https://coachmint.app/terms';

  /// عنوان الباك إند. الافتراضي للتطوير المحلي هو http://localhost:8080
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// مهلة الاتصال بالشبكة لعمليات التوليد والتحليل.
  static const Duration networkTimeout = Duration(seconds: 120);

  /// أقصى عدد رياضات محفوظة لكل مستخدم.
  static const int maxSavedSports = 12;
}
