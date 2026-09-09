import 'dart:convert';

import 'package:coachmint/core/theme/app_theme.dart';
import 'package:coachmint/data/models/fitness_level.dart';
import 'package:coachmint/data/repositories/program_repository.dart';
import 'package:coachmint/data/repositories/subscription_repository.dart';
import 'package:coachmint/data/services/ai_program_service.dart';
import 'package:coachmint/data/services/api_client.dart';
import 'package:coachmint/data/services/iap_service.dart';
import 'package:coachmint/data/services/local_store.dart';
import 'package:coachmint/data/services/prompt_builder.dart';
import 'package:coachmint/features/sports/generating_screen.dart';
import 'package:coachmint/state/library_controller.dart';
import 'package:coachmint/state/subscription_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حارس تخطيط شاشة التوليد.
///
/// هي الشاشة الوحيدة في التطبيق التي تعرض عموداً ثابتاً بلا تمرير: شعار
/// كبير، عنوان بسطرين محتملين، وسم مستوى، ثم خمس خطوات متتالية. المستخدم
/// يراها دقيقة كاملة ولا يستطيع الخروج منها، فأي فيضان هنا هو أطول عيب
/// بصري في التطبيق — ويظهر بالضبط في اللحظة التي يجرّبها المراجع.
///
/// الاختبار يمرّ بأضيق جهاز يدعمه التطبيق (320×568 — iPhone SE الأول على
/// iOS 15) وبأكبر مقاس خطّ يسمح به `app.dart`، وفي حالتَي الانتظار والفشل.
void main() {
  /// أطول اسم رياضة يقبله `Validators.sport` — الحالة الأسوأ للعنوان.
  const longSport = 'تمارين المقاومة بالأثقال الحرة للجزء العلوي';

  Future<void> pumpGenerating(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    String sport = 'كرة القدم',
    bool failGeneration = false,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await LocalStore.instance();

    // التوليد لا يُختبر هنا — نريد الشاشة معلّقة على حالة الانتظار، أو
    // ساقطة فوراً على حالة الفشل.
    final api = ApiClient(
      baseUrl: 'http://test.local',
      httpClient: MockClient((request) async {
        if (failGeneration) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'message': 'الاشتراك مطلوب لبناء برنامجك التدريبي. اختر باقتك '
                  'لتبدأ، وبعدها نجهّز لك البرنامج كاملاً.',
              'code': 'subscription_required',
            }),
            402,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }
        return http.Response(
          jsonEncode(<String, dynamic>{'entitlement': <String, dynamic>{}}),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }),
    );

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LibraryController>(
            create: (_) => LibraryController(
              repository: RemoteProgramRepository(
                api,
                LocalProgramRepository(store),
              ),
              ai: AiProgramService(api: api),
            )..loadFor('u1'),
          ),
          ChangeNotifierProvider<SubscriptionController>(
            create: (_) => SubscriptionController(
              iap: IapService(),
              repository: SubscriptionRepository(api),
              store: store,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery.withClampedTextScaling(
              minScaleFactor: textScale,
              maxScaleFactor: textScale,
              child: child!,
            ),
          ),
          home: GeneratingScreen(
            request: ProgramRequest(
              sport: sport,
              level: FitnessLevel.advanced,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// يقدّم الوقت حتى تُضيء كل الخطوات — أطول ما تبلغه الشاشة ارتفاعاً.
  Future<void> runThroughAllSteps(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull, reason: 'الخطوة ${i + 1}');
    }
  }

  testWidgets('لا فيضان على أضيق جهاز (320×568) عبر كل الخطوات',
      (tester) async {
    await pumpGenerating(tester, size: const Size(320, 568));
    await runThroughAllSteps(tester);
  });

  testWidgets('لا فيضان باسم رياضة طويل على أضيق جهاز', (tester) async {
    await pumpGenerating(
      tester,
      size: const Size(320, 568),
      sport: longSport,
    );
    await runThroughAllSteps(tester);
  });

  testWidgets('لا فيضان مع أقصى تكبير خطّ يسمح به التطبيق (×1.25)',
      (tester) async {
    await pumpGenerating(
      tester,
      size: const Size(320, 568),
      textScale: 1.25,
      sport: longSport,
    );
    await runThroughAllSteps(tester);
  });

  testWidgets('لا فيضان على شاشة كبيرة (412×915)', (tester) async {
    await pumpGenerating(tester, size: const Size(412, 915));
    await runThroughAllSteps(tester);
  });

  testWidgets('حالة الفشل تعرض الرسالة وزرّي المحاولة والرجوع بلا فيضان',
      (tester) async {
    await pumpGenerating(
      tester,
      size: const Size(320, 568),
      failGeneration: true,
    );
    // ننتظر رجوع الخادم بالرفض ورسم حالة الخطأ.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('ما قدرنا نجهّز البرنامج'), findsOneWidget);
    expect(find.text('رجوع لتعديل الطلب'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // iPad — يدور بحرية ويعمل في نوافذ تعدّد المهام.
  for (final (label, ipadSize) in <(String, Size)>[
    ('iPad طولاً', const Size(834, 1112)),
    ('iPad عرضاً', const Size(1366, 1024)),
    ('iPad نافذة جانبية', const Size(320, 1024)),
  ]) {
    testWidgets('لا فيضان على $label عبر كل الخطوات', (tester) async {
      await pumpGenerating(tester, size: ipadSize, sport: longSport);
      await runThroughAllSteps(tester);
    });
  }
}
