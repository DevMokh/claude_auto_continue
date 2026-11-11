import '../core/utils/text_utils.dart';

/// One interactive element (clickable or editable) visible in the Claude window.
class ControlInfo {
  const ControlInfo({
    this.desc = '',
    this.text = '',
    this.className = '',
    this.viewId = '',
    this.editable = false,
    this.clickable = false,
    this.enabled = true,
  });

  factory ControlInfo.fromMap(Map<dynamic, dynamic> m) => ControlInfo(
        desc: (m['desc'] as String?) ?? '',
        text: (m['text'] as String?) ?? '',
        className: (m['className'] as String?) ?? '',
        viewId: (m['viewId'] as String?) ?? '',
        editable: m['editable'] == true,
        clickable: m['clickable'] == true,
        enabled: m['enabled'] != false,
      );

  final String desc;
  final String text;
  final String className;
  final String viewId;
  final bool editable;
  final bool clickable;
  final bool enabled;

  /// True when the description or text EQUALS one of [labels] (already normalised).
  bool matches(Iterable<String> labels) {
    final d = normalizeText(desc);
    final t = normalizeText(text);
    for (final l in labels) {
      if (l == d || l == t) return true;
    }
    return false;
  }
}

/// What the accessibility service saw at one instant. Contains no credentials:
/// password fields are skipped natively.
class ScreenSnapshot {
  const ScreenSnapshot({
    required this.capturedAt,
    this.accessibilityConnected = true,
    this.claudeInForeground = true,
    this.online = true,
    this.texts = const <String>[],
    this.controls = const <ControlInfo>[],
    this.hasPasswordField = false,
  });

  factory ScreenSnapshot.fromMap(Map<dynamic, dynamic> m, DateTime capturedAt) {
    final texts = <String>[];
    final rawTexts = m['texts'];
    if (rawTexts is List) {
      for (final t in rawTexts) {
        if (t != null) texts.add(t.toString());
      }
    }
    final controls = <ControlInfo>[];
    final rawControls = m['controls'];
    if (rawControls is List) {
      for (final c in rawControls) {
        if (c is Map) controls.add(ControlInfo.fromMap(c));
      }
    }
    return ScreenSnapshot(
      capturedAt: capturedAt,
      accessibilityConnected: m['accessibilityConnected'] != false,
      claudeInForeground: m['claudeInForeground'] == true,
      online: m['online'] != false,
      texts: texts,
      controls: controls,
      hasPasswordField: m['hasPasswordField'] == true,
    );
  }

  final DateTime capturedAt;
  final bool accessibilityConnected;
  final bool claudeInForeground;
  final bool online;
  final List<String> texts;
  final List<ControlInfo> controls;
  final bool hasPasswordField;
}
