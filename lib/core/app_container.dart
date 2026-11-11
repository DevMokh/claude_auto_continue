import 'package:shared_preferences/shared_preferences.dart';

import '../features/automation/app_controller.dart';
import '../services/accessibility_bridge.dart';
import '../services/activity_log_repository.dart';
import '../services/auto_continue_engine.dart';
import '../services/claude_monitor.dart';
import '../services/engine_state_store.dart';
import '../services/native_channel.dart';
import '../services/notification_service.dart';
import '../services/settings_repository.dart';
import '../services/sqlite_log_repository.dart';

/// Builds the object graph once. Kept alive for the whole process so the engine
/// keeps running after the Activity is closed (the native side keeps the Flutter
/// engine cached while the foreground service runs).
class AppContainer {
  AppContainer._({
    required this.settings,
    required this.logs,
    required this.engine,
    required this.controller,
  });

  final SettingsRepository settings;
  final ActivityLogRepository logs;
  final AutoContinueEngine engine;
  final AppController controller;

  static AppContainer? _instance;

  static Future<AppContainer> create() async {
    final existing = _instance;
    if (existing != null) return existing;

    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsRepository.load(prefs);

    ActivityLogRepository logs;
    try {
      logs = await SqliteLogRepository.open();
    } catch (_) {
      logs = InMemoryLogRepository();
    }

    final store = PrefsEngineStateStore(prefs);
    final native = NativeChannel();
    final notifications = NotificationService(native);

    late AppController controller;
    final engine = AutoContinueEngine(
      bridge: AccessibilityBridge(native),
      monitor: ClaudeMonitor(),
      logs: logs,
      store: store,
      settings: () => settings.value,
      onNotice: (n) => controller.onEngineNotice(n),
    );
    controller = AppController(
      engine: engine,
      native: native,
      settingsRepo: settings,
      store: store,
      notifications: notifications,
    );
    await controller.init();
    await controller.restore();

    final container = AppContainer._(
      settings: settings,
      logs: logs,
      engine: engine,
      controller: controller,
    );
    _instance = container;
    return container;
  }
}
