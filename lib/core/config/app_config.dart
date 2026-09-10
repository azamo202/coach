/// إعدادات التطبيق المركزية.
///
/// جميع العمليات الذكية تمر حصراً عبر خادم الباك إند الآمن (Production Architecture)
/// لحماية مفاتيح الذكاء الاصطناعي وتطبيق قواعد التحقق وتتبع الاستهلاك.
///
/// يمكن تمرير عنوان السيرفر وقت البناء أو التشغيل:
/// flutter run --dart-define=API_BASE_URL=https://api.coachmin.tech
class AppConfig {
  const AppConfig._();

  static const String appName = 'CoachMint';
  static const String appTagline = 'مدربك الرياضي بالذكاء الاصطناعي';
  static const String supportEmail = 'coachmint1@gmail.com';
  static const String privacyPolicyUrl = 'https://coachmin.tech/privacy';
  static const String termsUrl = 'https://coachmin.tech/terms';

  /// عنوان الباك إند.
  ///
  /// الافتراضي هو **الإنتاج** عمداً، لا التطوير المحلي. نسيان
  /// `--dart-define` وقت بناء نسخة للمتجر كان يعني شحن تطبيق يخاطب
  /// `localhost` — أي تطبيق ميت في يد كل مستخدم، وعطل لا يظهر في أي
  /// اختبار محلي لأن الخادم يعمل على جهاز المطوّر.
  ///
  /// للتطوير المحلي مرّر العنوان صراحةً:
  /// `flutter run --dart-define=API_BASE_URL=http://localhost:8080`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.coachmin.tech',
  );

  /// هل العنوان صالح لنسخة إنتاج؟
  ///
  /// شرطان: HTTPS (نظام ATS في iOS يحجب HTTP الصريح أصلاً)، وألا يشير
  /// إلى جهاز محلي.
  static bool get isProductionApi {
    final url = apiBaseUrl.toLowerCase();
    if (!url.startsWith('https://')) return false;
    const localHosts = <String>['localhost', '127.0.0.1', '10.0.2.2', '0.0.0.0'];
    return !localHosts.any(url.contains);
  }

  /// مهلة الاتصال بالشبكة لعمليات التوليد والتحليل.
  static const Duration networkTimeout = Duration(seconds: 120);

  /// أقصى عدد رياضات محفوظة لكل مستخدم.
  static const int maxSavedSports = 12;

  // -------------------------------------------------------------------
  // الاشتراكات — Apple In-App Purchase
  // -------------------------------------------------------------------
  //
  // هذه المعرّفات يجب أن تطابق حرفياً ما في App Store Connect وما في
  // متغيّرات بيئة الخادم (APPLE_PRODUCT_*). أي اختلاف يعني منتجاً لا
  // يظهر في التطبيق، أو اشتراكاً لا يمنح صلاحية.

  static const String productSingleMonthly = String.fromEnvironment(
    'IAP_SINGLE_MONTHLY',
    defaultValue: 'com.coachmint.single.monthly',
  );

  static const String productTrioMonthly = String.fromEnvironment(
    'IAP_TRIO_MONTHLY',
    defaultValue: 'com.coachmint.trio.monthly',
  );

  static const String productUnlimitedYearly = String.fromEnvironment(
    'IAP_UNLIMITED_YEARLY',
    defaultValue: 'com.coachmint.unlimited.yearly',
  );

  /// كل معرّفات المنتجات — تُطلب من StoreKit دفعة واحدة.
  static const Set<String> subscriptionProductIds = <String>{
    productSingleMonthly,
    productTrioMonthly,
    productUnlimitedYearly,
  };

  /// صفحة إدارة الاشتراكات في App Store.
  ///
  /// Apple تشترط أن يصل المستخدم لإلغاء اشتراكه من داخل التطبيق، وهذا
  /// هو الرابط الرسمي الذي يفتح الشاشة الصحيحة.
  static const String manageSubscriptionsUrl =
      'https://apps.apple.com/account/subscriptions';
}
