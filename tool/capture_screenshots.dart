// أداة توليد لقطات App Store من الشاشات الحقيقية.
//
//     flutter test tool/capture_screenshots.dart
//
// المخرجات في `build/screenshots/<جهاز>/`. انظر tool/README.md.
//
// ليست اختباراً — لا تعيش تحت `test/` كي لا تجمعها `flutter test`، ولا
// تؤكّد شيئاً سوى أن الشاشات تُرسم بلا استثناء.
//
// لماذا تمرّ عبر `flutter test`؟ لأنه المشغّل الوحيد الذي يرسم شجرة
// ودجت بلا جهاز ولا محاكي — والمشروع يُطوَّر على ويندوز حيث لا وجود
// لمحاكي iOS أصلاً. الشاشات المُلتقَطة هي الشاشات نفسها التي تُبنى في
// النسخة النهائية، لا رسوماً تمثّلها.
//
// المحلّل يعامل `tool/` كشيفرة إنتاج لا اختبار، فيشتكي من أعضاء
// `@visibleForTesting`. والملفّ يعمل داخل `flutter test` فعلاً — أي أنه
// الاستخدام المقصود بالضبط لا التفافاً عليه.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coachmint/core/config/app_config.dart';
import 'package:coachmint/core/theme/app_theme.dart';
import 'package:coachmint/data/models/fitness_level.dart';
import 'package:coachmint/data/models/program_progress.dart';
import 'package:coachmint/data/models/training_program.dart';
import 'package:coachmint/data/repositories/auth_repository.dart';
import 'package:coachmint/data/repositories/program_repository.dart';
import 'package:coachmint/data/repositories/subscription_repository.dart';
import 'package:coachmint/data/services/ai_program_service.dart';
import 'package:coachmint/data/services/api_client.dart';
import 'package:coachmint/data/services/health_service.dart';
import 'package:coachmint/data/services/iap_service.dart';
import 'package:coachmint/data/services/local_store.dart';
import 'package:coachmint/features/paywall/paywall_screen.dart';
import 'package:coachmint/features/program/program_screen.dart';
import 'package:coachmint/features/program/session_screen.dart';
import 'package:coachmint/features/shell/main_shell.dart';
import 'package:coachmint/state/auth_controller.dart';
import 'package:coachmint/state/health_controller.dart';
import 'package:coachmint/state/library_controller.dart';
import 'package:coachmint/state/subscription_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports — `httpClient` معلَّم @visibleForTesting
// وهو المنفذ الوحيد لإسكات جلب الخطوط في بيئة بلا شبكة.
import 'package:google_fonts/src/google_fonts_base.dart' as gf_base;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// جهاز هدف: المقاس المنطقي وكثافة البكسل التي تعطي مقاس App Store.
class _Device {
  const _Device(this.folder, this.logical, this.pixelRatio, this.expected);

  final String folder;
  final Size logical;
  final double pixelRatio;

  /// المقاس بالبكسل الذي يقبله App Store — نتحقق منه بعد الالتقاط.
  final Size expected;
}

const _devices = <_Device>[
  // iPhone 6.5″ — إلزامي لكل تطبيق iPhone.
  _Device('iphone-6.5', Size(414, 896), 3, Size(1242, 2688)),
  // iPad 12.9″ — إلزامي ما دام التطبيق يدعم iPad.
  _Device('ipad-12.9', Size(1024, 1366), 2, Size(2048, 2732)),
];

final GlobalKey _captureKey = GlobalKey();

