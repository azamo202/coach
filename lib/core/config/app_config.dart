/// إعدادات التطبيق المركزية.
///
/// يمكن تمرير القيم وقت البناء دون تعديل الكود:
/// flutter run --dart-define=API_BASE_URL=https://api.coachmint.app
class AppConfig {
  const AppConfig._();

  static const String appName = 'CoachMint';
  static const String appTagline = 'مدربك الرياضي بالذكاء الاصطناعي';
  static const String supportEmail = 'support@coachmint.app';
  static const String privacyPolicyUrl = 'https://coachmint.app/privacy';
  static const String termsUrl = 'https://coachmint.app/terms';

  /// عنوان الباك إند. اتركه فارغاً لتشغيل التطبيق بوضع محلي بالكامل
  /// (حسابات وبرامج مخزنة على الجهاز) — مفيد للتجربة والعرض.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// عند true يعمل التطبيق بالكامل على الجهاز بدون سيرفر.
  static bool get isOfflineMode => apiBaseUrl.trim().isEmpty;

  /// مفتاح Anthropic — للتطوير المحلي فقط.
  /// في الإنتاج يجب أن يمر التوليد عبر الباك إند حتى لا يُشحن المفتاح مع التطبيق.
  static const String anthropicApiKeyDev = String.fromEnvironment(
    'ANTHROPIC_API_KEY',
    defaultValue: '',
  );

  static const String anthropicModel = 'claude-sonnet-4-6';
  static const String anthropicVersion = '2023-06-01';
  static const int anthropicMaxTokens = 8000;

  static const Duration networkTimeout = Duration(seconds: 90);

  /// أقصى عدد رياضات محفوظة لكل مستخدم.
  static const int maxSavedSports = 12;
}
