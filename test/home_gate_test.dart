import 'dart:convert';

import 'package:coachmint/core/theme/app_theme.dart';
import 'package:coachmint/data/repositories/auth_repository.dart';
import 'package:coachmint/data/repositories/program_repository.dart';
import 'package:coachmint/data/repositories/subscription_repository.dart';
import 'package:coachmint/data/services/ai_program_service.dart';
import 'package:coachmint/data/services/api_client.dart';
import 'package:coachmint/data/services/health_service.dart';
import 'package:coachmint/data/services/iap_service.dart';
import 'package:coachmint/data/services/local_store.dart';
import 'package:coachmint/features/home/home_screen.dart';
import 'package:coachmint/state/auth_controller.dart';
import 'package:coachmint/state/health_controller.dart';
import 'package:coachmint/state/library_controller.dart';
import 'package:coachmint/state/subscription_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حارس القفل على الشاشة الأولى.
///
/// التطبيق مقفول بالكامل خلف الاشتراك، فأول شاشة يراها مستخدم جديد يجب أن
/// تقوده إلى الباقات لا أن تعده بإنشاء لا يستطيعه. هذا الاختبار يحرس ذلك
/// الوعد: لا زرّ ولا اختصار يقود إلى طريق مسدود.
void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    required bool subscribed,
    Size size = const Size(390, 844),
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await LocalStore.instance();

    final entitlement = subscribed
        ? <String, dynamic>{
            'planId': 'trio_monthly',
            'isSubscribed': true,
            'canCreateProgram': true,
            'coachAdvice': true,
            'remainingSlots': 3,
          }
        : <String, dynamic>{
            'planId': 'free',
            'isSubscribed': false,
            'canCreateProgram': false,
            'programSlots': 0,
            'freeGenerationsLimit': 0,
          };

    final api = ApiClient(
      baseUrl: 'http://test.local',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(<String, dynamic>{'entitlement': entitlement}),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        ),
      ),
    );

    final subscription = SubscriptionController(
      iap: IapService(),
      repository: SubscriptionRepository(api),
      store: store,
    );
    await subscription.refresh();

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(
              repository: LocalAuthRepository(store),
              store: store,
            ),
          ),
          ChangeNotifierProvider<LibraryController>(
            create: (_) => LibraryController(
              repository: LocalProgramRepository(store),
              ai: AiProgramService(api: null),
            ),
          ),
          ChangeNotifierProvider<HealthController>(
            create: (_) => HealthController(
              service: HealthService(),
              store: store,
            ),
          ),
          ChangeNotifierProvider<SubscriptionController>.value(
            value: subscription,
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
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('الشاشة الأولى بلا اشتراك', () {
    testWidgets('الزرّ الأساسي يقود إلى الباقات لا إلى الإنشاء',
        (tester) async {
      await pumpHome(tester, subscribed: false);

      expect(find.text('اختر باقتك'), findsOneWidget);
      expect(find.text('أنشئ برنامجي'), findsNothing);
    });

    testWidgets('اختصارات الرياضات مخفية — كلها تنتهي إلى نفس الحاجز',
        (tester) async {
      await pumpHome(tester, subscribed: false);

      expect(find.text('أو ابدأ من رياضة شائعة'), findsNothing);
      expect(find.text('كرة قدم'), findsNothing);
    });

    testWidgets('«كيف يعمل» يبقى ظاهراً — القيمة تُعرض قبل الدفع',
        (tester) async {
      await pumpHome(tester, subscribed: false);
      expect(find.text('كيف يعمل'), findsOneWidget);
    });

    testWidgets('لا فيضان في التخطيط المقفول', (tester) async {
      await pumpHome(tester, subscribed: false, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });
  });

  group('الشاشة الأولى مع اشتراك', () {
    testWidgets('الزرّ الأساسي يقود إلى الإنشاء مباشرةً', (tester) async {
      await pumpHome(tester, subscribed: true);

      expect(find.text('أنشئ برنامجي'), findsOneWidget);
      expect(find.text('اختر باقتك'), findsNothing);
    });

    testWidgets('اختصارات الرياضات تظهر للمشترك', (tester) async {
      await pumpHome(tester, subscribed: true);

      expect(find.text('أو ابدأ من رياضة شائعة'), findsOneWidget);
      expect(find.text('كرة قدم'), findsOneWidget);
    });
  });
}
