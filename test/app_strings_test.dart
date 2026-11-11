import 'package:claude_auto_continue/core/l10n/app_strings.dart';
import 'package:claude_auto_continue/models/automation_state.dart';
import 'package:claude_auto_continue/models/claude_ui_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic and English tables have exactly the same keys', () {
    expect(AppStrings.arabicKeys, AppStrings.englishKeys);
  });

  test('every automation and Claude state has a label in both languages', () {
    for (final code in ['ar', 'en']) {
      final s = AppStrings(Locale(code));
      for (final st in AutomationState.values) {
        expect(s.stateLabel(st), isNot(startsWith('state_')));
      }
      for (final st in ClaudeUiState.values) {
        expect(s.claudeState(st), isNot(startsWith('ui_')));
      }
    }
  });

  test('locale resolution prefers the setting, else the system language', () {
    expect(AppStrings.resolveCode('ar', 'en'), 'ar');
    expect(AppStrings.resolveCode('system', 'ar'), 'ar');
    expect(AppStrings.resolveCode('system', 'fr'), 'en');
  });
}
