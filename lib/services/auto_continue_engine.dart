import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/engine_constants.dart';
import '../core/utils/text_utils.dart';
import '../models/app_settings.dart';
import '../models/automation_state.dart';
import '../models/claude_ui_state.dart';
import '../models/log_entry.dart';
import '../models/persisted_engine_state.dart';
import 'accessibility_bridge.dart';
import 'activity_log_repository.dart';
import 'claude_monitor.dart';
import 'engine_state_store.dart';

enum EngineNoticeKind { waiting, usageAvailableManual, sent, attention, stopped }

/// Emitted for things the user may want a notification about.
class EngineNotice {
  const EngineNotice(this.kind, this.code, [this.details = '']);

  final EngineNoticeKind kind;
  final String code;
  final String details;
}

/// The Auto Continue state machine.
///
/// Rules it enforces (each has a unit test):
///  * never acts unless the latest observation is positively "ready";
///  * a wait episode ends in at most ONE send (write-ahead flag, persisted);
///  * never sends while Claude is generating;
///  * the banner merely disappearing is not enough: the composer must be
///    present and enabled for several consecutive checks, then re-verified;
///  * login / security / unknown failures stop or flag instead of guessing.
class AutoContinueEngine extends ChangeNotifier {
  AutoContinueEngine({
    required this.bridge,
    required this.monitor,
    required this.logs,
    required this.store,
    required this.settings,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
    this.tuning = const EngineTuning(),
    this.onNotice,
    this.autoSchedule = true,
  })  : _now = now ?? DateTime.now,
        _delay = delay ?? ((d) => Future<void>.delayed(d));

  final ScreenBridge bridge;
  final ClaudeMonitor monitor;
  final ActivityLogRepository logs;
  final EngineStateStore store;
  final AppSettings Function() settings;
  final EngineTuning tuning;
  final void Function(EngineNotice notice)? onNotice;

  /// Tests set this to false and call [tick] by hand.
  final bool autoSchedule;

  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  // ---- public state ----
  AutomationState _state = AutomationState.idle;
  bool _running = false;
  int _continueCount = 0;
  DateTime? _limitStartedAt;
  String? _limitMessage;
  String? _attention;
  ClaudeObservation? _lastObservation;
  DateTime? _lastCheckAt;

  AutomationState get state => _state;
  bool get isRunning => _running;
  int get continueCount => _continueCount;
  String? get limitMessage => _limitMessage;
  String? get attentionReason => _attention;
  ClaudeObservation? get lastObservation => _lastObservation;
  DateTime? get lastCheckAt => _lastCheckAt;
  DateTime? get limitStartedAt => _limitStartedAt;

  Duration? get waitElapsed {
    if (!_inEpisode || _limitStartedAt == null) return null;
    final d = _now().difference(_limitStartedAt!);
    return d.isNegative ? Duration.zero : d;
  }

  // ---- internal state ----
  Timer? _timer;
  bool _ticking = false;
  AutomationState _stateBeforeAttention = AutomationState.monitoring;

  bool _inEpisode = false;
  int _episodeId = 0;
  bool _sentInEpisode = false;
  DateTime? _lastSendAt;
  DateTime? _lastContinueClickAt;
  DateTime? _sentAt;
  bool _generatingSeenSinceSend = false;

  int _readyStreak = 0;
  int _limitStreak = 0;
  int _notClaudeTicks = 0;
  int _unknownTicks = 0;
  bool _offlineLogged = false;
  bool _errorLogged = false;

  // ================= lifecycle =================

  Future<void> start({bool resumed = false}) async {
    if (_running) return;
    _running = true;
    _attention = null;
    _resetStreaks();
    if (resumed) {
      final p = await store.load();
      _episodeId = p.episodeId;
      _continueCount = p.continueCount;
      _sentInEpisode = p.sentInEpisode;
      _lastSendAt = p.lastSendAt;
      if (p.limitStartedAt != null && !p.sentInEpisode) {
        _inEpisode = true;
        _limitStartedAt = p.limitStartedAt;
        _state = AutomationState.waitingForUsageReset;
      } else {
        _inEpisode = false;
        _limitStartedAt = null;
        _state = AutomationState.monitoring;
      }
      await _log(LogType.monitoring, 'monitoring_resumed');
    } else {
      _episodeId = 0;
      _continueCount = 0;
      _sentInEpisode = false;
      _lastSendAt = null;
      _lastContinueClickAt = null;
      _inEpisode = false;
      _limitStartedAt = null;
      _limitMessage = null;
      _state = AutomationState.monitoring;
      await _log(LogType.monitoring, 'monitoring_started');
    }
    await _persist();
    notifyListeners();
    _schedule(immediate: true);
  }

