import 'package:claude_auto_continue/models/claude_ui_state.dart';
import 'package:claude_auto_continue/models/screen_snapshot.dart';
import 'package:claude_auto_continue/services/claude_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  final monitor = ClaudeMonitor();
  final now = DateTime(2026);

  ClaudeUiState stateOf(ScreenSnapshot? snap) => monitor.observe(snap, now: now).state;

  test('ready: enabled composer, no stop button, no banner', () {
    expect(stateOf(Snaps.ready()), ClaudeUiState.ready);
  });

  test('generating: stop button visible', () {
    expect(stateOf(Snaps.generating()), ClaudeUiState.generating);
  });

  test('usage limit: banner with disabled composer', () {
    final o = monitor.observe(Snaps.limit(), now: now);
    expect(o.state, ClaudeUiState.usageLimit);
    expect(o.limitMessage, contains('usage limit'));
  });

  test('usage limit banner wins even if composer looks enabled', () {
    expect(stateOf(Snaps.limitWithEnabledComposer()), ClaudeUiState.usageLimit);
  });

  test('generating wins over limit text (chat history may quote it)', () {
    expect(stateOf(Snaps.generatingWithQuotedLimit()), ClaudeUiState.generating);
  });

  test('not claude / accessibility off / null', () {
    expect(stateOf(Snaps.notClaude()), ClaudeUiState.notClaude);
    expect(stateOf(Snaps.accessibilityOff()), ClaudeUiState.unavailable);
    expect(stateOf(null), ClaudeUiState.unknown);
  });

  test('login, captcha and password field all mean needsLogin', () {
    expect(stateOf(Snaps.login()), ClaudeUiState.needsLogin);
    expect(stateOf(Snaps.captcha()), ClaudeUiState.needsLogin);
    expect(stateOf(Snaps.passwordScreen()), ClaudeUiState.needsLogin);
  });

  test('offline and connection error are distinguished from ready', () {
    expect(stateOf(Snaps.offline()), ClaudeUiState.offline);
    expect(stateOf(Snaps.networkError()), ClaudeUiState.connectionError);
  });

  test('unrecognised screen is unknown, never ready', () {
    expect(stateOf(Snaps.unknown()), ClaudeUiState.unknown);
  });

  test('continue button is reported only when clickable and enabled', () {
    expect(monitor.observe(Snaps.withContinueButton(), now: now).continueButtonVisible, isTrue);
    expect(monitor.observe(Snaps.ready(), now: now).continueButtonVisible, isFalse);
  });

  test('composer text is exposed for send verification', () {
    final o = monitor.observe(Snaps.ready(composerText: 'كمل'), now: now);
    expect(o.composerText, 'كمل');
    expect(o.composerEnabled, isTrue);
  });
}
