import 'package:claude_auto_continue/services/usage_limit_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final detector = UsageLimitDetector();

  test('detects an English banner', () {
    final m = detector.detect(['Hello', 'You have reached your usage limit.']);
    expect(m, isNotNull);
    expect(m!.message, contains('usage limit'));
  });

  test('detects an Arabic banner', () {
    expect(detector.detect(['وصلت إلى حد الاستخدام، سيتجدد لاحقًا']), isNotNull);
  });

  test('handles curly apostrophes and case', () {
    expect(detector.detect(['You\u2019ve HIT YOUR LIMIT for now']), isNotNull);
  });

  test('ignores long chat content that merely mentions the phrase', () {
    final long = 'We talked about the usage limit. ' * 20;
    expect(detector.detect([long]), isNull);
  });

  test('returns null when nothing matches', () {
    expect(detector.detect(['Hello', 'How can I help?', '']), isNull);
  });
}