void main() {
  final fontsDir = Directory('tool/.fonts');

  late Directory gfCache;

  tearDownAll(() {
    // تنظيف بأفضل جهد: محرّك الرسم يُبقي ملفات الخطوط مفتوحة على ويندوز
    // فيرفض النظام حذف المجلد. وهو مجلد مؤقّت يمسحه النظام لاحقاً على أي
    // حال — ولا يجوز أن يُسقط توليداً أنتج كل لقطاته سليمة.
    try {
      if (gfCache.existsSync()) gfCache.deleteSync(recursive: true);
    } on FileSystemException {
      // لا شيء نفعله، ولا شيء يستحق الإبلاغ.
    }
  });

  setUpAll(() async {
    if (!fontsDir.existsSync()) {
      throw StateError(
        'مجلد الخطوط غير موجود: ${fontsDir.path}\n'
        'انظر tool/README.md لأمر تنزيلها.',
      );
    }

    // نملأ ذاكرة الخطوط التي يقرأها google_fonts **قبل** الشبكة.
    //
    // بدون هذا يطلق طلب شبكة لكل عائلة عند كل بناء، ويرمي عند فشله —
    // والاستثناء يصل بعد انتهاء اللقطة فيُسقط تشغيلاً أنتج صوراً سليمة.
    // ولا سبيل لإرضائه عبر الشبكة: يتحقق من طول الملف وبصمته فلا يقبل
    // بديلاً. أما مسار الذاكرة على القرص فيقرأ البايتات كما هي بلا أي
    // تحقّق، فنضع فيه خطوطنا بالأسماء التي يبحث عنها:
    // `<العائلة>_<المتغيّر>_<البصمة>.ttf`.
    //
    // البصمات مأخوذة من جداول google_fonts نفسها. لو رُقّيت الحزمة
    // وتغيّرت، عاد الجلب الشبكي وعادت الضوضاء — وهي إشارة كافية لتحديث
    // القيم أدناه من `lib/src/google_fonts_parts/`.
    const cacheHashes = <String, String>{
      'IBMPlexSansArabic_regular':
          'd5cf8fb8cf46567940400f93c9835d59225bce9745e4fb75915ed52d96041032',
      'IBMPlexSansArabic_500':
          '55c3c36487c44b975a7a2c8839da2d983826c51742dcd77a1dffe0245eb4621f',
      'IBMPlexSansArabic_600':
          'f25f975695c8b5dd3932d0307ed9fff200f64aee4f11a5a1005b71daa3b7d1ca',
      'IBMPlexSansArabic_700':
          'b4df5f9a0306b37b9028cb36a8ec03de3e99a875ef041d0d319a8582f45bd9ca',
      'PlusJakartaSans_regular':
          '80501e2c94323d8b8d48b29bc73aa042539f0a6e62c3afe318980de7b7b19267',
      'PlusJakartaSans_700':
          'dbf8d18a2d1c11f9b68005f52aaefe3974273175b1048047d662a13858c1e9e6',
    };
    const cacheSource = <String, String>{
      'IBMPlexSansArabic_regular': 'IBMPlexSansArabic-Regular.ttf',
      'IBMPlexSansArabic_500': 'IBMPlexSansArabic-Medium.ttf',
      'IBMPlexSansArabic_600': 'IBMPlexSansArabic-SemiBold.ttf',
      'IBMPlexSansArabic_700': 'IBMPlexSansArabic-Bold.ttf',
      'PlusJakartaSans_regular': 'PlusJakartaSans.ttf',
      'PlusJakartaSans_700': 'PlusJakartaSans.ttf',
    };

    final cacheDir = Directory.systemTemp.createTempSync('coachmint-gf-');
    gfCache = cacheDir;
    cacheHashes.forEach((name, hash) {
      File('${cacheDir.path}/${name}_$hash.ttf').writeAsBytesSync(
        File('${fontsDir.path}/${cacheSource[name]}').readAsBytesSync(),
      );
    });

    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => cacheDir.path,
    );

    // شبكة مغلقة صراحةً: لو أخفقت الذاكرة أردنا فشلاً فورياً مرئياً، لا
    // تعليقاً على مهلة اتصال.
    GoogleFonts.config.allowRuntimeFetching = true;
    gf_base.httpClient = MockClient((_) async => http.Response('', 404));

    /// يسجّل عائلة خطّ من ملف أو أكثر — الأول أصلي والبقية احتياط.
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final file in files) {
        final path = '${fontsDir.path}/$file';
        if (!File(path).existsSync()) {
          throw StateError('خطّ ناقص: $path — انظر tool/README.md');
        }
        loader.addFont(
          File(path).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      }
      await loader.load();
    }

    await load('IBMPlexSansArabic_regular', ['IBMPlexSansArabic-Regular.ttf']);
    await load('IBMPlexSansArabic_500', ['IBMPlexSansArabic-Medium.ttf']);
    await load('IBMPlexSansArabic_600', ['IBMPlexSansArabic-SemiBold.ttf']);
    await load('IBMPlexSansArabic_700', ['IBMPlexSansArabic-Bold.ttf']);

    // الخطّ العربي احتياطٌ خلف Plus Jakarta Sans عمداً.
    //
    // `AppType.number` يرسم كل الأرقام بـPlus Jakarta Sans، والتطبيق
    // يكتب النِّسب بعلامة النسبة العربية `٪` (U+066A) — وهذه العلامة
    // **غير موجودة في Plus Jakarta Sans إطلاقاً**. على الجهاز يسدّها
    // خطّ النظام العربي تلقائياً، أما هنا فلا خطّ نظام، فتُرسم مربّعاً
    // فارغاً في كل نسبة على كل شاشة.
    await load('PlusJakartaSans_regular', [
      'PlusJakartaSans.ttf',
      'IBMPlexSansArabic-Regular.ttf',
    ]);
    await load('PlusJakartaSans_700', [
      'PlusJakartaSans.ttf',
      'IBMPlexSansArabic-Bold.ttf',
    ]);

    // بلا خطّ الأيقونات تُرسم مربّعات فارغة مكان كل أيقونة في التطبيق.
    await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  /// برنامج كامل الحقول بمحتوى واقعي — اللقطة تُظهر ما يراه المستخدم فعلاً.
  TrainingProgram buildProgram({
    String id = 'p_shot',
    String sport = 'تمارين المقاومة بالأثقال الحرة',
    FitnessLevel level = FitnessLevel.advanced,
    TrainingGoal goal = TrainingGoal.strength,
    int accentShift = 0,
  }) {
    const bench = Exercise(
      name: 'ضغط الصدر بالبار على مقعد مائل',
      sets: 4,
      reps: '8-10',
      restSeconds: 90,
      tempo: '2-0-1-0',
      targetMuscles: 'الصدر العلوي، الكتف الأمامي، الترايسبس',
      equipment: 'بار أولمبي، مقعد مائل',
      howTo: 'استلقِ على المقعد المائل بزاوية ٣٠ درجة، امسك البار بقبضة '
          'أوسع قليلاً من الكتفين، أنزل البار ببطء حتى يلامس أعلى الصدر، '
          'ثم ادفع للأعلى مع إبقاء لوحَي الكتف مسحوبتين للخلف.',
      cue: 'ادفع الأرض بقدميك وثبّت القفص الصدري قبل كل تكرار',
    );
    const row = Exercise(
      name: 'التجديف بالبار المنحني',
      sets: 4,
      reps: '10-12',
      restSeconds: 75,
      tempo: '2-1-1-0',
      targetMuscles: 'الظهر العريض، المعيّنة، البايسبس',
      equipment: 'بار أولمبي، أوزان',
      howTo: 'انحنِ من الوركين حتى يصير جذعك قريباً من الأفقي، وظهرك '
          'مستقيم، ثم اسحب البار إلى أسفل القفص الصدري واعصر لوحَي الكتف.',
      cue: 'اسحب بمرفقيك لا بكفّيك',
    );
    const press = Exercise(
      name: 'الضغط العلوي واقفاً',
      sets: 3,
      reps: '6-8',
      restSeconds: 90,
      tempo: '2-0-1-0',
      targetMuscles: 'الكتف، الترايسبس، عضلات الجذع',
      equipment: 'بار أولمبي',
      howTo: 'ثبّت قدميك بعرض الحوض، اقبض البار عند مستوى الترقوة، ادفعه '
          'فوق رأسك مباشرة حتى يستقيم ذراعاك، ثم أنزله بتحكّم.',
      cue: 'شدّ بطنك ولا تقوّس أسفل ظهرك',
    );

    return TrainingProgram(
      id: id,
      sport: sport,
      level: level,
      goal: goal,
      accentIndex: accentShift,
      createdAt: DateTime(2026, 1, 1),
      summary: 'برنامج قوة متدرّج على ثمانية أسابيع، يرفع الحمل أسبوعياً '
          'مع تنويع في شدة الجلسات بين ثقيلة ومتوسطة وخفيفة.',
      tips: const <String>[
        'نم سبع ساعات على الأقل — التعافي جزء من البرنامج لا إضافة عليه.',
        'سجّل أوزانك بعد كل جلسة لتعرف من أين تزيد الأسبوع القادم.',
      ],
      equipmentNeeded: const <String>['بار أولمبي', 'أوزان', 'مقعد مائل'],
      safetyNotes: 'أحمِ ظهرك: لا ترفع بوزن يجبرك على تقويس أسفل الظهر، '
          'واستعن بمراقب في المجموعات الثقيلة.',
      weeks: List<TrainingWeek>.generate(
        8,
        (w) => TrainingWeek(
          title: switch (w) {
            0 => 'تأسيس الحمل',
            1 => 'رفع الحجم',
            2 => 'زيادة الشدّة',
            3 => 'أسبوع تخفيف',
            4 => 'قوة قصوى',
            5 => 'كثافة أعلى',
            6 => 'ذروة الحمل',
            _ => 'تثبيت المكتسب',
          },
          days: List<TrainingDay>.generate(
            5,
            (d) => TrainingDay(
              label: switch (d) {
                0 => 'دفع علوي',
                1 => 'سحب علوي',
                2 => 'أرجل',
                3 => 'كتف وذراعان',
                _ => 'جذع كامل',
              },
              focus: 'قوة',
              durationMinutes: 65,
              warmUp: 'عشر دقائق دراجة ثابتة ثم تسخين المفاصل بحركات دائرية.',
              coolDown: 'خمس دقائق إطالة ساكنة للصدر والكتف والترايسبس.',
              exercises: const <Exercise>[bench, row, press],
            ),
          ),
        ),
      ),
    );
  }

  var seq = 0;

  /// يبني الشجرة الكاملة حول [screen] ويلتقطها كملف PNG.
  Future<void> shoot(
    WidgetTester tester,
    _Device device,
    String name,
    Widget Function() screen, {
    /// عدد الجلسات المكتملة — يملأ الرسوم البيانية وشريط التقدّم.
    int completedSessions = 11,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await LocalStore.instance();
    seq++;

    final api = ApiClient(
      baseUrl: 'http://shot.local',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(<String, dynamic>{
            'entitlement': <String, dynamic>{
              'planId': 'unlimited_yearly',
              'isSubscribed': true,
              'canCreateProgram': true,
              'coachAdvice': true,
              'activePrograms': 1,
              'autoRenew': true,
              'expiresAt': '2027-01-01T00:00:00.000Z',
            },
          }),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        ),
      ),
    );

    final auth = AuthController(
      repository: LocalAuthRepository(store),
      store: store,
    );
    await auth.signUp(
      name: 'عبدالله',
      email: 'shot$seq@coachmint.app',
      password: 'Passw0rd1',
    );

    final programs = LocalProgramRepository(store);

    /// تقدّم بتواريخ محسوبة من اليوم لا ثابتة.
    ///
    /// الرسم الأسبوعي والسلسلة اليومية يقرآن «آخر ٧ أيام»، فتواريخ ثابتة
    /// تعني لقطةً برسم فارغ بعد أسبوع من كتابة الأداة.
    ProgramProgress progressOf(int done) => ProgramProgress(
          completed: <String, DateTime>{
            for (var i = 0; i < done; i++)
              ProgramProgress.keyFor(i ~/ 5, i % 5):
                  DateTime.now().subtract(Duration(days: done - 1 - i)),
          },
          lastOpenedAt: DateTime.now(),
        );

    // ثلاث رياضات لا واحدة.
    //
    // «حفظ حتى ١٢ رياضة بالتوازي» ميزة أساسية في التطبيق، ومكتبةٌ فيها
    // بطاقة واحدة تُظهر عكسها في أهم لقطة تسويقية. والرئيسية أيضاً تعرض
    // «رياضاتك» فتبدو خاوية ببرنامج واحد.
    await programs.save(
      auth.user!.id,
      SavedProgram(
        program: buildProgram(),
        progress: progressOf(completedSessions),
      ),
    );
    await programs.save(
      auth.user!.id,
      SavedProgram(
        program: buildProgram(
          id: 'p_swim',
          sport: 'السباحة',
          level: FitnessLevel.intermediate,
          goal: TrainingGoal.endurance,
          accentShift: 1,
        ),
        progress: progressOf(6),
      ),
    );
    await programs.save(
      auth.user!.id,
      SavedProgram(
        program: buildProgram(
          id: 'p_box',
          sport: 'الملاكمة',
          level: FitnessLevel.beginner,
          goal: TrainingGoal.general,
          accentShift: 2,
        ),
        progress: progressOf(3),
      ),
    );

    final library = LibraryController(
      repository: programs,
      ai: AiProgramService(api: api),
    );
    await library.loadFor(auth.user!.id);

    tester.view
      ..physicalSize = device.logical
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: api),
            Provider<LocalStore>.value(value: store),
            Provider<AiProgramService>.value(value: AiProgramService(api: api)),
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<LibraryController>.value(value: library),
            ChangeNotifierProvider<HealthController>(
              create: (_) => HealthController(
                service: HealthService(),
                store: store,
              ),
            ),
            ChangeNotifierProvider<SubscriptionController>(
              create: (_) => SubscriptionController(
                iap: _ShotIap(),
                repository: SubscriptionRepository(api),
                store: store,
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
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
            home: screen(),
          ),
        ),
      ),
    );

    // لا pumpAndSettle: بعض الشاشات تحمل حركات دورية لا تهدأ أبداً.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    // أي استثناء هنا عيبٌ حقيقي في الشاشة، ويجب أن يُسقط التوليد قبل أن
    // تُرفع لقطة معطوبة إلى المتجر.
    expect(tester.takeException(), isNull, reason: 'الشاشة $name رمت استثناءً');

    final boundary =
        _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: device.pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });

    final dir = Directory('build/screenshots/${device.folder}')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!);

    // App Store يرفض أي مقاس غير مطابق، والرفض يأتي بعد الرفع لا قبله.
    final codec = await tester.runAsync(
      () => ui.instantiateImageCodec(bytes),
    );
    final frame = await tester.runAsync(() => codec!.getNextFrame());
    final w = frame!.image.width;
    final h = frame.image.height;
    expect(
      Size(w.toDouble(), h.toDouble()),
      device.expected,
      reason: 'مقاس ${device.folder}/$name غير مقبول في App Store',
    );

    // ignore: avoid_print
    print('✓ ${device.folder}/$name.png  ($w×$h)');
  }

  for (final device in _devices) {
    group(device.folder, () {
      testWidgets('01 الرئيسية', (t) async {
        await shoot(t, device, '01-home', () => const MainShell());
      });

      testWidgets('02 برامجي', (t) async {
        await shoot(
          t,
          device,
          '02-library',
          () => const MainShell(initialIndex: 1),
        );
      });

      testWidgets('03 البرنامج', (t) async {
        await shoot(
          t,
          device,
          '03-program',
          () => const ProgramScreen(programId: 'p_shot'),
        );
      });

      testWidgets('04 الجلسة', (t) async {
        await shoot(
          t,
          device,
          '04-session',
          () => const SessionScreen(
            programId: 'p_shot',
            weekIndex: 2,
            dayIndex: 0,
          ),
        );
      });

      testWidgets('05 تقدّمي', (t) async {
        await shoot(
          t,
          device,
          '05-progress',
          () => const MainShell(initialIndex: 2),
        );
      });

      testWidgets('06 الاشتراك', (t) async {
        await shoot(t, device, '06-paywall', () => const PaywallScreen());
      });
    });
  }
}

/// متجر بأسعار ثابتة — StoreKit لا يعمل خارج iOS، وصفحة اشتراك بلا أسعار
/// لقطةٌ لا تصلح للمتجر.
class _ShotIap extends IapService {
  static final List<ProductDetails> _catalog = <ProductDetails>[
    _p(AppConfig.productSingleMonthly, 'برنامج واحد', r'$9.99', 9.99),
    _p(AppConfig.productTrioMonthly, 'ثلاثة برامج', r'$19.99', 19.99),
    _p(AppConfig.productUnlimitedYearly, 'برامج بلا حدود', r'$99.99', 99.99),
  ];

  static ProductDetails _p(String id, String title, String price, double raw) =>
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
  ProductDetails? productFor(String id) {
    for (final p in _catalog) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<void> start() async {}

  @override
  Future<List<ProductDetails>> loadProducts() async => _catalog;
}
