import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_container.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/automation/app_controller.dart';
import 'features/home_shell.dart';
import 'services/activity_log_repository.dart';
import 'services/settings_repository.dart';

class App extends StatelessWidget {
  const App({super.key, required this.container});

  final AppContainer container;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsRepository>.value(value: container.settings),
        ChangeNotifierProvider<AppController>.value(value: container.controller),
        ChangeNotifierProvider<ActivityLogRepository>.value(value: container.logs),
      ],
      child: Consumer<SettingsRepository>(
        builder: (context, settings, _) {
          final code = settings.value.localeCode;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Claude Auto Continue',
            theme: AppTheme.dark(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            locale: code == 'system' ? null : Locale(code),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (locale, supported) {
              final lang = locale?.languageCode ??
                  ui.PlatformDispatcher.instance.locale.languageCode;
              return Locale(lang == 'ar' ? 'ar' : 'en');
            },
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
