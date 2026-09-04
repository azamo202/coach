import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/program_repository.dart';
import 'data/services/ai_program_service.dart';
import 'data/services/api_client.dart';
import 'data/services/health_service.dart';
import 'data/services/local_store.dart';
import 'state/auth_controller.dart';
import 'state/health_controller.dart';
import 'state/library_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);
    } catch (error) {
      debugPrint('SystemChrome configuration skipped: $error');
    }
  }

  final store = await LocalStore.instance();

  // في الوضع المحلي لا ننشئ عميل شبكة للباك إند إطلاقاً.
  final ApiClient? api =
      AppConfig.isOfflineMode ? null : ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final localPrograms = LocalProgramRepository(store);

  final AuthRepository authRepository = api == null
      ? LocalAuthRepository(store)
      : RemoteAuthRepository(api, store);

  final ProgramRepository programRepository =
      api == null ? localPrograms : RemoteProgramRepository(api, localPrograms);

  final aiService = AiProgramService(api: api);

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalStore>.value(value: store),
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
      ],
      child: const TatawwarApp(),
    ),
  );
}