  Future<void> stop({String reason = 'stopped_user'}) async {
    _timer?.cancel();
    _timer = null;
    final wasActive = _running || _state == AutomationState.needsAttention;
    _running = false;
    _attention = null;
    _inEpisode = false;
    _limitStartedAt = null;
    _state = AutomationState.stopped;
    if (wasActive) await _log(LogType.stop, reason);
    await _persist();
    notifyListeners();
  }

  void _schedule({bool immediate = false}) {
    _timer?.cancel();
    _timer = null;
    if (!autoSchedule || !_running) return;
    final secs = clampInt(settings().checkIntervalSec, 2, 120);
    _timer = Timer(immediate ? Duration.zero : Duration(seconds: secs), () async {
      await tick();
      _schedule();
    });
  }

  // ================= one observation cycle =================

  Future<void> tick() async {
    if (!_running || _ticking) return;
    _ticking = true;
    try {
      final snap = await bridge.snapshot();
      if (!_running) return;
      final obs = monitor.observe(snap, now: _now());
      _lastObservation = obs;
      _lastCheckAt = obs.capturedAt;
      await _handle(obs);
    } catch (e) {
      await _raise('engine_error', details: e.toString(), halt: true);
    } finally {
      _ticking = false;
      notifyListeners();
    }
  }

  Future<void> _handle(ClaudeObservation obs) async {
    // After sending, silence for too long means we cannot confirm: stop, do not resend.
    if (_state == AutomationState.waitingForResponse &&
        obs.state != ClaudeUiState.generating &&
        !_generatingSeenSinceSend &&
        _sentAt != null &&
        _now().difference(_sentAt!) > tuning.responseStartTimeout) {
      await _raise('send_not_confirmed', halt: true);
      return;
    }

    switch (obs.state) {
      case ClaudeUiState.unavailable:
        await _raise('accessibility_off', halt: true);
        return;
      case ClaudeUiState.needsLogin:
        await _raise('login_required', halt: true);
        return;
      case ClaudeUiState.notClaude:
        await _onNotClaude();
        return;
      case ClaudeUiState.offline:
        _onRecognized();
        _readyStreak = 0;
        if (!_offlineLogged) {
          _offlineLogged = true;
          await _log(LogType.info, 'device_offline');
        }
        return;
      case ClaudeUiState.connectionError:
        _onRecognized();
        _readyStreak = 0;
        if (!_errorLogged) {
          _errorLogged = true;
          await _log(LogType.info, 'claude_connection_error');
        }
        return;
      case ClaudeUiState.unknown:
        await _onUnknown();
        return;
      case ClaudeUiState.generating:
        _onRecognized();
        await _onGenerating();
        return;
      case ClaudeUiState.usageLimit:
        _onRecognized();
        await _onLimit(obs);
        return;
      case ClaudeUiState.ready:
        _onRecognized();
        await _onReady(obs);
        return;
    }
  }

  void _onRecognized() {
    _notClaudeTicks = 0;
    _unknownTicks = 0;
    if (_attention != null && _running) {
      _attention = null;
      _state = _stateBeforeAttention;
      unawaited(_log(LogType.info, 'attention_cleared'));
    }
  }

  Future<void> _onNotClaude() async {
    _notClaudeTicks++;
    _readyStreak = 0;
    _limitStreak = 0;
    if (_notClaudeTicks == 1) {
      await _log(LogType.info, 'claude_not_foreground');
    }
    if (_notClaudeTicks == tuning.notForegroundChecks) {
      await _raise('claude_not_foreground', halt: false);
    }
  }

  Future<void> _onUnknown() async {
    _notClaudeTicks = 0;
    _unknownTicks++;
    _readyStreak = 0;
    if (_unknownTicks == 1) {
      await _log(LogType.info, 'ui_unrecognized');
    }
    if (_unknownTicks == tuning.unknownChecks) {
      await _raise(
        'ui_unrecognized',
        halt: settings().autoStopOnProblem,
      );
    }
  }

