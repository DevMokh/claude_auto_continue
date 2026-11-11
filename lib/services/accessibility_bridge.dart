import '../core/constants/ui_patterns.dart';
import '../models/action_result.dart';
import '../models/screen_snapshot.dart';
import 'native_channel.dart';

/// Everything the engine needs from the outside world. Faked in tests.
abstract class ScreenBridge {
  Future<ScreenSnapshot?> snapshot();
  Future<ActionResult> typeText(String text);
  Future<ActionResult> clickSend();
  Future<ActionResult> clickContinue();
}

/// Real implementation on top of the Kotlin AccessibilityService.
///
/// Native side re-verifies every action (single visible match, enabled,
/// automation gate open, rate limit) and refuses when unsure.
class AccessibilityBridge implements ScreenBridge {
  AccessibilityBridge(this._native);

  final NativeChannel _native;

  @override
  Future<ScreenSnapshot?> snapshot() async {
    final raw = await _native.getSnapshot();
    if (raw == null || raw['error'] != null) return null;
    return ScreenSnapshot.fromMap(raw, DateTime.now());
  }

  @override
  Future<ActionResult> typeText(String text) => _native.typeText(text);

  @override
  Future<ActionResult> clickSend() =>
      _native.clickByLabels(UiPatterns.sendLabels);

  @override
  Future<ActionResult> clickContinue() =>
      _native.clickByLabels(UiPatterns.continueLabels);
}
