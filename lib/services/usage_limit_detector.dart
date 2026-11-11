import '../core/constants/ui_patterns.dart';
import '../core/utils/text_utils.dart';

class UsageLimitMatch {
  const UsageLimitMatch({required this.message, required this.phrase});

  /// The (short) on-screen text that matched. Shown in the log.
  final String message;
  final String phrase;
}

/// Independent usage-limit recogniser.
///
/// It only ever READS text. It never decides when the limit resets: the end of
/// a wait is decided by the engine from the composer state, never from a
/// guessed time and never from the banner merely disappearing.
class UsageLimitDetector {
  UsageLimitDetector({List<String>? phrases, this.maxTextLength = 200})
      : phrases = phrases ?? UiPatterns.usageLimitPhrases;

  final List<String> phrases;

  /// Long texts are chat content, not banners. They are ignored to reduce false
  /// positives (this project's own conversation mentions "usage limit" a lot).
  final int maxTextLength;

  UsageLimitMatch? detect(Iterable<String> texts) {
    for (final raw in texts) {
      if (raw.length > maxTextLength) continue;
      final n = normalizeText(raw);
      if (n.isEmpty) continue;
      for (final p in phrases) {
        if (n.contains(p)) {
          return UsageLimitMatch(message: raw.trim(), phrase: p);
        }
      }
    }
    return null;
  }
}