  Future<void> _onGenerating() async {
    _readyStreak = 0;
    _limitStreak = 0;
    if (_state == AutomationState.waitingForUsageReset) {
      // Claude is answering although we were waiting: someone resumed it.
      await _log(LogType.usage, 'resumed_externally');
      _inEpisode = false;
      _limitStartedAt = null;
    }
    if (_state == AutomationState.waitingForResponse) {
      _generatingSeenSinceSend = true;
    }
    if (_state != AutomationState.claudeWorking) {
      if (_state == AutomationState.monitoring) {
        await _log(LogType.detection, 'claude_working');
      }
      _setState(AutomationState.claudeWorking);
      await _persist();
    }
  }

  Future<void> _onLimit(ClaudeObservation obs) async {
    _readyStreak = 0;
    _limitStreak++;
    _limitMessage = obs.limitMessage;
    if (_state == AutomationState.waitingForUsageReset) return;
    if (_limitStreak < tuning.limitConfirmChecks) return;

    _episodeId++;
    _inEpisode = true;
    _sentInEpisode = false;
    _limitStartedAt = _now();
    await _log(LogType.usage, 'usage_limit_detected',
        details: truncateText(obs.limitMessage ?? '', 120));
    _setState(AutomationState.waitingForUsageReset);
    await _log(LogType.wait, 'wait_started');
    await _persist();
    onNotice?.call(const EngineNotice(EngineNoticeKind.waiting, 'wait_started'));
  }

  Future<void> _onReady(ClaudeObservation obs) async {
    _limitStreak = 0;

    if (_state == AutomationState.waitingForUsageReset) {
      _readyStreak++;
      if (_readyStreak >= tuning.readyStableChecks) {
        await _attemptSend();
      }
      return;
    }

    if (_state == AutomationState.waitingForResponse) {
      await _onReadyWhileWaitingResponse(obs);
      return;
    }

    if (_state == AutomationState.claudeWorking) {
      await _log(LogType.detection, 'response_finished');
      _setState(AutomationState.monitoring);
      await _persist();
    }

    await _maybeClickContinue(obs);
  }

  Future<void> _onReadyWhileWaitingResponse(ClaudeObservation obs) async {
    if (_generatingSeenSinceSend) {
      await _log(LogType.detection, 'response_finished');
      _setState(AutomationState.monitoring);
      await _persist();
      return;
    }
    final text = obs.composerText?.trim() ?? '';
    if (text == EngineConstants.continueText &&
        _sentAt != null &&
        _now().difference(_sentAt!) > tuning.composerClearTimeout) {
      await _raise('send_failed_text_remains', halt: true);
    }
  }

  // ================= actions =================

  Future<void> _maybeClickContinue(ClaudeObservation obs) async {
    final s = settings();
    if (!obs.continueButtonVisible || !s.clickContinueEnabled) return;
    if (_state != AutomationState.monitoring) return;
    final last = _lastContinueClickAt;
    if (last != null && _now().difference(last) < tuning.continueClickCooldown) {
      return;
    }
    if (_continueCount >= s.maxContinueAttempts) {
      await _stopForMax();
      return;
    }
    _lastContinueClickAt = _now();
    await _log(LogType.detection, 'continue_button_detected');
    final r = await bridge.clickContinue();
    if (!_running) return;
    if (!r.ok) {
      await _log(LogType.send, 'send_result_failed', details: r.reason);
      await _raise(
        'continue_click_failed',
        details: r.reason,
        halt: s.autoStopOnProblem,
      );
      return;
    }
    _continueCount++;
    await _log(LogType.send, 'continue_button_clicked', details: '#$_continueCount');
    await _beginWaitingResponse();
    onNotice?.call(EngineNotice(EngineNoticeKind.sent, 'continue_button_clicked', '$_continueCount'));
  }

