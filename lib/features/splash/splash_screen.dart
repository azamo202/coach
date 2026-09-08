import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/brand_logo.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../../state/health_controller.dart';
import '../../state/library_controller.dart';
import '../../state/subscription_controller.dart';
import '../auth/level_setup_screen.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../shell/main_shell.dart';

/// شاشة الإقلاع: تستعيد الجلسة ثم توجّه المستخدم للمكان الصحيح.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  late final Animation<double> _markIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.7, curve: Curves.easeOutBack),
  );

  late final Animation<double> _wordIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthController>();
    final library = context.read<LibraryController>();
    final health = context.read<HealthController>();
    final subscription = context.read<SubscriptionController>();

    await Future.wait<void>(<Future<void>>[
      auth.bootstrap(),
      Future<void>.delayed(const Duration(milliseconds: 1000)),
    ]);

    if (!mounted) return;

    // نحمّل مكتبة البرامج وبيانات الصحة في الخلفية.
    final user = auth.user;
    if (user != null) {
      _fireAndForget(library.loadFor(user.id));
      // الصلاحية تُحمَّل في الخلفية: الشاشات المدفوعة تنتظرها، والباقي لا.
      _fireAndForget(
        subscription.bindAccount(
          userId: user.id,
          appAccountToken: user.appAccountToken,
        ),
      );
      if (user.healthSyncEnabled) _fireAndForget(health.bootstrap());
    }

    if (!auth.hasSeenOnboarding) {
      await context.resetTo(const OnboardingScreen());
      return;
    }
    if (!auth.isSignedIn) {
      await context.resetTo(const LoginScreen());
      return;
    }
    if (user != null && !user.hasCompletedOnboarding) {
      await context.resetTo(const LevelSetupScreen());
      return;
    }
    await context.resetTo(const MainShell());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.spruce,
      body: Center(
        child: Column(
          children: <Widget>[
            const Spacer(flex: 3),
            ScaleTransition(
              scale: Tween<double>(begin: 0.7, end: 1).animate(_markIn),
              child: FadeTransition(
                opacity: _markIn,
                child: const CoachMintMark(size: 120),
              ),
            ),
            const SizedBox(height: Space.xxl),
            FadeTransition(
              opacity: _wordIn,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.35),
                  end: Offset.zero,
                ).animate(_wordIn),
                child: Column(
                  children: <Widget>[
                    const CoachMintLogo(showMark: false, wordmarkSize: 32),
                    const SizedBox(height: Space.sm),
                    Text(AppConfig.appTagline, style: AppType.bodySm),
                  ],
                ),
              ),
            ),
            const Spacer(flex: 3),
            const SizedBox(
              width: IconSizes.lg,
              height: IconSizes.lg,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: Space.x5),
          ],
        ),
      ),
    );
  }
}

/// تشغيل عملية في الخلفية دون انتظارها، مع تسجيل أي خطأ.
void _fireAndForget(Future<void> future) {
  future.catchError((Object error) {
    debugPrint('Background task failed: $error');
  });
}
