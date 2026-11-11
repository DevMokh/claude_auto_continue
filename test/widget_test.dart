import 'package:claude_auto_continue/core/l10n/app_strings.dart';
import 'package:claude_auto_continue/core/theme/app_theme.dart';
import 'package:claude_auto_continue/models/automation_state.dart';
import 'package:claude_auto_continue/shared/widgets/state_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Locale locale) => MaterialApp(
      theme: AppTheme.dark(),
      locale: locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(
        body: Center(
          child: StateBadge(state: AutomationState.waitingForUsageReset),
        ),
      ),
    );

void main() {
  testWidgets('state badge renders in English', (tester) async {
    await tester.pumpWidget(_host(const Locale('en')));
    expect(find.text('Waiting for Usage Reset'), findsOneWidget);
  });

  testWidgets('state badge renders in Arabic with RTL layout', (tester) async {
    await tester.pumpWidget(_host(const Locale('ar')));
    expect(find.text('بانتظار تجدد الاستخدام'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.byType(StateBadge)));
    expect(dir, TextDirection.rtl);
  });
}
