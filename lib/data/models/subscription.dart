import '../../core/config/app_config.dart';

/// عدد غير محدود من البرامج.
const int kUnlimitedSlots = -1;

/// خطط الاشتراك الثلاث زائد الخطة المجانية.
///
/// الترتيب هنا هو ترتيب العرض في صفحة الاشتراك، ومقياس «الأعلى» عند
/// تداخل اشتراكين. يجب أن يطابق `rank` ما في `backend/src/lib/plans.js`.
enum SubscriptionPlan {
  /// حالة «بلا اشتراك» — ليست خطة يُنتفع بها.
  ///
  /// التطبيق مقفول بالكامل خلف الاشتراك: لا توليد ولا استشارة قبل الشراء.
  free(
    id: 'free',
    productId: null,
    rank: 0,
    title: 'بلا اشتراك',
    tagline: 'الاشتراك مطلوب لبناء برامجك التدريبية',
    programSlots: 0,
    coachAdvice: false,
    priceHint: '—',
    periodLabel: '',
  ),
  singleMonthly(
    id: 'single_monthly',
    productId: AppConfig.productSingleMonthly,
    rank: 1,
    title: 'برنامج واحد',
    tagline: 'برنامج تدريبي نشط واحد، بدّله وقت ما تبي',
    programSlots: 1,
    coachAdvice: true,
    priceHint: r'$10',
    periodLabel: 'شهرياً',
  ),
  trioMonthly(
    id: 'trio_monthly',
    productId: AppConfig.productTrioMonthly,
    rank: 2,
    title: 'ثلاثة برامج',
    tagline: 'ثلاث رياضات بالتوازي في نفس الوقت',
    programSlots: 3,
    coachAdvice: true,
    priceHint: r'$20',
    periodLabel: 'شهرياً',
  ),
  unlimitedYearly(
    id: 'unlimited_yearly',
    productId: AppConfig.productUnlimitedYearly,
    rank: 3,
    title: 'برامج بلا حدود',
    tagline: 'كل الرياضات، سنة كاملة',
    programSlots: kUnlimitedSlots,
    coachAdvice: true,
    priceHint: r'$100',
    periodLabel: 'سنوياً',
  );

  const SubscriptionPlan({
    required this.id,
    required this.productId,
    required this.rank,
    required this.title,
    required this.tagline,
    required this.programSlots,
    required this.coachAdvice,
    required this.priceHint,
    required this.periodLabel,
  });

  final String id;

  /// معرّف المنتج في App Store. فارغ للخطة المجانية.
  final String? productId;

  final int rank;
  final String title;
  final String tagline;
  final int programSlots;
  final bool coachAdvice;

  /// سعر تقريبي للعرض قبل وصول سعر StoreKit الحقيقي بعملة المستخدم.
  ///
  /// السعر المعروض للمستخدم يجب أن يكون دائماً سعر StoreKit — هذا احتياط
  /// بصري لا أكثر، ولا يُعرض حين يتوفّر السعر الحقيقي.
  final String priceHint;

  final String periodLabel;

  bool get isFree => this == SubscriptionPlan.free;

  bool get isUnlimited => programSlots == kUnlimitedSlots;

  /// وصف الحصة بصيغة عربية سليمة العدد.
  String get slotsLabel {
    if (isUnlimited) return 'برامج بلا حدود';
    if (programSlots == 0) return 'لا برامج';
    if (programSlots == 1) return 'برنامج واحد';
    if (programSlots == 2) return 'برنامجان';
    return '$programSlots برامج';
  }

  static SubscriptionPlan fromId(String? id) {
    for (final plan in SubscriptionPlan.values) {
      if (plan.id == id) return plan;
    }
    return SubscriptionPlan.free;
  }

  static SubscriptionPlan? fromProductId(String? productId) {
    if (productId == null) return null;
    for (final plan in SubscriptionPlan.values) {
      if (plan.productId == productId) return plan;
    }
    return null;
  }

  /// الخطط المدفوعة بترتيب العرض.
  static List<SubscriptionPlan> get paid => <SubscriptionPlan>[
        SubscriptionPlan.singleMonthly,
        SubscriptionPlan.trioMonthly,
        SubscriptionPlan.unlimitedYearly,
      ];
}

