import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/subscription.dart';
import '../../state/subscription_controller.dart';
import 'widgets/plan_card.dart';

/// صفحة الاشتراك.
///
/// بُنيت حول ثلاثة قيود لا تُساوَم:
///
/// 1. **ما يشتريه المستخدم مكتوب قبل أن يضغط.** الاسم والسعر والمدة
///    وما يفتحه الاشتراك — كلها ظاهرة في البطاقة نفسها، لا خلف رابط.
///    وشريط الدفع السفلي يكرّر السعر والمدة عند لحظة القرار.
/// 2. **شروط App Store مستوفاة.** التجديد التلقائي معلن، وزرّ استعادة
///    المشتريات موجود، وروابط الشروط والخصوصية تعمل. غياب أي منها سبب
///    رفض معروف في مراجعة Apple (إرشاد 3.1.2).
/// 3. **الحالة الحالية ليست مخفية.** المشترك يرى خطته وتاريخ تجديدها،
///    ومن عنده مشكلة دفع يرى ذلك أولاً — لا أن يُعرض عليه الشراء مجدداً.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.reason});

  /// سبب وصول المستخدم إلى هنا — يُعرض أعلى الصفحة حين يأتي من بوابة.
  final String? reason;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  /// الخطة المحدَّدة ابتداءً: الأوسع قيمة مقابل السعر.
  SubscriptionPlan _selected = SubscriptionPlan.trioMonthly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<SubscriptionController>();
      controller.clearMessages();
      controller.loadProducts();
      controller.refresh();
    });
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (error) {
      debugPrint('Failed to open $url: $error');
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('ما قدرنا نفتح الرابط.')));
  }

  Future<void> _subscribe() async {
    HapticFeedback.mediumImpact();
    await context.read<SubscriptionController>().purchase(_selected);
  }

  Future<void> _restore() async {
    await context.read<SubscriptionController>().restore();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SubscriptionController>();
    final entitlement = controller.entitlement;

    // الرسائل تُعرض مرة واحدة ثم تُمسح، فلا تلاحق المستخدم بين الشاشات.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notice = controller.notice;
      if (notice == null || !mounted) return;
      showAppSnack(context, notice);
      controller.clearMessages();
    });

    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Space.contentWidth),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: Space.xxl),
                      children: <Widget>[
                        const ScreenHeader(
                          showBack: true,
                          title: 'اشترك في CoachMint',
                          subtitle: 'برامج تدريبية يبنيها المدرّب الذكي '
                              'على مستواك وهدفك',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.screenInset,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (widget.reason != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: Space.lg),
                                  child: AppNotice(
                                    message: widget.reason!,
                                    tone: NoticeTone.neutral,
                                    icon: Icons.lock_outline_rounded,
                                  ),
                                ),

                              if (entitlement.billingIssue)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: Space.lg),
                                  child: AppNotice(
                                    title: 'فيه مشكلة في الدفع',
                                    message: 'ما قدرت Apple تجدّد اشتراكك. '
                                        'حدّث طريقة الدفع في إعدادات حساب '
                                        'Apple ليرجع اشتراكك تلقائياً.',
                                    tone: NoticeTone.warning,
                                  ),
                                ),

                              if (entitlement.isSubscribed)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: Space.lg),
                                  child: _CurrentPlanCard(
                                    entitlement: entitlement,
                                  ),
                                ),

                              if (controller.error != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: Space.lg),
                                  child: AppNotice(
                                    message: controller.error!,
                                    onDismiss: controller.clearMessages,
                                  ),
                                ),

                              const _Benefits(),
                              const SizedBox(height: Space.xxl),

                              SectionHeader(
                                title: entitlement.isSubscribed
                                    ? 'غيّر خطتك'
                                    : 'اختر خطتك',
                                subtitle: controller.isLoadingProducts
                                    ? 'نجيب الأسعار من App Store…'
                                    : null,
                              ),

                              if (controller.productsError != null)
                                AppNotice(
                                  message: controller.productsError!,
                                  onRetry: () => controller.loadProducts(
                                    force: true,
                                  ),
                                )
                              else
                                ...SubscriptionPlan.paid.map(
                                  (plan) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: Space.md,
                                    ),
                                    child: PlanCard(
                                      plan: plan,
                                      price: controller.priceLabel(plan),
                                      priceReady:
                                          controller.productFor(plan) != null,
                                      selected: _selected == plan,
                                      isCurrent:
                                          entitlement.isSubscribed &&
                                              entitlement.plan == plan,
                                      highlight:
                                          plan == SubscriptionPlan.unlimitedYearly,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _selected = plan);
                                      },
                                    ),
                                  ),
                                ),

                              const SizedBox(height: Space.lg),
                              _LegalBlock(onOpen: _open, onRestore: _restore),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PurchaseBar(
                    plan: _selected,
                    price: controller.priceLabel(_selected),
                    stage: controller.stage,
                    enabled: controller.productFor(_selected) != null &&
                        !controller.isBusy,
                    isCurrent: entitlement.isSubscribed &&
                        entitlement.plan == _selected,
                    onPressed: _subscribe,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة الخطة الحالية للمشترك.
class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.entitlement});

  final Entitlement entitlement;

  String get _renewalLine {
    final expires = entitlement.expiresAt;
    if (expires == null) return 'اشتراك فعّال';
    final date = DateFormat('yyyy/MM/dd').format(expires);
    if (entitlement.inGracePeriod) return 'في مهلة سماح حتى $date';
    return entitlement.autoRenew ? 'يتجدّد في $date' : 'ينتهي في $date';
  }

  @override
  Widget build(BuildContext context) {
    final slots = entitlement.isUnlimited
        ? 'برامج بلا حدود'
        : '${entitlement.activePrograms} من ${entitlement.plan.programSlots} '
            'برامج مستخدمة';

    return AppCard(
      borderColor: AppColors.mint.withValues(alpha: 0.35),
      child: Row(
        children: <Widget>[
          Container(
            width: IconSizes.tile,
            height: IconSizes.tile,
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: const Icon(
              Icons.verified_rounded,
              size: IconSizes.md,
              color: AppColors.mint,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'خطتك: ${entitlement.plan.title}',
                  style: AppType.h4,
                ),
                const SizedBox(height: Space.xxs),
                Text('$_renewalLine · $slots', style: AppType.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ما يفتحه الاشتراك — بلغة الفائدة لا بلغة الميزة.
class _Benefits extends StatelessWidget {
  const _Benefits();

  static const List<(IconData, String, String)> _items = <(IconData, String, String)>[
    (
      Icons.auto_awesome_rounded,
      'برنامج مبني لك أنت',
      'يبنيه الذكاء الاصطناعي على رياضتك ومستواك وهدفك وأدواتك المتاحة',
    ),
    (
      Icons.psychology_alt_rounded,
      'مدرّب يجاوب على أسئلتك',
      'اسأل عن أي تمرين أو ألم أو بديل، وخذ جواباً عملياً في ثوانٍ',
    ),
    (
      Icons.trending_up_rounded,
      'تدرّج أسبوعي محسوب',
      'الحمل يزيد بالتدريج مع تتبّع جلساتك وسلسلة أيامك',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < _items.length; i++)
          RevealIn(
            step: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    _items[i].$1,
                    size: IconSizes.md,
                    color: AppColors.mint,
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(_items[i].$2, style: AppType.h4),
                        const SizedBox(height: Space.xxs),
                        Text(_items[i].$3, style: AppType.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// الإفصاح القانوني وزرّ الاستعادة.
///
/// وجود هذه الكتلة شرط لقبول التطبيق في App Store، ومضمونها هو ما يجعل
/// المستخدم يعرف أنه يشترك في خدمة متجدّدة لا في شراء لمرة واحدة.
class _LegalBlock extends StatelessWidget {
  const _LegalBlock({required this.onOpen, required this.onRestore});

  final Future<void> Function(String url) onOpen;
  final Future<void> Function() onRestore;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SubscriptionController>();

    return Column(
      children: <Widget>[
        AppButton.ghost(
          label: 'استعادة المشتريات',
          icon: Icons.restore_rounded,
          expand: true,
          isLoading: controller.stage == PurchaseStage.restoring,
          onPressed: controller.isBusy ? null : onRestore,
        ),
        const SizedBox(height: Space.md),
        Text(
          'الاشتراك يتجدّد تلقائياً بنفس المدة والسعر ما لم تُلغه قبل 24 ساعة '
          'على الأقل من نهاية الفترة الحالية. تُخصم الرسوم من حساب Apple عند '
          'التأكيد، وتقدر تدير اشتراكك أو تلغيه من إعدادات حسابك في App Store.',
          textAlign: TextAlign.center,
          style: AppType.caption,
        ),
        const SizedBox(height: Space.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Space.lg,
          runSpacing: Space.xs,
          children: <Widget>[
            _LegalLink(
              label: 'شروط الاستخدام',
              onTap: () => onOpen(AppConfig.termsUrl),
            ),
            _LegalLink(
              label: 'سياسة الخصوصية',
              onTap: () => onOpen(AppConfig.privacyPolicyUrl),
            ),
            _LegalLink(
              label: 'إدارة الاشتراك',
              onTap: () => onOpen(AppConfig.manageSubscriptionsUrl),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Space.xs,
            horizontal: Space.xxs,
          ),
          child: Text(
            label,
            style: AppType.caption.copyWith(
              color: AppColors.mint,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.mint.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// شريط الدفع الثابت — القرار وسعره في مكان واحد.
class _PurchaseBar extends StatelessWidget {
  const _PurchaseBar({
    required this.plan,
    required this.price,
    required this.stage,
    required this.enabled,
    required this.isCurrent,
    required this.onPressed,
  });

  final SubscriptionPlan plan;
  final String price;
  final PurchaseStage stage;
  final bool enabled;
  final bool isCurrent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final busy = stage == PurchaseStage.buying || stage == PurchaseStage.verifying;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.spruceDeep,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.screenInset,
            Space.md,
            Space.screenInset,
            Space.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                isCurrent
                    ? 'أنت مشترك في ${plan.title} حالياً'
                    : '${plan.title} · $price ${plan.periodLabel} · '
                        '${plan.slotsLabel}',
                textAlign: TextAlign.center,
                style: AppType.caption,
              ),
              const SizedBox(height: Space.sm),
              AppButton.primary(
                label: switch (stage) {
                  PurchaseStage.verifying => 'نأكّد اشتراكك…',
                  PurchaseStage.buying => 'جارٍ الشراء…',
                  _ => isCurrent ? 'خطتك الحالية' : 'اشترك الآن',
                },
                isLoading: busy,
                onPressed: enabled && !isCurrent ? onPressed : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
