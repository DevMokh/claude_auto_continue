import 'package:flutter/services.dart';

import '../core/constants/engine_constants.dart';
import '../models/action_result.dart';

class AccessibilityStatus {
  const AccessibilityStatus({this.connected = false, this.enabled = false});

  /// The service instance is alive and bound.
  final bool connected;

  /// The service is switched on in system settings (may not be bound yet).
  final bool enabled;
}

/// Thin, failure-tolerant wrapper over the Kotlin side. Every method returns a
/// safe default instead of throwing, so a missing plugin never crashes the UI.
class NativeChannel {
  NativeChannel() : _channel = const MethodChannel(EngineConstants.nativeChannel);

  final MethodChannel _channel;

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _callMap(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  void setStopHandler(Future<void> Function() handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onStopRequested') {
        await handler();
      }
      return null;
    });
  }

  Future<AccessibilityStatus> accessibilityStatus() async {
    final m = await _callMap('accessibilityStatus');
    if (m == null) return const AccessibilityStatus();
    return AccessibilityStatus(
      connected: m['connected'] == true,
      enabled: m['enabled'] == true,
    );
  }

  Future<void> openAccessibilitySettings() =>
      _call<bool>('openAccessibilitySettings');

  Future<bool> isClaudeInstalled() async =>
      (await _call<bool>('isClaudeInstalled')) ?? false;

  Future<bool> openClaude() async => (await _call<bool>('openClaude')) ?? false;

  Future<Map<String, dynamic>?> getSnapshot() => _callMap('getSnapshot');

  Future<ActionResult> typeText(String text) async =>
      ActionResult.fromMap(await _callMap('typeText', {'text': text}));

  Future<ActionResult> clickByLabels(List<String> labels) async =>
      ActionResult.fromMap(await _callMap('clickByLabels', {'labels': labels}));

  Future<String> dumpTree() async =>
      (await _call<String>('dumpTree')) ?? 'Native bridge unavailable.';

  Future<void> setAutomationEnabled(bool enabled) =>
      _call<bool>('setAutomationEnabled', {'enabled': enabled});

  Future<void> setRunningFlag(bool running) =>
      _call<bool>('setRunningFlag', {'running': running});

  Future<bool> startForeground(String title, String text) async =>
      (await _call<bool>('startForeground', {'title': title, 'text': text})) ??
      false;

  Future<void> stopForeground() => _call<bool>('stopForeground');

  Future<void> updateNotification(String title, String text) =>
      _call<bool>('updateNotification', {'title': title, 'text': text});

  Future<void> notifyAttention(String title, String text) =>
      _call<bool>('notifyAttention', {'title': title, 'text': text});

  Future<bool> hasNotificationPermission() async =>
      (await _call<bool>('hasNotificationPermission')) ?? false;

  Future<bool> requestNotificationPermission() async =>
      (await _call<bool>('requestNotificationPermission')) ?? false;

  Future<bool> isIgnoringBatteryOptimizations() async =>
      (await _call<bool>('isIgnoringBatteryOptimizations')) ?? false;

  Future<void> openBatterySettings() => _call<bool>('openBatterySettings');

  Future<void> setKeepScreenOn(bool enabled) =>
      _call<bool>('setKeepScreenOn', {'enabled': enabled});
}
