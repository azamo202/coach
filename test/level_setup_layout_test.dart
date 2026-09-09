import 'package:coachmint/core/theme/app_theme.dart';
import 'package:coachmint/data/repositories/auth_repository.dart';
import 'package:coachmint/data/services/local_store.dart';
import 'package:coachmint/features/auth/level_setup_screen.dart';
import 'package:coachmint/state/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حارس تخطيط شاشة المستوى والهدف.
///
/// الشاشة أطول نموذج في التطبيق: ثلاث بطاقات مستوى، سبعة أهداف، وثلاثة حقول
/// قياس في صفّ واحد. الاختبار يفتحها في أضيق جهاز شائع ومع تكبير الخط،
/// ويسقط عند أول فيضان.
void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    bool isEditing = false,
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
          home: LevelSetupScreen(isEditing: isEditing),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  const small = Size(320, 568);
  const large = Size(412, 915);

  testWidgets('لا فيضان على شاشة صغيرة', (tester) async {
    await pumpScreen(tester, size: small);
    expect(find.text('وش مستواك الرياضي؟'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('السؤال لا يتكرّر عنواناً وترويسة قسم', (tester) async {
    await pumpScreen(tester, size: large);
    // كان العنوان الرئيسي يسأل السؤال ثم تعيده ترويسة القسم تحته مباشرة.
    expect(find.text('وش مستواك الرياضي؟'), findsOneWidget);
  });

  testWidgets('اختيار مستوى يبدّل الحالة بلا فيضان', (tester) async {
    await pumpScreen(tester, size: large);

    await tester.tap(find.text('محترف'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('يلا نبدأ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('قياس خارج المدى يُظهر رسالة خطأ ظاهرة', (tester) async {
    await pumpScreen(tester, size: large);

    // كانت رسائل حقول القياس مخفيّة بحجم خطّ صفر، فيرفض النموذج الحفظ
    // بلا سبب مرئي على الشاشة.
    await tester.enterText(find.byType(TextFormField).first, '3');
    await tester.pump();
    await tester.tap(find.text('يلا نبدأ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('العمر يجب أن يكون بين'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('وضع التعديل يعرض زرّ الرجوع وعنوانه', (tester) async {
    await pumpScreen(tester, size: large, isEditing: true);
    expect(find.text('مستواي وهدفي'), findsOneWidget);
    expect(find.text('حفظ التعديلات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('لا فيضان مع تكبير الخط ×1.3', (tester) async {
    await pumpScreen(tester, size: large, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  // iPad — يدور بحرية ويعمل في نوافذ تعدّد المهام. شاشة المستوى أطول
  // نموذج في التطبيق (ثلاثة قياسات + شبكتا اختيار)، فهي أول ما يفيض
  // عند ارتفاع أقصر أو عرض أضيق مما يفترضه تصميم الهاتف.
  for (final (label, ipadSize) in <(String, Size)>[
    ('iPad طولاً', const Size(834, 1112)),
    ('iPad عرضاً', const Size(1366, 1024)),
    ('iPad نافذة جانبية', const Size(320, 1024)),
  ]) {
    testWidgets('لا فيضان على $label', (tester) async {
      await pumpScreen(tester, size: ipadSize);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('لا فيضان على iPad عرضاً مع تكبير الخط ×1.25', (tester) async {
    await pumpScreen(tester, size: const Size(1366, 1024), textScale: 1.25);
    expect(tester.takeException(), isNull);
  });
}
