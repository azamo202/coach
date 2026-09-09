import 'dart:convert';

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
import 'package:coachmint/features/profile/edit_profile_screen.dart';
import 'package:coachmint/features/program/program_screen.dart';
import 'package:coachmint/features/program/session_screen.dart';
import 'package:coachmint/features/shell/main_shell.dart';
import 'package:coachmint/features/sports/new_program_screen.dart';
import 'package:coachmint/state/auth_controller.dart';
import 'package:coachmint/state/health_controller.dart';
import 'package:coachmint/state/library_controller.dart';
import 'package:coachmint/state/subscription_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حارس تخطيط iPad للشاشات الغنية بالمحتوى.
///
/// التطبيق يُنشر لـiPhone وiPad. على iPhone الاتجاه مقفول على الطول في
/// `Info.plist`، أما على iPad فالاتجاهات الأربعة معلنة والتطبيق يعمل في
/// نوافذ تعدّد المهام — أي أن نفس الشجرة تُرسم بثلاث هندسات لا يبلغها أي
/// مقاس هاتف:
///
/// - **iPad طولاً** — ضعفا عرض الهاتف.
/// - **iPad عرضاً** — ثلاثة أضعاف العرض مع ارتفاع أقصر من هاتف طويل،
///   وهو الوضع الذي يفيض فيه ما بُني على ارتفاع هاتف.
/// - **نافذة جانبية** — أضيق من أي هاتف مع ارتفاع لوحي.
///
/// بقية ملفات التخطيط تغطي شاشات المصادقة والاشتراك والتعريف والتوليد.
/// هذا الملف يغطي ما تبقّى: الهيكل بتبويباته الأربعة، وشاشتَي البرنامج
/// والجلسة، ونموذج البرنامج الجديد، وتعديل الحساب — وهي الشاشات التي
/// تحمل أكثر البيانات، فأكثرها عرضة للفيضان.
void main() {
  const ipadPortrait = Size(834, 1112);
  const ipadLandscape = Size(1366, 1024);
  const ipadSlideOver = Size(320, 1024);

  const geometries = <(String, Size)>[
    ('iPad طولاً', ipadPortrait),
    ('iPad عرضاً', ipadLandscape),
    ('iPad نافذة جانبية', ipadSlideOver),
  ];

  /// برنامج كامل الحقول — لا برنامج هيكلي.
  ///
  /// الفيضان يأتي من المحتوى الطويل لا من وجود الحقل، فكل نصّ هنا بطول
  /// ما يكتبه الذكاء الاصطناعي فعلاً.
  TrainingProgram buildProgram() {
    const exercise = Exercise(
      name: 'ضغط الصدر بالبار على مقعد مائل',
      sets: 4,
      reps: '8-10',
      restSeconds: 90,
      tempo: '2-0-1-0',
      targetMuscles: 'الصدر العلوي، الكتف الأمامي، الترايسبس',
      equipment: 'بار أولمبي، مقعد مائل، أوزان',
      howTo: 'استلقِ على المقعد المائل بزاوية ٣٠ درجة، امسك البار بقبضة '
          'أوسع قليلاً من الكتفين، أنزل البار ببطء حتى يلامس أعلى الصدر، '
          'ثم ادفع للأعلى مع إبقاء لوحَي الكتف مسحوبتين للخلف.',
      cue: 'ادفع الأرض بقدميك وثبّت القفص الصدري قبل كل تكرار',
    );

    return TrainingProgram(
      id: 'p_ipad',
      sport: 'تمارين المقاومة بالأثقال الحرة',
      level: FitnessLevel.advanced,
      goal: TrainingGoal.strength,
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
          title: 'الأسبوع ${w + 1}',
          days: List<TrainingDay>.generate(
            5,
            (d) => TrainingDay(
              label: 'اليوم ${d + 1}',
              focus: 'دفع علوي — قوة',
              durationMinutes: 65,
              warmUp: 'عشر دقائق دراجة ثابتة ثم تسخين المفاصل بحركات دائرية.',
              coolDown: 'خمس دقائق إطالة ساكنة للصدر والكتف والترايسبس.',
              exercises: const <Exercise>[
                exercise,
                exercise,
                exercise,
                exercise,
                exercise,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `LocalStore` مفرد يحتفظ بنسخته بين الاختبارات داخل الملف الواحد،
  /// فبريد ثابت يعني «هذا البريد مسجّل من قبل» في كل اختبار بعد الأول.
  var accountSeq = 0;

  /// يبني الشجرة الكاملة بمزوّديها حول [screen] بحجم شاشة محدّد.
  ///
  /// المستخدم مسجَّل ومشترك: الحالتان المقفولتان مغطّاتان في
  /// `home_gate_test.dart` و`paywall_layout_test.dart`، وما يهمّنا هنا هو
  /// الشجرة الأكثر امتلاءً — أي شجرة المشترك الذي عنده برنامج.
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    required Size size,
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await LocalStore.instance();
    accountSeq++;

    final api = ApiClient(
      baseUrl: 'http://test.local',
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
    final created = await auth.signUp(
      name: 'مستخدم اختبار',
      email: 'ipad$accountSeq@coachmint.app',
      password: 'Passw0rd1',
    );
    expect(created, isTrue, reason: auth.error ?? 'تعذّر إنشاء حساب الاختبار');

    final programs = LocalProgramRepository(store);
    await programs.save(
      auth.user!.id,
      SavedProgram(program: buildProgram(), progress: const ProgramProgress()),
    );

    final library = LibraryController(
      repository: programs,
      ai: AiProgramService(api: api),
    );
    await library.loadFor(auth.user!.id);

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
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
          home: screen,
        ),
      ),
    );

    // لا نستخدم pumpAndSettle: بعض الشاشات تحمل حركات دورية لا تهدأ.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  // -------------------------------------------------------------------
  // الهيكل وتبويباته الأربعة
  // -------------------------------------------------------------------

  group('الهيكل الرئيسي', () {
    const tabs = <(int, String)>[
      (0, 'الرئيسية'),
      (1, 'برامجي'),
      (2, 'تقدّمي'),
      (3, 'حسابي'),
    ];

    for (final (label, size) in geometries) {
      for (final (index, tabName) in tabs) {
        testWidgets('$tabName بلا فيضان على $label', (tester) async {
          await pump(tester, MainShell(initialIndex: index), size: size);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('كل التبويبات بلا فيضان على iPad عرضاً مع تكبير ×1.25',
        (tester) async {
      for (final (index, _) in tabs) {
        await pump(
          tester,
          MainShell(initialIndex: index),
          size: ipadLandscape,
          textScale: 1.25,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  // -------------------------------------------------------------------
  // شاشتا البرنامج والجلسة
  // -------------------------------------------------------------------

  group('البرنامج والجلسة', () {
    for (final (label, size) in geometries) {
      testWidgets('شاشة البرنامج بلا فيضان على $label', (tester) async {
        await pump(
          tester,
          const ProgramScreen(programId: 'p_ipad'),
          size: size,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('شاشة الجلسة بلا فيضان على $label', (tester) async {
        await pump(
          tester,
          const SessionScreen(programId: 'p_ipad', weekIndex: 0, dayIndex: 0),
          size: size,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('شاشة الجلسة بلا فيضان على iPad عرضاً مع تكبير ×1.25',
        (tester) async {
      await pump(
        tester,
        const SessionScreen(programId: 'p_ipad', weekIndex: 3, dayIndex: 4),
        size: ipadLandscape,
        textScale: 1.25,
      );
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------
  // النماذج الطويلة
  // -------------------------------------------------------------------

  group('النماذج', () {
    for (final (label, size) in geometries) {
      testWidgets('نموذج البرنامج الجديد بلا فيضان على $label', (tester) async {
        await pump(tester, const NewProgramScreen(), size: size);
        expect(tester.takeException(), isNull);
      });

      testWidgets('تعديل الحساب بلا فيضان على $label', (tester) async {
        await pump(tester, const EditProfileScreen(), size: size);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
