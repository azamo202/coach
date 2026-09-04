import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';

/// جذر التطبيق: ثيم داكن، لغة عربية، واتجاه من اليمين لليسار.
class TatawwarApp extends StatelessWidget {
  const TatawwarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // نثبّت الاتجاه ومقياس الخط حتى لا ينكسر التصميم على الأجهزة
        // المضبوطة على خط كبير جداً.
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.25,
        );
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: media.copyWith(textScaler: scale),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
