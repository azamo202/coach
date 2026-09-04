import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../../state/health_controller.dart';
import '../../state/library_controller.dart';
import '../auth/level_setup_screen.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

/// حساب المستخدم وإعداداته.
///
/// الأقسام مرتّبة حسب كم يزورها المستخدم فعلاً: التدريب أولاً، ثم التطبيق،
/// وأخيراً إجراءات الحساب — وحذف الحساب في آخر السطر لا في وسط القائمة.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnack(context, 'ما قدرنا نفتح الرابط', isError: true);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final auth = context.read<AuthController>();
    final library = context.read<LibraryController>();
    final navigator = Navigator.of(context);

    final ok = await showConfirmDialog(
      context,
      title: 'تسجيل الخروج',
      message: 'تبقى برامجك محفوظة، وترجع لها عند تسجيل الدخول مرة أخرى.',
      confirmLabel: 'خروج',
    );
    if (!ok) return;

    library.clear();
    await auth.signOut();
    await navigator.pushAndRemoveUntil(
      fadeThroughRoute<void>(const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final auth = context.read<AuthController>();
    final library = context.read<LibraryController>();
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
    await navigator.pushAndRemoveUntil(
      fadeThroughRoute<void>(const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _toggleHealth(BuildContext context, bool enable) async {
    final auth = context.read<AuthController>();
    final health = context.read<HealthController>();

    if (!enable) {
      await health.disconnect();
      await auth.setHealthSync(enabled: false);
      return;
    }

    final connected = await health.connect();
    if (!context.mounted) return;

    if (connected) {
      await auth.setHealthSync(enabled: true);
      if (!context.mounted) return;
      showAppSnack(context, 'تم ربط بيانات صحتك');
    } else if (!health.isAvailable && !kIsWeb && Platform.isAndroid) {
      showAppSnack(context, 'تحتاج تثبيت Health Connect أولاً', isError: true);
      await health.openHealthConnectInstall();
    } else {
      showAppSnack(context, 'ما حصلنا على الصلاحية', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final library = context.watch<LibraryController>();
    final health = context.watch<HealthController>();
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isApple = !kIsWeb && Platform.isIOS;

    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          bottom: false,
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
                          label: 'رياضة',
                          icon: Icons.sports_score_rounded,
                        ),
                        StatTile(
                          value: '${library.totalCompletedSessions}',
                          label: 'جلسة',
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
                    const SectionHeader(title: 'التدريب'),
                    _Tile(
                      icon: user.level.icon,
                      title: 'مستواي وهدفي',
                      subtitle: '${user.level.label} · ${user.goal.label}',
                      onTap: () => context.pushPage(
                        const LevelSetupScreen(isEditing: true),
                      ),
                    ),
                    _Tile(
                      icon: Icons.favorite_outline_rounded,
                      title: isApple ? 'ربط تطبيق الصحة' : 'ربط Health Connect',
                      subtitle: _healthStatus(
                        enabled: user.healthSyncEnabled,
                        connected: health.isConnected,
                      ),
                      trailing: Switch.adaptive(
                        value: user.healthSyncEnabled,
                        onChanged: health.isBusy
                            ? null
                            : (value) => _toggleHealth(context, value),
                      ),
                    ),
                    const SizedBox(height: Space.xxl),
                    const SectionHeader(title: 'عن التطبيق'),
                    _Tile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'سياسة الخصوصية',
                      onTap: () =>
                          _openUrl(context, AppConfig.privacyPolicyUrl),
                    ),
                    _Tile(
                      icon: Icons.description_outlined,
                      title: 'شروط الاستخدام',
                      onTap: () => _openUrl(context, AppConfig.termsUrl),
                    ),
                    _Tile(
                      icon: Icons.mail_outline_rounded,
                      title: 'الدعم الفني',
                      subtitle: AppConfig.supportEmail,
                      onTap: () => _openUrl(
                        context,
                        'mailto:${AppConfig.supportEmail}',
                      ),
                    ),
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
    );
  }

  String _healthStatus({required bool enabled, required bool connected}) {
    if (!enabled) return 'غير مفعّل';
    return connected ? 'مفعّل — نقرأ خطواتك ونشاطك' : 'مفعّل، والصلاحية ناقصة';
  }
}

/// صفّ إعداد واحد. نفس البنية في كل الأقسام.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// لون دلالي للأيقونة والعنوان — للإجراءات المتلفة فقط.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              width: IconSizes.lg + Space.md,
              height: IconSizes.lg + Space.md,
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
            const SizedBox(width: Space.sm),
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : const Icon(
                        // يتبع اتجاه القراءة تلقائياً: يشير يساراً في
                        // الواجهة العربية ويميناً في الإنجليزية.
                        Icons.chevron_right_rounded,
                        size: IconSizes.md,
                        color: AppColors.textTertiary,
                      )),
          ],
        ),
      ),
    );
  }
}
