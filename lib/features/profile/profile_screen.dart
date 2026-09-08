import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/ar_plural.dart';
import '../../core/widgets/app_widgets.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../../state/health_controller.dart';
import '../../state/library_controller.dart';
import '../../state/subscription_controller.dart';
import '../auth/level_setup_screen.dart';
import '../auth/login_screen.dart';
import '../paywall/paywall_screen.dart';
import 'edit_profile_screen.dart';

/// حساب المستخدم وإعداداته.
///
/// الأقسام مرتّبة حسب كم يزورها المستخدم فعلاً: التدريب أولاً، ثم التطبيق،
/// وأخيراً إجراءات الحساب — وحذف الحساب في آخر السطر لا في وسط القائمة.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final auth = context.read<AuthController>();
    final library = context.read<LibraryController>();
    final subscription = context.read<SubscriptionController>();
    final navigator = Navigator.of(context);

    final ok = await showConfirmDialog(
      context,
      title: 'تسجيل الخروج',
      message: 'تبقى برامجك محفوظة، وترجع لها عند تسجيل الدخول مرة أخرى.',
      confirmLabel: 'خروج',
    );
    if (!ok) return;

    library.clear();
    subscription.clear();
    await auth.signOut();
    await navigator.pushAndRemoveUntil(
      fadeThroughRoute<void>(const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final auth = context.read<AuthController>();
    final library = context.read<LibraryController>();
    final subscription = context.read<SubscriptionController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showConfirmDialog(
      context,
      title: 'حذف الحساب نهائياً؟',
      message: 'يُحذف حسابك وكل برامجك وتقدّمك. لا يمكن التراجع عن هذا '
          'الإجراء ولا استعادة البيانات لاحقاً.',
      confirmLabel: 'حذف نهائي',
      isDestructive: true,
    );
    if (!ok) return;

    final done = await auth.deleteAccount();
    if (!done) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('تعذّر حذف الحساب. حاول مرة ثانية.')),
        );
      return;
    }

    library.clear();
    subscription.clear();
    await navigator.pushAndRemoveUntil(
      fadeThroughRoute<void>(const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final library = context.watch<LibraryController>();
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Space.contentWidth),
              child: ListView(
                padding: const EdgeInsets.only(bottom: Space.bottomBarClearance),
                children: <Widget>[
                  ScreenHeader(
                    title: user.name,
                    subtitle: user.email,
                    leading: AppAvatar(initials: user.initials, size: 52),
                    trailing: AppIconButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'تعديل البيانات',
                      onPressed: () => context.pushPage(const EditProfileScreen()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.screenInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        StatRow(
                          tiles: <StatTile>[
                            StatTile(
                              value: '${library.entries.length}',
                              label: Ar.sport.unit(library.entries.length),
                              icon: Icons.sports_score_rounded,
                            ),
                            StatTile(
                              value: '${library.totalCompletedSessions}',
                              label: Ar.session
                                  .unit(library.totalCompletedSessions),
                              icon: Icons.check_circle_outline_rounded,
                            ),
                            StatTile(
                              value: user.level.label,
                              label: 'المستوى',
                              icon: user.level.icon,
                              isNumeric: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.x3),
                        const SectionHeader(title: 'الاشتراك'),
                        const _SubscriptionTile(),
                        const SizedBox(height: Space.xxl),
                        const SectionHeader(title: 'التدريب'),
                        _Tile(
                          icon: user.level.icon,
                          title: 'مستواي وهدفي',
                          subtitle: '${user.level.label} · ${user.goal.label}',
                          onTap: () => context.pushPage(
                            const LevelSetupScreen(isEditing: true),
                          ),
                        ),
                        _HealthSyncTile(enabled: user.healthSyncEnabled),
                        const SizedBox(height: Space.xxl),
                        const SectionHeader(title: 'الحساب'),
                        _Tile(
                          icon: Icons.logout_rounded,
                          title: 'تسجيل الخروج',
                          onTap: () => _signOut(context),
                        ),
                        const SizedBox(height: Space.xxl),
                        // الحذف النهائي معزول عن بقية القائمة، لا صفّاً بينها.
                        _Tile(
                          icon: Icons.delete_forever_outlined,
                          accent: AppColors.danger,
                          title: 'حذف الحساب',
                          subtitle: 'يمسح كل بياناتك نهائياً',
                          onTap: () => _deleteAccount(context),
                        ),
                        const SizedBox(height: Space.xxl),
                        Center(
                          child: Text(
                            '${AppConfig.appName} · الإصدار 1.0.0',
                            style: AppType.caption,
                          ),
                        ),
                      ],
                    ),
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

/// حالة الاشتراك ومدخل صفحة الباقات.
///
/// الصفّ يقول ما يملكه المستخدم الآن وكم بقي له من حصص — لا «اشترك الآن»
/// وحدها. المشترك يحتاج أن يرى خطته بقدر ما يحتاج غيرُه أن يرى العرض.
class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SubscriptionController>();
    final entitlement = controller.entitlement;
    final plan = entitlement.plan;

    final String subtitle;
    if (entitlement.billingIssue) {
      subtitle = 'فيه مشكلة في الدفع — حدّث طريقة الدفع ليرجع اشتراكك';
    } else if (!entitlement.isSubscribed) {
      subtitle = entitlement.freeTrialUsedUp
          ? 'استهلكت برنامجك المجاني — اشترك لتكمل'
          : 'اشترك لتبني برامجك مع المدرّب الذكي';
    } else if (plan.isUnlimited) {
      subtitle = 'برامج بلا حدود · ${entitlement.activePrograms} برنامج نشط';
    } else {
      final left = entitlement.remainingSlots ?? 0;
      subtitle = left > 0
          ? '${plan.slotsLabel} · بقي لك $left'
          : '${plan.slotsLabel} · استخدمت كل حصصك';
    }

    return _Tile(
      icon: entitlement.isSubscribed
          ? Icons.workspace_premium_rounded
          : Icons.lock_open_rounded,
      accent: entitlement.billingIssue
          ? AppColors.warning
          : entitlement.isSubscribed
              ? AppColors.mint
              : null,
      title: entitlement.isSubscribed ? plan.title : 'باقات الاشتراك',
      subtitle: subtitle,
      trailing: controller.isRefreshing
          ? const SizedBox(
              width: IconSizes.md,
              height: IconSizes.md,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: () => context.pushPage(const PaywallScreen()),
    );
  }
}

/// ربط بيانات الصحة.
///
/// كان هذا الصفّ غائباً عن الواجهة كلها: [HealthController] مكتمل، وبطاقة
/// «نشاطك» في الرئيسية تحيل المستخدم إلى «حسابي ← ربط الصحة» — إلى صفّ لا
/// وجود له، فتبقى الميزة معطّلة بلا طريق إليها.
class _HealthSyncTile extends StatelessWidget {
  const _HealthSyncTile({required this.enabled});

  final bool enabled;

  Future<void> _toggle(BuildContext context, {required bool value}) async {
    final auth = context.read<AuthController>();
    final health = context.read<HealthController>();
    final messenger = ScaffoldMessenger.of(context);

    if (!value) {
      await health.disconnect();
      await auth.setHealthSync(enabled: false);
      return;
    }

    // الصلاحية تُطلب أولاً: لا معنى لتشغيل المزامنة قبل موافقة النظام.
    final granted = await health.connect();
    await auth.setHealthSync(enabled: granted);
    if (granted) return;

    // الرسالة تقول ما الذي منع الربط وأين يُصلَح، لا «تعذّر» وحدها.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            health.isAvailable
                ? 'ما وصلتنا صلاحية القراءة. افتح تطبيق الصحة على جهازك '
                    'واسمح لـCoachMint بقراءة نشاطك.'
                : 'خدمة الصحة غير متاحة على هذا الجهاز.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthController>();

    return _Tile(
      icon: Icons.favorite_border_rounded,
      title: 'ربط بيانات الصحة',
      subtitle: enabled
          ? 'يقرأ المدرّب خطواتك ودقائق تمرينك ليضبط الحمل'
          : 'اربطه ليأخذ نشاطك اليومي بالحسبان',
      trailing: health.isBusy
          ? const SizedBox(
              width: IconSizes.md,
              height: IconSizes.md,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: enabled,
              onChanged: (value) => _toggle(context, value: value),
            ),
      onTap: health.isBusy ? null : () => _toggle(context, value: !enabled),
      toggled: enabled,
    );
  }
}

/// صفّ إعداد واحد. نفس البنية في كل الأقسام.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.accent,
    this.trailing,
    this.toggled,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// لون دلالي للأيقونة والعنوان — للإجراءات المتلفة فقط.
  final Color? accent;

  /// عنصر في طرف الصفّ يحلّ محلّ سهم الانتقال — مفتاح أو مؤشّر انتظار.
  final Widget? trailing;

  /// حالة المفتاح إن كان الصفّ مفتاحاً — تُعلَن للقارئ الصوتي.
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: AppCard(
        onTap: onTap,
        radius: Radii.md,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: IconSizes.tile,
              height: IconSizes.tile,
              decoration: BoxDecoration(
                color:
                    (accent ?? AppColors.textSecondary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(
                icon,
                size: IconSizes.md,
                color: accent ?? AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppType.h4.copyWith(color: accent),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: Space.xxs),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: Space.sm),
              // المفتاح يُعلَن مرة واحدة على مستوى الصفّ كاملاً.
              ExcludeSemantics(child: trailing!),
            ] else if (onTap != null) ...<Widget>[
              const SizedBox(width: Space.sm),
              const Icon(
                Icons.chevron_right_rounded,
                size: IconSizes.md,
                color: AppColors.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );

    if (toggled == null) return row;

    // صفّ المفتاح يُقرأ كمفتاح واحد بحالته، لا كزرّ ثم مفتاح منفصلين.
    return Semantics(
      toggled: toggled,
      label: title,
      child: ExcludeSemantics(child: row),
    );
  }
}
