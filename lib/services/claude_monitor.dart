import '../core/constants/ui_patterns.dart';
import '../core/utils/text_utils.dart';
import '../models/claude_ui_state.dart';
import '../models/screen_snapshot.dart';
import 'usage_limit_detector.dart';

/// Turns a raw [ScreenSnapshot] into a [ClaudeObservation].
/// Pure function of its input: no I/O, no timers, fully unit-testable.
class ClaudeMonitor {
  ClaudeMonitor({UsageLimitDetector? detector})
      : _detector = detector ?? UsageLimitDetector();

  final UsageLimitDetector _detector;

  ClaudeObservation observe(ScreenSnapshot? snap, {required DateTime now}) {
    if (snap == null) {
      return ClaudeObservation(state: ClaudeUiState.unknown, capturedAt: now);
    }
    if (!snap.accessibilityConnected) {
      return ClaudeObservation(
        state: ClaudeUiState.unavailable,
        capturedAt: now,
      );
    }
    if (!snap.claudeInForeground) {
      return ClaudeObservation(state: ClaudeUiState.notClaude, capturedAt: now);
    }

    final editables = snap.controls.where((c) => c.editable).toList();
    final composer = editables.length == 1 ? editables.first : null;
    final composerPresent = composer != null;
    final composerEnabled = composer != null && composer.enabled;
    final composerText = composer?.text;

    final stopVisible = snap.controls.any(
      (c) => c.clickable && c.matches(UiPatterns.stopLabels),
    );
    final continueVisible = snap.controls.any(
      (c) => c.clickable && c.enabled && c.matches(UiPatterns.continueLabels),
    );
    final limit = _detector.detect(snap.texts);

    ClaudeObservation make(ClaudeUiState state) => ClaudeObservation(
          state: state,
          capturedAt: now,
          continueButtonVisible: continueVisible,
          limitMessage: limit?.message,
          composerText: composerText,
          composerPresent: composerPresent,
          composerEnabled: composerEnabled,
          stopVisible: stopVisible,
        );

    if (_looksLikeLoginOrSecurity(snap)) return make(ClaudeUiState.needsLogin);
    if (!snap.online) return make(ClaudeUiState.offline);
    // Generating wins over limit text: chat history may quote the phrase.
    if (stopVisible) return make(ClaudeUiState.generating);
    if (limit != null) return make(ClaudeUiState.usageLimit);
    if (_hasErrorBanner(snap)) return make(ClaudeUiState.connectionError);
    if (composerEnabled) return make(ClaudeUiState.ready);
    return make(ClaudeUiState.unknown);
  }

  bool _looksLikeLoginOrSecurity(ScreenSnapshot snap) {
    if (snap.hasPasswordField) return true;
    if (snap.controls.any(
      (c) => c.clickable && c.matches(UiPatterns.loginLabels),
    )) {
      return true;
    }
    for (final raw in snap.texts) {
      if (raw.length > 80) continue;
      final n = normalizeText(raw);
      for (final p in UiPatterns.securityPhrases) {
        if (n.contains(p)) return true;
      }
    }
    return false;
  }

  bool _hasErrorBanner(ScreenSnapshot snap) {
    for (final raw in snap.texts) {
      if (raw.length > 120) continue;
      final n = normalizeText(raw);
      for (final p in UiPatterns.errorPhrases) {
        if (n.contains(p)) return true;
      }
    }
    return false;
  }
}
