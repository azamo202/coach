import 'package:coachmint/core/theme/app_theme.dart';
import 'package:coachmint/data/repositories/auth_repository.dart';
import 'package:coachmint/data/services/local_store.dart';
import 'package:coachmint/features/auth/forgot_password_screen.dart';
import 'package:coachmint/features/auth/login_screen.dart';
import 'package:coachmint/features/auth/signup_screen.dart';
import 'package:coachmint/state/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حارس تخطيط شاشات المصادقة.
///
/// الشاشات الثلاث تشترك في نفس البنية (رأس + لوحة + تذييل) ويتغيّر طولها مع
/// الأخطاء ومؤشّر قوة كلمة المرور. الاختبار يفتح كل شاشة في أضيق جهاز شائع
/// ومع تكبير الخط، ويسقط عند أول فيضان.
void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
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
      // المكتبة لا تُقرأ إلا بعد نجاح الإرسال، وهذه الاختبارات لا تصل إليه.
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
          home: screen,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  const small = Size(320, 568);
  const large = Size(412, 915);

  // ---------------------------------------------------------------
  // مقاسات iPad
  // ---------------------------------------------------------------
  //
  // التطبيق يُنشر لـiPhone وiPad، وعلى iPad يدور بحرية ويعمل في نوافذ
  // تعدّد المهام. هذه ثلاث حالات لا يبلغها أي مقاس هاتف:
  //
  // - `ipadPortrait`  — أعرض من كل تصميمات الهاتف.
  // - `ipadLandscape` — عريض جداً وأقصر، وهو الوضع الذي يفيض فيه ما
  //   بُني على ارتفاع هاتف.
  // - `ipadSlideOver` — أضيق من أي هاتف مع ارتفاع لوحي، ويظهر حين
  //   يسحب المستخدم التطبيق كنافذة جانبية.
  const ipadPortrait = Size(834, 1112);
  const ipadLandscape = Size(1366, 1024);
  const ipadSlideOver = Size(320, 1024);

  testWidgets('الدخول: لا فيضان على شاشة صغيرة', (tester) async {
    await pumpScreen(tester, const LoginScreen(), size: small);
    expect(find.text('أهلاً بعودتك'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('التسجيل: لا فيضان على شاشة صغيرة', (tester) async {
    await pumpScreen(tester, const SignUpScreen(), size: small);
    expect(find.text('أنشئ حسابك'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('التسجيل: مؤشّر القوة والمطابقة بلا فيضان', (tester) async {
    await pumpScreen(tester, const SignUpScreen(), size: large);

    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Passw0rd!2026',
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('قوية جداً'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(3), 'مختلفة');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('التسجيل: الضغط دون الموافقة يُظهر خطأ الشروط', (tester) async {
    await pumpScreen(tester, const SignUpScreen(), size: large);

    // النموذج أطول من الشاشة، فالزرّ يحتاج تمريراً قبل الضغط.
    await tester.ensureVisible(find.text('إنشاء الحساب'));
    await tester.pump();
    await tester.tap(find.text('إنشاء الحساب'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('وافق على الشروط لتتمكّن من إنشاء الحساب.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('التسجيل: لا فيضان مع تكبير الخط ×1.3', (tester) async {
    await pumpScreen(
      tester,
      const SignUpScreen(),
      size: const Size(360, 690),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('استعادة كلمة المرور: لا فيضان', (tester) async {
    await pumpScreen(tester, const ForgotPasswordScreen(), size: small);
    expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------
  // iPad — الأوضاع الثلاثة لكل شاشة مصادقة
  // ---------------------------------------------------------------

  for (final (label, size) in <(String, Size)>[
    ('iPad طولاً', ipadPortrait),
    ('iPad عرضاً', ipadLandscape),
    ('iPad نافذة جانبية', ipadSlideOver),
  ]) {
    testWidgets('الدخول: لا فيضان على $label', (tester) async {
      await pumpScreen(tester, const LoginScreen(), size: size);
      expect(find.text('أهلاً بعودتك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('التسجيل: لا فيضان على $label', (tester) async {
      await pumpScreen(tester, const SignUpScreen(), size: size);
      expect(find.text('أنشئ حسابك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('استعادة كلمة المرور: لا فيضان على $label', (tester) async {
      await pumpScreen(tester, const ForgotPasswordScreen(), size: size);
      expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('التسجيل: لا فيضان على iPad عرضاً مع تكبير الخط ×1.25',
      (tester) async {
    await pumpScreen(
      tester,
      const SignUpScreen(),
      size: ipadLandscape,
      textScale: 1.25,
    );
    expect(tester.takeException(), isNull);
  });
}
