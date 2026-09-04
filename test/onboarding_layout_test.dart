import 'package:coachmint/core/theme/app_theme.dart';
import 'package:coachmint/data/repositories/auth_repository.dart';
import 'package:coachmint/data/services/local_store.dart';
import 'package:coachmint/features/onboarding/onboarding_screen.dart';
import 'package:coachmint/state/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حارس تخطيط شاشة التعريف.
///
/// الشاشة تجمع رسماً بمقاس ثابت ونصّاً متغيّر الطول فوق زرّين ومؤشّر تقدّم،
/// وهذا أكثر تركيب معرّض للفيضان على الشاشات القصيرة. الاختبار يمرّ على كل
/// شريحة في أضيق جهاز شائع وفي أكبر مقاس خطّ، ويسقط عند أول فيضان.
void main() {
  Future<void> pumpOnboarding(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await LocalStore.instance();

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(
          repository: LocalAuthRepository(store),
          store: store,
        ),
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: child!,
          ),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  /// ينتقل خطوة واحدة. لا نستخدم pumpAndSettle: حقل الكتابة في الشريحة
  /// الأولى يعمل بمؤقّت دوري، فلا تهدأ الشجرة أبداً.
  Future<void> advance(WidgetTester tester) async {
    await tester.tap(find.text('التالي'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> walkAllSlides(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      expect(tester.takeException(), isNull, reason: 'الشريحة ${i + 1}');
      if (i < 3) await advance(tester);
    }
  }

  testWidgets('لا فيضان على شاشة صغيرة (320×568)', (tester) async {
    await pumpOnboarding(tester, size: const Size(320, 568));
    await walkAllSlides(tester);
  });

  testWidgets('لا فيضان على شاشة كبيرة (412×915)', (tester) async {
    await pumpOnboarding(tester, size: const Size(412, 915));
    await walkAllSlides(tester);
  });

  testWidgets('لا فيضان مع تكبير الخط ×1.3', (tester) async {
    await pumpOnboarding(
      tester,
      size: const Size(360, 690),
      textScale: 1.3,
    );
    await walkAllSlides(tester);
  });

  testWidgets('الشريحة الأخيرة تعرض زرّ البدء', (tester) async {
    await pumpOnboarding(tester, size: const Size(360, 690));
    for (var i = 0; i < 3; i++) {
      await advance(tester);
    }
    expect(find.text('ابدأ الآن'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
