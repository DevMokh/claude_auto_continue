class AppSettings {
  const AppSettings({
    this.autoResume = true,
    this.maxContinueAttempts = 20,
    this.checkIntervalSec = 5,
    this.notificationsEnabled = true,
    this.clickContinueEnabled = true,
    this.sendContinueEnabled = true,
    this.autoStopOnProblem = true,
    this.keepScreenOn = true,
    this.localeCode = 'system',
  });

  final bool autoResume;
  final int maxContinueAttempts;
  final int checkIntervalSec;
  final bool notificationsEnabled;
  final bool clickContinueEnabled;
  final bool sendContinueEnabled;
  final bool autoStopOnProblem;
  final bool keepScreenOn;

  /// 'system' | 'ar' | 'en'
  final String localeCode;

  AppSettings copyWith({
    bool? autoResume,
    int? maxContinueAttempts,
    int? checkIntervalSec,
    bool? notificationsEnabled,
    bool? clickContinueEnabled,
    bool? sendContinueEnabled,
    bool? autoStopOnProblem,
    bool? keepScreenOn,
    String? localeCode,
  }) {
    return AppSettings(
      autoResume: autoResume ?? this.autoResume,
      maxContinueAttempts: maxContinueAttempts ?? this.maxContinueAttempts,
      checkIntervalSec: checkIntervalSec ?? this.checkIntervalSec,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      clickContinueEnabled: clickContinueEnabled ?? this.clickContinueEnabled,
      sendContinueEnabled: sendContinueEnabled ?? this.sendContinueEnabled,
      autoStopOnProblem: autoStopOnProblem ?? this.autoStopOnProblem,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      localeCode: localeCode ?? this.localeCode,
    );
  }
}