  Future<void> _attemptSend() async {
    final s = settings();
    if (_sentInEpisode) return; // one send per episode, ever
    if (!s.sendContinueEnabled) {
      await _log(LogType.usage, 'usage_available_send_disabled');
      _inEpisode = false;
      _limitStartedAt = null;
      _setState(AutomationState.monitoring);
      await _persist();
      onNotice?.call(const EngineNotice(
          EngineNoticeKind.usageAvailableManual, 'usage_available_send_disabled'));
      return;
    }
    if (_continueCount >= s.maxContinueAttempts) {
      await _stopForMax();
      return;
    }
    final last = _lastSendAt;
    if (last != null && _now().difference(last) < tuning.minSendGap) return;

    _setState(AutomationState.usageAvailable);
    await _log(LogType.usage, 'usage_available',
        details: waitElapsed == null ? '' : formatDuration(waitElapsed!));

    // Fresh, independent verification right before acting.
    final fresh = monitor.observe(await bridge.snapshot(), now: _now());
    if (!_running) return;
    _lastObservation = fresh;
    if (fresh.state != ClaudeUiState.ready) {
      _readyStreak = 0;
      _setState(AutomationState.waitingForUsageReset);
      await _log(LogType.info, 'verification_failed', details: fresh.state.name);
      return;
    }

    // Write-ahead: mark as sent BEFORE touching the UI so a crash cannot duplicate.
    _sentInEpisode = true;
    _lastSendAt = _now();
    await _persist();

    _setState(AutomationState.sendingContinue);
    await _log(LogType.send, 'sending_continue');

    final typed = await bridge.typeText(EngineConstants.continueText);
    if (!_running) return;
    if (!typed.ok) {
      await _log(LogType.send, 'send_result_failed', details: typed.reason);
      await _raise('send_failed', details: typed.reason, halt: true);
      return;
    }

    await _delay(tuning.typeToClickDelay);
    if (!_running) return;

    final check = monitor.observe(await bridge.snapshot(), now: _now());
    if (!_running) return;
    _lastObservation = check;
    if (check.composerText?.trim() != EngineConstants.continueText) {
      await _log(LogType.send, 'send_result_failed', details: 'composer_text_mismatch');
      await _raise('send_failed', details: 'composer_text_mismatch', halt: true);
      return;
    }

    final clicked = await bridge.clickSend();
    if (!_running) return;
    if (!clicked.ok) {
      await _log(LogType.send, 'send_result_failed', details: clicked.reason);
      await _raise('send_failed', details: clicked.reason, halt: true);
      return;
    }

    _continueCount++;
    await _log(LogType.send, 'continue_sent', details: '#$_continueCount');
    await _beginWaitingResponse();
    onNotice?.call(EngineNotice(EngineNoticeKind.sent, 'continue_sent', '$_continueCount'));
  }

  Future<void> _beginWaitingResponse() async {
    _inEpisode = false;
    _limitStartedAt = null;
    _sentAt = _now();
    _generatingSeenSinceSend = false;
    _readyStreak = 0;
    _setState(AutomationState.waitingForResponse);
    await _persist();
  }

  Future<void> _stopForMax() async {
    await _log(LogType.stop, 'max_attempts_reached');
    onNotice?.call(const EngineNotice(EngineNoticeKind.stopped, 'max_attempts_reached'));
    await stop(reason: 'stopped_max_attempts');
  }

  // ================= helpers =================

  Future<void> _raise(
    String code, {
    String details = '',
    required bool halt,
  }) async {
    if (_state != AutomationState.needsAttention) {
      _stateBeforeAttention = _state;
    }
    _attention = code;
    _state = AutomationState.needsAttention;
    await _log(LogType.attention, code, details: details);
    onNotice?.call(EngineNotice(EngineNoticeKind.attention, code, details));
    if (halt) {
      _timer?.cancel();
      _timer = null;
      _running = false;
    }
    await _persist();
    notifyListeners();
  }

  void _setState(AutomationState s) {
    if (_state != s) {
      _state = s;
      notifyListeners();
    }
  }

  void _resetStreaks() {
    _readyStreak = 0;
    _limitStreak = 0;
    _notClaudeTicks = 0;
    _unknownTicks = 0;
    _offlineLogged = false;
    _errorLogged = false;
    _sentAt = null;
    _generatingSeenSinceSend = false;
  }

  Future<void> _log(LogType type, String code, {String details = ''}) =>
      logs.add(type, code, details: details);

  Future<void> _persist() => store.save(
        PersistedEngineState(
          running: _running,
          state: _state.name,
          episodeId: _episodeId,
          limitStartedAt: _inEpisode ? _limitStartedAt : null,
          sentInEpisode: _sentInEpisode,
          continueCount: _continueCount,
          lastSendAt: _lastSendAt,
        ),
      );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