/// صلاحية المستخدم كما يقرّرها الخادم.
///
/// هذا الكائن هو النسخة الوحيدة المعتمدة من «ماذا يستطيع المستخدم الآن».
/// التطبيق لا يحسب الصلاحية بنفسه أبداً — يقرأها فقط ويعرضها.
class Entitlement {
  const Entitlement({
    this.plan = SubscriptionPlan.free,
    this.isSubscribed = false,
    this.activePrograms = 0,
    this.remainingSlots,
    this.canCreateProgram = true,
    this.coachAdvice = false,
    this.freeGenerationsUsed = 0,
    this.freeGenerationsLimit,
    this.expiresAt,
    this.autoRenew = false,
    this.inGracePeriod = false,
    this.isTrial = false,
    this.billingIssue = false,
  });

  /// الحالة المفترضة قبل وصول أي رد من الخادم.
  ///
  /// نبدأ **متحفّظين**: لا اشتراك، ولا توليد. صفحة الاشتراك خير من فتح
  /// باب مدفوع بالخطأ ثم إغلاقه في وجه المستخدم بعد أن يبدأ.
  static const Entitlement unknown = Entitlement(canCreateProgram: false);

  final SubscriptionPlan plan;
  final bool isSubscribed;

  /// عدد البرامج التي تشغل حصصاً الآن.
  final int activePrograms;

  /// الحصص المتبقية، أو `null` في الخطة المفتوحة.
  final int? remainingSlots;

  final bool canCreateProgram;
  final bool coachAdvice;

  final int freeGenerationsUsed;
  final int? freeGenerationsLimit;

  final DateTime? expiresAt;
  final bool autoRenew;

  /// الدفع تعثّر ولكن Apple منحت مهلة — الصلاحية مفتوحة والتحذير واجب.
  final bool inGracePeriod;

  final bool isTrial;

  /// الدفع فشل والاشتراك في إعادة المحاولة — الصلاحية مغلقة.
  final bool billingIssue;

  bool get isUnlimited => plan.isUnlimited;

  /// هل يمنح الخادم أي تجربة مجانية أصلاً؟
  ///
  /// يُقرأ من ردّ الخادم لا من ثابت في التطبيق: فتح تجربة مجانية لاحقاً
  /// يجب أن يسري بتغيير الخادم وحده، دون إصدار جديد على App Store.
  bool get hasFreeTier => (freeGenerationsLimit ?? 0) > 0;

  /// هل استُهلكت التجربة المجانية بالكامل؟ (حين توجد تجربة أصلاً)
  bool get freeTrialUsedUp =>
      !isSubscribed &&
      hasFreeTier &&
      freeGenerationsUsed >= freeGenerationsLimit!;

  /// سبب منع التوليد بصيغة يفهمها المستخدم، أو `null` إن كان مسموحاً.
  ///
  /// الرسالتان تقودان إلى إجراءين مختلفين — «اشترك» أو «احذف برنامجاً» —
  /// فخلطهما يترك المستخدم أمام زرّ لا يحلّ مشكلته.
  String? get blockReason {
    if (canCreateProgram) return null;
    if (!isSubscribed) {
      if (freeTrialUsedUp) {
        return 'استهلكت برنامجك المجاني. اشترك لتولّد برامج جديدة.';
      }
      return 'الاشتراك مطلوب لبناء برنامجك التدريبي. اختر باقتك لتبدأ.';
    }
    return 'خطتك الحالية تسمح بـ${plan.slotsLabel}. احذف برنامجاً أو رقّي '
        'اشتراكك لتضيف غيره.';
  }

  factory Entitlement.fromJson(Map<String, dynamic> json) {
    return Entitlement(
      plan: SubscriptionPlan.fromId(json['planId'] as String?),
      isSubscribed: json['isSubscribed'] == true,
      activePrograms: _asInt(json['activePrograms']) ?? 0,
      remainingSlots: _asInt(json['remainingSlots']),
      canCreateProgram: json['canCreateProgram'] == true,
      coachAdvice: json['coachAdvice'] == true,
      freeGenerationsUsed: _asInt(json['freeGenerationsUsed']) ?? 0,
      freeGenerationsLimit: _asInt(json['freeGenerationsLimit']),
      expiresAt: DateTime.tryParse((json['expiresAt'] ?? '').toString()),
      autoRenew: json['autoRenew'] == true,
      inGracePeriod: json['inGracePeriod'] == true,
      isTrial: json['isTrial'] == true,
      billingIssue: json['billingIssue'] == true,
    );
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
