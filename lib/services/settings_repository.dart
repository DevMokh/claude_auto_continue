import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/text_utils.dart';
import '../models/app_settings.dart';

class SettingsRepository extends ChangeNotifier {
  SettingsRepository._(this._prefs, this._value);

  final SharedPreferences _prefs;
  AppSettings _value;

  AppSettings get value => _value;

  static Future<SettingsRepository> load([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    const d = AppSettings();
    final settings = AppSettings(
      autoResume: p.getBool('s.autoResume') ?? d.autoResume,
      maxContinueAttempts: clampInt(
        p.getInt('s.maxAttempts') ?? d.maxContinueAttempts,
        1,
        100,
      ),
      checkIntervalSec: clampInt(
        p.getInt('s.interval') ?? d.checkIntervalSec,
        2,
        60,
      ),
      notificationsEnabled:
          p.getBool('s.notifications') ?? d.notificationsEnabled,
      clickContinueEnabled: p.getBool('s.clickContinue') ?? d.clickContinueEnabled,
      sendContinueEnabled: p.getBool('s.sendContinue') ?? d.sendContinueEnabled,
      autoStopOnProblem: p.getBool('s.autoStop') ?? d.autoStopOnProblem,
      keepScreenOn: p.getBool('s.keepScreen') ?? d.keepScreenOn,
      localeCode: p.getString('s.locale') ?? d.localeCode,
    );
    return SettingsRepository._(p, settings);
  }

  Future<void> update(AppSettings next) async {
    _value = next;
    notifyListeners();
    await _prefs.setBool('s.autoResume', next.autoResume);
    await _prefs.setInt('s.maxAttempts', next.maxContinueAttempts);
    await _prefs.setInt('s.interval', next.checkIntervalSec);
    await _prefs.setBool('s.notifications', next.notificationsEnabled);
    await _prefs.setBool('s.clickContinue', next.clickContinueEnabled);
    await _prefs.setBool('s.sendContinue', next.sendContinueEnabled);
    await _prefs.setBool('s.autoStop', next.autoStopOnProblem);
    await _prefs.setBool('s.keepScreen', next.keepScreenOn);
    await _prefs.setString('s.locale', next.localeCode);
  }
}
