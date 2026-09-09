import 'dart:convert';

import 'package:coachmint/core/config/app_config.dart';
import 'package:coachmint/core/theme/app_theme.dart';
import 'package:coachmint/data/repositories/subscription_repository.dart';
import 'package:coachmint/data/services/api_client.dart';
import 'package:coachmint/data/services/iap_service.dart';
import 'package:coachmint/data/services/local_store.dart';
import 'package:coachmint/features/paywall/paywall_screen.dart';
import 'package:coachmint/state/subscription_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حارس صفحة الاشتراك.
///
/// الصفحة تجمع ثلاث بطاقات أسعار، كتلة إفصاح قانوني طويلة، وشريط دفع
/// ثابت — أكثر تركيب معرّض للفيضان على الشاشات القصيرة. وهي أيضاً الصفحة
/// التي لا يجوز أن ينقص منها عنصر: غياب زرّ الاستعادة أو الإفصاح عن
/// التجديد التلقائي سبب رفض معروف في مراجعة App Store.
void main() {
  /// متجر وهمي: يعيد المنتجات الثلاثة بأسعار ثابتة بلا لمس StoreKit.
  ///
  /// نحتاجه لأن `Platform.isIOS` كاذب داخل بيئة الاختبار، فالخدمة الحقيقية
  /// ترفض الجلب — وهي حالة صحيحة لكنها ليست ما نريد اختبار تخطيطه.
  final fakeIap = _FakeIapService();

  Future<void> pumpPaywall(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    Map<String, dynamic> entitlement = const <String, dynamic>{
      'planId': 'free',
      'isSubscribed': false,
      'canCreateProgram': false,
      'programSlots': 0,
      'freeGenerationsUsed': 0,
      'freeGenerationsLimit': 0,
    },
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await LocalStore.instance();

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

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionController>(
        create: (_) => SubscriptionController(
          iap: fakeIap,
          repository: SubscriptionRepository(api),
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
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery.withClampedTextScaling(
              minScaleFactor: textScale,
              maxScaleFactor: textScale,
              child: child!,
            ),
          ),
          home: const PaywallScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('تخطيط صفحة الاشتراك', () {
    testWidgets('لا فيضان على شاشة صغيرة (320×568)', (tester) async {
      await pumpPaywall(tester, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });

    testWidgets('لا فيضان على شاشة كبيرة (412×915)', (tester) async {
      await pumpPaywall(tester, size: const Size(412, 915));
      expect(tester.takeException(), isNull);
    });

    testWidgets('لا فيضان مع تكبير الخط ×1.3', (tester) async {
      await pumpPaywall(
        tester,
        size: const Size(390, 844),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });

    // التطبيق يُنشر لـiPhone وiPad، وعلى iPad يدور بحرية ويعمل في نوافذ
    // تعدّد المهام. الوضع الأفقي هو الحرج هنا: شريط الدفع الثابت يحتلّ
    // أسفل الشاشة، فما بقي للمحتوى أقصر مما يفترضه أي تصميم هاتف.
    for (final (label, size) in <(String, Size)>[
      ('iPad طولاً', const Size(834, 1112)),
      ('iPad عرضاً', const Size(1366, 1024)),
      ('iPad نافذة جانبية', const Size(320, 1024)),
    ]) {
      testWidgets('لا فيضان على $label', (tester) async {
        await pumpPaywall(tester, size: size);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('لا فيضان على iPad عرضاً مع تكبير الخط ×1.25', (tester) async {
      await pumpPaywall(
        tester,
        size: const Size(1366, 1024),
        textScale: 1.25,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('متطلبات مراجعة App Store', () {
    testWidgets('الخطط الثلاث ظاهرة بأسعارها ومددها', (tester) async {
      await pumpPaywall(tester, size: const Size(390, 844));

      expect(find.text('برنامج واحد'), findsWidgets);
      expect(find.text('ثلاثة برامج'), findsWidgets);
      expect(find.text('برامج بلا حدود'), findsWidgets);

      // السعر يأتي من المتجر لا من ثوابت التطبيق.
      expect(find.text(r'$10.00'), findsWidgets);
      expect(find.text(r'$20.00'), findsWidgets);
      expect(find.text(r'$100.00'), findsWidgets);

      expect(find.text('شهرياً'), findsWidgets);
      expect(find.text('سنوياً'), findsWidgets);
    });

    testWidgets('زرّ استعادة المشتريات موجود', (tester) async {
      await pumpPaywall(tester, size: const Size(390, 844));
      expect(find.text('استعادة المشتريات'), findsOneWidget);
    });

    testWidgets('الإفصاح عن التجديد التلقائي مكتوب في الصفحة', (tester) async {
      await pumpPaywall(tester, size: const Size(390, 844));

      final disclosure = find.textContaining('يتجدّد تلقائياً');
      expect(disclosure, findsOneWidget);
      expect(
        (tester.widget<Text>(disclosure).data ?? ''),
        allOf(contains('24 ساعة'), contains('App Store')),
      );
    });

    testWidgets('روابط الشروط والخصوصية وإدارة الاشتراك ظاهرة',
        (tester) async {
      await pumpPaywall(tester, size: const Size(390, 844));
      expect(find.text('شروط الاستخدام'), findsOneWidget);
      expect(find.text('سياسة الخصوصية'), findsOneWidget);
      expect(find.text('إدارة الاشتراك'), findsOneWidget);
    });
  });

  group('عرض الحالة', () {
    testWidgets('المستخدم المجاني يرى سبب وصوله ودعوة الاشتراك',
        (tester) async {
      await pumpPaywall(tester, size: const Size(390, 844));
      expect(find.text('اختر خطتك'), findsOneWidget);
      expect(find.text('اشترك الآن'), findsOneWidget);
    });

    testWidgets('المشترك يرى خطته الحالية لا دعوة شراء جديدة',
        (tester) async {
      await pumpPaywall(
        tester,
        size: const Size(390, 844),
        entitlement: const <String, dynamic>{
          'planId': 'trio_monthly',
          'isSubscribed': true,
          'canCreateProgram': true,
          'activePrograms': 2,
          'remainingSlots': 1,
          'coachAdvice': true,
          'autoRenew': true,
          'expiresAt': '2026-10-08T12:00:00.000Z',
        },
      );

      expect(find.text('خطتك: ثلاثة برامج'), findsOneWidget);
      expect(find.textContaining('يتجدّد في'), findsOneWidget);
      expect(find.text('غيّر خطتك'), findsOneWidget);
      expect(find.text('خطتك'), findsOneWidget);
    });

    testWidgets('مشكلة الدفع تُعرض قبل أي عرض شراء', (tester) async {
      await pumpPaywall(
        tester,
        size: const Size(390, 844),
        entitlement: const <String, dynamic>{
          'planId': 'free',
          'isSubscribed': false,
          'canCreateProgram': false,
          'billingIssue': true,
        },
      );

      expect(find.text('فيه مشكلة في الدفع'), findsOneWidget);
    });
  });
}

/// متجر وهمي بمنتجات ثابتة.
class _FakeIapService extends IapService {
  _FakeIapService();

  static final List<ProductDetails> _catalog = <ProductDetails>[
    _product(AppConfig.productSingleMonthly, 'برنامج واحد', r'$10.00', 10),
    _product(AppConfig.productTrioMonthly, 'ثلاثة برامج', r'$20.00', 20),
    _product(AppConfig.productUnlimitedYearly, 'بلا حدود', r'$100.00', 100),
  ];

  static ProductDetails _product(
    String id,
    String title,
    String price,
    double raw,
  ) =>
      ProductDetails(
        id: id,
        title: title,
        description: title,
        price: price,
        rawPrice: raw,
        currencyCode: 'USD',
      );

  @override
  bool get isAvailable => true;

  @override
  List<ProductDetails> get products => _catalog;

  @override
  ProductDetails? productFor(String productId) {
    for (final product in _catalog) {
      if (product.id == productId) return product;
    }
    return null;
  }

  @override
  Future<void> start() async {}

  @override
  Future<List<ProductDetails>> loadProducts() async => _catalog;
}
