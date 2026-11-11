import 'package:claude_auto_continue/core/constants/engine_constants.dart';
import 'package:claude_auto_continue/models/action_result.dart';
import 'package:claude_auto_continue/models/app_settings.dart';
import 'package:claude_auto_continue/models/automation_state.dart';
import 'package:claude_auto_continue/models/persisted_engine_state.dart';
import 'package:claude_auto_continue/services/auto_continue_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// All tests below use MOCK screens (see support/fakes.dart). They verify the
/// decision logic only. They do NOT prove the real Claude app behaves this way.
void main() {
  const cont = EngineConstants.continueText;

  /// Drives a harness into a confirmed wait episode.
  Future<Harness> inWaitingEpisode({
    EngineTuning tuning = const EngineTuning(),
    AppSettings settings = const AppSettings(),
  }) async {
    final h = Harness(tuning: tuning, settings: settings);
    await h.engine.start();
    h.bridge.current = Snaps.limit();
    await h.ticks(2);
    expect(h.engine.state, AutomationState.waitingForUsageReset);
    return h;
  }

  group('detection of Claude state', () {
    test('Claude working: no action, state follows the screen', () async {
      final h = Harness();
      await h.engine.start();
      h.bridge.current = Snaps.generating();
      await h.ticks(3);
      expect(h.engine.state, AutomationState.claudeWorking);
      expect(h.bridge.actions, isEmpty);
    });

    test('normal end of response goes back to monitoring without sending', () async {
      final h = Harness();
      await h.engine.start();
      h.bridge.current = Snaps.generating();
      await h.ticks(1);
      h.bridge.current = Snaps.ready();
      await h.ticks(3);
      expect(h.engine.state, AutomationState.monitoring);
      expect(h.bridge.actions, isEmpty);
      expect(h.logs.hasCode('response_finished'), isTrue);
    });
  });

  group('usage limit and renewal', () {
    test('limit must be seen twice before a wait episode starts', () async {
      final h = Harness();
      await h.engine.start();
      h.bridge.current = Snaps.limit();
      await h.ticks(1);
      expect(h.engine.state, AutomationState.monitoring);
      await h.ticks(1);
      expect(h.engine.state, AutomationState.waitingForUsageReset);
      expect(h.logs.hasCode('usage_limit_detected'), isTrue);
      expect(h.logs.hasCode('wait_started'), isTrue);
    });

    test('wait time is tracked and no send happens during the ban', () async {
      final h = await inWaitingEpisode();
      await h.ticks(20);
      expect(h.engine.waitElapsed, isNotNull);
      expect(h.engine.waitElapsed!.inSeconds, greaterThan(0));
      expect(h.bridge.actions, isEmpty);
    });

    test('limit banner vanishing alone is not enough (unknown screen)', () async {
      final h = await inWaitingEpisode();
      h.bridge.current = Snaps.unknown();
      await h.ticks(10);
      expect(h.bridge.actions, isEmpty);
      expect(h.engine.state, AutomationState.waitingForUsageReset);
    });

    test('ready for N consecutive checks then ONE send of "كمل"', () async {
      final h = await inWaitingEpisode();
      h.bridge.current = Snaps.ready();
      await h.ticks(2);
      expect(h.bridge.actions, isEmpty, reason: 'not yet stable');
      await h.ticks(1);
      expect(h.bridge.actions, ['type:$cont', 'send']);
      expect(h.engine.continueCount, 1);
      expect(h.engine.state, AutomationState.waitingForResponse);
      expect(h.notices.any((n) => n.kind == EngineNoticeKind.sent), isTrue);
    });

    test('a flickering screen resets the stability counter', () async {
      final h = await inWaitingEpisode();
      h.bridge.current = Snaps.ready();
      await h.ticks(2);
      h.bridge.current = Snaps.limit();
      await h.ticks(1);
      h.bridge.current = Snaps.ready();
      await h.ticks(2);
      expect(h.bridge.actions, isEmpty);
      await h.ticks(1);
      expect(h.sends.length, 2);
    });

    test('final verification failing sends nothing and returns to waiting', () async {
      final h = await inWaitingEpisode();
      h.bridge.current = Snaps.ready();
      await h.ticks(2);
      h.bridge.queue.addAll([Snaps.ready(), Snaps.limit()]);
      await h.ticks(1);
      expect(h.bridge.actions, isEmpty);
      expect(h.engine.state, AutomationState.waitingForUsageReset);
      expect(h.logs.hasCode('verification_failed'), isTrue);
    });
  });

  group('no duplicate sends', () {
    test('many extra ticks after sending never send again', () async {
      final h = await inWaitingEpisode();
      h.bridge.current = Snaps.ready();
      await h.ticks(3);
      expect(h.sends.length, 2);
      await h.ticks(1); // generating
      expect(h.engine.state, AutomationState.claudeWorking);
      h.bridge.current = Snaps.ready();
      await h.ticks(10);
      expect(h.sends.length, 2, reason: 'still exactly one type + one send');
      expect(h.engine.continueCount, 1);
      expect(h.engine.state, AutomationState.monitoring);
    });

    test('never sends while Claude is writing', () async {
      final h = await inWaitingEpisode();
      h.bridge.current = Snaps.generating();
      await h.ticks(15);
      expect(h.bridge.actions, isEmpty);
      expect(h.engine.state, AutomationState.claudeWorking);
    });

    test('rapid repeated ticks cannot overlap into two sends', () async {
      final h = await inWaitingEpisode();
      h.bridge.current = Snaps.ready();
      await h.ticks(2);
      await Future.wait([h.engine.tick(), h.engine.tick(), h.engine.tick()]);
      expect(h.sends.length, 2);
    });

    test('a new limit later starts a new episode that may send again', () async {
      final h = await inWaitingEpisode();
      h.bridge.current = Snaps.ready();
      await h.ticks(3);
      await h.ticks(1);
      h.bridge.current = Snaps.ready();
      await h.ticks(1);
      h.bridge.current = Snaps.limit();
      await h.ticks(2);
      expect(h.engine.state, AutomationState.waitingForUsageReset);
      h.bridge.current = Snaps.ready();
      h.clock = h.clock.add(const Duration(minutes: 5));
      await h.ticks(3);
      expect(h.engine.continueCount, 2);
    });

    test('maximum attempts stops the engine instead of sending', () async {
      final h = await inWaitingEpisode(
        settings: const AppSettings(maxContinueAttempts: 1),
      );
      h.bridge.current = Snaps.ready();
      await h.ticks(3);
      expect(h.engine.continueCount, 1);
      await h.ticks(1);
      h.bridge.current = Snaps.ready();
      await h.ticks(1);
      h.bridge.current = Snaps.limit();
      await h.ticks(2);
      h.bridge.current = Snaps.ready();
      h.clock = h.clock.add(const Duration(minutes: 5));
      await h.ticks(3);
      expect(h.engine.state, AutomationState.stopped);
      expect(h.engine.isRunning, isFalse);
      expect(h.sends.length, 2);
    });
  });

  group('Continue button', () {
    test('is pressed once, not repeatedly', () async {
      final h = Harness();
      h.bridge.current = Snaps.withContinueButton();
      h.bridge.afterContinue = Snaps.withContinueButton();
      await h.engine.start();
      await h.ticks(4);
      expect(h.bridge.actions, ['continue']);
      expect(h.engine.continueCount, 1);
      expect(h.engine.state, AutomationState.waitingForResponse);
    });

    test('is ignored when the setting is off', () async {
      final h = Harness(settings: const AppSettings(clickContinueEnabled: false));
      h.bridge.current = Snaps.withContinueButton();
      await h.engine.start();
      await h.ticks(3);
      expect(h.bridge.actions, isEmpty);
    });

    test('a failed press raises attention and is not blindly retried', () async {
      final h = Harness();
      h.bridge.current = Snaps.withContinueButton();
      h.bridge.continueResult = const ActionResult(false, 'ambiguous');
      await h.engine.start();
      await h.ticks(5);
      expect(h.bridge.actions, ['continue']);
      expect(h.engine.state, AutomationState.needsAttention);
      expect(h.engine.isRunning, isFalse);
    });
  });

  group('send failures', () {
    test('typing refused: attention, halted, no click, no retry', () async {
      final h = await inWaitingEpisode();
      h.bridge.typeResult = const ActionResult(false, 'composer_not_empty');
      h.bridge.current = Snaps.ready();
      await h.ticks(3);
      expect(h.engine.state, AutomationState.needsAttention);
      expect(h.engine.attentionReason, 'send_failed');
      expect(h.engine.isRunning, isFalse);
      await h.ticks(10);
      expect(h.bridge.actions, ['type:$cont']);
    });

    test('send click refused: attention, halted', () async {
      final h = await inWaitingEpisode();
      h.bridge.sendResult = const ActionResult(false, 'not_found');
      h.bridge.current = Snaps.ready();
      await h.ticks(3);
      expect(h.engine.state, AutomationState.needsAttention);
      expect(h.engine.isRunning, isFalse);
      expect(h.engine.continueCount, 0);
    });

    test('no sign Claude started answering: stops, does not resend', () async {
      final h = await inWaitingEpisode();
      h.bridge.afterSend = Snaps.ready();
      h.bridge.current = Snaps.ready();
      await h.ticks(3);
      expect(h.engine.state, AutomationState.waitingForResponse);
      h.clock = h.clock.add(const Duration(seconds: 60));
      await h.ticks(1);
      expect(h.engine.state, AutomationState.needsAttention);
      expect(h.engine.attentionReason, 'send_not_confirmed');
      expect(h.sends.length, 2);
    });
  });

  group('connection loss', () {
    test('offline phone: nothing is sent while offline', () async {
      final h = await inWaitingEpisode();
      h.bridge.current = Snaps.offline();
      await h.ticks(10);
      expect(h.bridge.actions, isEmpty);
      expect(h.logs.hasCode('device_offline'), isTrue);
    });

    test('Claude connection error: nothing is sent', () async {
      final h = await inWaitingEpisode();
      h.bridge.current = Snaps.networkError();
      await h.ticks(10);
      expect(h.bridge.actions, isEmpty);
      expect(h.logs.hasCode('claude_connection_error'), isTrue);
    });

    test('connection coming back restarts the stability count', () async {
      final h = await inWaitingEpisode();
      h.bridge.current = Snaps.ready();
      await h.ticks(2);
      h.bridge.current = Snaps.offline();
      await h.ticks(1);
      h.bridge.current = Snaps.ready();
      await h.ticks(2);
      expect(h.bridge.actions, isEmpty);
      await h.ticks(1);
      expect(h.sends.length, 2);
    });
  });

  group('safety stops', () {
    test('login screen stops the automation immediately', () async {
      final h = await inWaitingEpisode();
      h.bridge.current = Snaps.login();
      await h.ticks(1);
      expect(h.engine.state, AutomationState.needsAttention);
      expect(h.engine.attentionReason, 'login_required');
      expect(h.engine.isRunning, isFalse);
      expect(h.bridge.actions, isEmpty);
    });

    test('security challenge stops the automation', () async {
      final h = Harness();
      await h.engine.start();
      h.bridge.current = Snaps.captcha();
      await h.ticks(1);
      expect(h.engine.isRunning, isFalse);
      expect(h.engine.attentionReason, 'login_required');
    });

    test('accessibility switched off stops the automation', () async {
      final h = Harness();
      await h.engine.start();
      h.bridge.current = Snaps.accessibilityOff();
      await h.ticks(1);
      expect(h.engine.attentionReason, 'accessibility_off');
      expect(h.engine.isRunning, isFalse);
    });

    test('unknown screen for too long: halts when auto-stop is on', () async {
      final h = Harness(tuning: const EngineTuning(unknownChecks: 3));
      await h.engine.start();
      h.bridge.current = Snaps.unknown();
      await h.ticks(3);
      expect(h.engine.state, AutomationState.needsAttention);
      expect(h.engine.isRunning, isFalse);
    });

    test('unknown screen with auto-stop off: flags but keeps watching, then recovers', () async {
      final h = Harness(
        tuning: const EngineTuning(unknownChecks: 3),
        settings: const AppSettings(autoStopOnProblem: false),
      );
      await h.engine.start();
      h.bridge.current = Snaps.unknown();
      await h.ticks(3);
      expect(h.engine.state, AutomationState.needsAttention);
      expect(h.engine.isRunning, isTrue);
      h.bridge.current = Snaps.ready();
      await h.ticks(1);
      expect(h.engine.state, AutomationState.monitoring);
      expect(h.engine.attentionReason, isNull);
    });

    test('Claude left the foreground: flagged, never halted, recovers', () async {
      final h = await inWaitingEpisode(tuning: const EngineTuning(notForegroundChecks: 3));
      h.bridge.current = Snaps.notClaude();
      await h.ticks(3);
      expect(h.engine.attentionReason, 'claude_not_foreground');
      expect(h.engine.isRunning, isTrue);
      expect(h.bridge.actions, isEmpty);
      h.bridge.current = Snaps.limit();
      await h.ticks(1);
      expect(h.engine.state, AutomationState.waitingForUsageReset);
    });

    test('Stop is immediate and persists running=false', () async {
      final h = await inWaitingEpisode();
      await h.engine.stop();
      expect(h.engine.state, AutomationState.stopped);
      expect(h.engine.isRunning, isFalse);
      expect((await h.store.load()).running, isFalse);
      h.bridge.current = Snaps.ready();
      await h.ticks(10);
      expect(h.bridge.actions, isEmpty);
    });

    test('sending can be disabled: user is notified instead', () async {
      final h = await inWaitingEpisode(
        settings: const AppSettings(sendContinueEnabled: false),
      );
      h.bridge.current = Snaps.ready();
      await h.ticks(4);
      expect(h.bridge.actions, isEmpty);
      expect(h.engine.state, AutomationState.monitoring);
      expect(
        h.notices.any((n) => n.kind == EngineNoticeKind.usageAvailableManual),
        isTrue,
      );
    });
  });

  group('app closing and state restoration', () {
    test('persisted wait episode is restored and still verified before sending', () async {
      final h = Harness();
      h.store.value = PersistedEngineState(
        running: true,
        state: 'waitingForUsageReset',
        episodeId: 1,
        limitStartedAt: h.clock.subtract(const Duration(hours: 2)),
      );
      h.bridge.current = Snaps.limit();
      await h.engine.start(resumed: true);
      expect(h.engine.state, AutomationState.waitingForUsageReset);
      expect(h.engine.waitElapsed!.inMinutes, greaterThanOrEqualTo(120));
      await h.ticks(5);
      expect(h.bridge.actions, isEmpty, reason: 'limit still showing');
      h.bridge.current = Snaps.ready();
      await h.ticks(3);
      expect(h.sends.length, 2);
    });

    test('restart right after a send does NOT send twice', () async {
      final h = Harness();
      h.store.value = PersistedEngineState(
        running: true,
        state: 'waitingForResponse',
        episodeId: 1,
        sentInEpisode: true,
        continueCount: 1,
        lastSendAt: h.clock.subtract(const Duration(seconds: 10)),
      );
      h.bridge.current = Snaps.ready();
      await h.engine.start(resumed: true);
      expect(h.engine.state, AutomationState.monitoring);
      expect(h.engine.continueCount, 1);
      await h.ticks(10);
      expect(h.bridge.actions, isEmpty);
    });

    test('state is written to the store as it changes', () async {
      final h = await inWaitingEpisode();
      final p = await h.store.load();
      expect(p.running, isTrue);
      expect(p.limitStartedAt, isNotNull);
      expect(p.sentInEpisode, isFalse);
      h.bridge.current = Snaps.ready();
      await h.ticks(3);
      final p2 = await h.store.load();
      expect(p2.sentInEpisode, isTrue);
      expect(p2.continueCount, 1);
    });
  });
}
