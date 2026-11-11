import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/l10n/app_strings.dart';
import '../../models/app_settings.dart';
import '../../models/persisted_engine_state.dart';
import '../../services/auto_continue_engine.dart';
import '../../services/engine_state_store.dart';
import '../../services/native_channel.dart';
import '../../services/notification_service.dart';
import '../../services/settings_repository.dart';

enum StartResult { started, needsAccessibility, claudeMissing }

class SetupStatus {
  const SetupStatus({
    this.accessibilityConnected = false,
    this.accessibilityEnabled = false,
    this.claudeInstalled = false,
    this.notificationsGranted = false,
    this.batteryIgnored = false,
  });

  final bool accessibilityConnected;
  final bool accessibilityEnabled;
  final bool claudeInstalled;
  final bool notificationsGranted;
  final bool batteryIgnored;
}

/// Glue between the engine and Android: permissions, the foreground service,
/// notifications, the native "automation gate" and the stop button.
class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController({
    required this.engine,
    required this.native,
    required this.settingsRepo,
    required this.store,
    required this.notifications,
  });

  final AutoContinueEngine engine;
  final NativeChannel native;
  final SettingsRepository settingsRepo;
  final EngineStateStore store;
  final NotificationService notifications;

  SetupStatus setup = const SetupStatus();
  bool _nativeActive = false;
  AppSettings _lastSettings = const AppSettings();

  AppSettings get settings => settingsRepo.value;

  Future<void> init() async {
    _lastSettings = settings;
    WidgetsBinding.instance.addObserver(this);
    native.setStopHandler(_onStopFromNotification);
    engine.addListener(_onEngineChanged);
    settingsRepo.addListener(_onSettingsChanged);
    await refreshSetup();
  }

  /// Restores a session that was running when the process died.
  Future<void> restore() async {
    final p = await store.load();
    if (!p.running) return;
    if (settings.autoResume) {
      await engine.start(resumed: true);
    } else {
      await store.save(
        PersistedEngineState(
          running: false,
          state: 'stopped',
          episodeId: p.episodeId,
          limitStartedAt: p.limitStartedAt,
          sentInEpisode: p.sentInEpisode,
          continueCount: p.continueCount,
          lastSendAt: p.lastSendAt,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshSetup());
    }
  }

  Future<void> refreshSetup() async {
    final acs = await native.accessibilityStatus();
    setup = SetupStatus(
      accessibilityConnected: acs.connected,
      accessibilityEnabled: acs.enabled,
      claudeInstalled: await native.isClaudeInstalled(),
      notificationsGranted: await native.hasNotificationPermission(),
      batteryIgnored: await native.isIgnoringBatteryOptimizations(),
    );
    notifyListeners();
  }

  Future<StartResult> start() async {
    await refreshSetup();
    if (!setup.accessibilityConnected) return StartResult.needsAccessibility;
    if (!setup.claudeInstalled) return StartResult.claudeMissing;
    if (!setup.notificationsGranted && settings.notificationsEnabled) {
      await native.requestNotificationPermission();
      await refreshSetup();
    }
    await _activateNative();
    await engine.start();
    return StartResult.started;
  }

  Future<void> stop() => engine.stop();

  Future<void> _onStopFromNotification() async {
    // Close the native gate first so no action can slip through.
    await native.setAutomationEnabled(false);
    await engine.stop(reason: 'stopped_notification');
  }

  void _onEngineChanged() {
    if (engine.isRunning && !_nativeActive) {
      unawaited(_activateNative());
    } else if (!engine.isRunning && _nativeActive) {
      unawaited(_deactivateNative());
    }
    if (engine.isRunning) {
      unawaited(_updateOngoing());
    }
    notifyListeners();
  }

  void _onSettingsChanged() {
    final s = settings;
    if (_nativeActive && s.keepScreenOn != _lastSettings.keepScreenOn) {
      unawaited(native.setKeepScreenOn(s.keepScreenOn));
    }
    _lastSettings = s;
    if (engine.isRunning) unawaited(_updateOngoing());
    notifyListeners();
  }

  Future<void> _activateNative() async {
    if (_nativeActive) return;
    _nativeActive = true;
    final str = _strings();
    await native.setAutomationEnabled(true);
    await native.setRunningFlag(true);
    await native.startForeground(str.t('app_name'), str.stateLabel(engine.state));
    await native.setKeepScreenOn(settings.keepScreenOn);
  }

  Future<void> _deactivateNative() async {
    _nativeActive = false;
    await native.setAutomationEnabled(false);
    await native.setRunningFlag(false);
    await native.setKeepScreenOn(false);
    await native.stopForeground();
  }

  Future<void> _updateOngoing() {
    final str = _strings();
    final count = engine.continueCount;
    final text = count > 0
        ? '${str.stateLabel(engine.state)} • $count ${str.t('notif_sent_suffix')}'
        : str.stateLabel(engine.state);
    return notifications.updateOngoing(str.t('app_name'), text);
  }

  /// Called by the engine for events worth a heads-up.
  void onEngineNotice(EngineNotice notice) {
    if (!settings.notificationsEnabled) return;
    final str = _strings();
    switch (notice.kind) {
      case EngineNoticeKind.attention:
        unawaited(notifications.alert(
          str.t('notif_title_attention'),
          str.attentionText(notice.code),
        ));
        break;
      case EngineNoticeKind.usageAvailableManual:
        unawaited(notifications.alert(
          str.t('notif_title_info'),
          str.t('log_usage_available_send_disabled'),
        ));
        break;
      case EngineNoticeKind.stopped:
        unawaited(notifications.alert(
          str.t('notif_title_info'),
          str.t('log_stopped_max_attempts'),
        ));
        break;
      case EngineNoticeKind.waiting:
      case EngineNoticeKind.sent:
        break; // shown through the ongoing notification only
    }
  }

  AppStrings _strings() {
    final code = AppStrings.resolveCode(
      settings.localeCode,
      ui.PlatformDispatcher.instance.locale.languageCode,
    );
    return AppStrings(Locale(code));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    engine.removeListener(_onEngineChanged);
    settingsRepo.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
