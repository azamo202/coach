import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/program_repository.dart';
import 'data/repositories/subscription_repository.dart';
import 'data/services/ai_program_service.dart';
import 'data/services/api_client.dart';
import 'data/services/health_service.dart';
import 'data/services/iap_service.dart';
import 'data/services/local_store.dart';
import 'state/auth_controller.dart';
import 'state/health_controller.dart';
import 'state/library_controller.dart';
import 'state/subscription_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // حارس إعداد: نسخة إصدار تخاطب عنواناً محلياً أو غير مشفّر هي تطبيق
  // ميت في يد المستخدم. نكسر البناء في وضع التطوير حيث يُرى الخطأ، ولا
  // نُسقط التطبيق في يد مستخدم حقيقي — هناك نكتفي بتسجيله.
  assert(
    () {
      if (kReleaseMode && !AppConfig.isProductionApi) {
        throw StateError(
          'API_BASE_URL غير صالح للإنتاج: ${AppConfig.apiBaseUrl}\n'
          'ابنِ بـ: flutter build ipa --dart-define=API_BASE_URL=https://...',
        );
      }
      return true;
    }(),
  );
  if (kReleaseMode && !AppConfig.isProductionApi) {
    debugPrint('FATAL CONFIG: API_BASE_URL = ${AppConfig.apiBaseUrl}');
  }

  if (!kIsWeb) {
    try {
      // قفل الطول على أندرويد فقط.
      //
      // على iOS الاتجاه يُحسم في `Info.plist` لكل عائلة جهاز: الطول وحده
      // على iPhone، والاتجاهات الأربعة على iPad. وهذا ليس تفضيلاً بل
      // اضطرار — `setPreferredOrientations` يتجاهله iPadOS في أي تطبيق
      // يدعم تعدّد المهام، فينتج تطبيق يقول إنه مقفول والنظام يدوّره
      // على أي حال. مصدر واحد للحقيقة أفضل من قفلٍ لا يُطاع.
      if (Platform.isAndroid) {
        await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
      SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);
    } catch (error) {
      debugPrint('SystemChrome configuration skipped: $error');
    }
  }

  final store = await LocalStore.instance();

  final ApiClient api = ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final localPrograms = LocalProgramRepository(store);

  final AuthRepository authRepository = RemoteAuthRepository(api, store);

  final ProgramRepository programRepository =
      RemoteProgramRepository(api, localPrograms);

  final aiService = AiProgramService(api: api);

  final iapService = IapService();
  final subscriptionRepository = SubscriptionRepository(api);

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalStore>.value(value: store),
        Provider<ApiClient>.value(value: api),
        Provider<AiProgramService>.value(value: aiService),
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(
            repository: authRepository,
            store: store,
          ),
        ),
        ChangeNotifierProvider<LibraryController>(
          create: (_) => LibraryController(
            repository: programRepository,
            ai: aiService,
          ),
        ),
        ChangeNotifierProvider<HealthController>(
          create: (_) => HealthController(
            service: HealthService(),
            store: store,
          ),
        ),
        // `lazy: false` مقصود: StoreKit لا يسلّم العمليات المعلّقة إلا بعد
        // أن يبدأ أحد الإصغاء. لو انتظرنا أول قراءة للمزوّد لضاعت دفعة
        // اكتملت بينما كان التطبيق مغلقاً.
        ChangeNotifierProvider<SubscriptionController>(
          lazy: false,
          create: (_) => SubscriptionController(
            iap: iapService,
            repository: subscriptionRepository,
            store: store,
          )..start(),
        ),
      ],
      child: const TatawwarApp(),
    ),
  );
}
