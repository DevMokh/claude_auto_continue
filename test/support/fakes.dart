import 'package:claude_auto_continue/core/constants/engine_constants.dart';
import 'package:claude_auto_continue/models/action_result.dart';
import 'package:claude_auto_continue/models/app_settings.dart';
import 'package:claude_auto_continue/models/screen_snapshot.dart';
import 'package:claude_auto_continue/services/accessibility_bridge.dart';
import 'package:claude_auto_continue/services/activity_log_repository.dart';
import 'package:claude_auto_continue/services/auto_continue_engine.dart';
import 'package:claude_auto_continue/services/claude_monitor.dart';
import 'package:claude_auto_continue/services/engine_state_store.dart';

/// Hand-built screens. These are MOCKS of what Claude might expose; they prove
/// the logic, not that the real Claude app looks like this.
class Snaps {
  static ScreenSnapshot _base({
    List<String> texts = const <String>[],
    List<ControlInfo> controls = const <ControlInfo>[],
    bool claude = true,
    bool online = true,
    bool connected = true,
    bool password = false,
  }) =>
      ScreenSnapshot(
        capturedAt: DateTime(2026),
        accessibilityConnected: connected,
        claudeInForeground: claude,
        online: online,
        texts: texts,
        controls: controls,
        hasPasswordField: password,
      );

  static ControlInfo composer({String text = '', bool enabled = true}) =>
      ControlInfo(className: 'EditText', editable: true, text: text, enabled: enabled);

  static ScreenSnapshot ready({String composerText = ''}) => _base(
        texts: const <String>['Here is the code you asked for'],
        controls: [composer(text: composerText)],
      );

  static ScreenSnapshot generating() => _base(
        texts: const <String>['Writing the module...'],
        controls: [
          composer(enabled: false),
          const ControlInfo(desc: 'Stop', clickable: true, className: 'Button'),
        ],
      );

  /// Claude answering a question about usage limits: the phrase is only chat text.
  static ScreenSnapshot generatingWithQuotedLimit() => _base(
        texts: const <String>['usage limit'],
        controls: [
          composer(enabled: false),
          const ControlInfo(desc: 'Stop', clickable: true, className: 'Button'),
        ],
      );

  static ScreenSnapshot limit() => _base(
        texts: const <String>['You have reached your usage limit. Resets at 3 PM.'],
        controls: [composer(enabled: false)],
      );

  static ScreenSnapshot limitWithEnabledComposer() => _base(
        texts: const <String>['Usage limit reached'],
        controls: [composer()],
      );

  static ScreenSnapshot withContinueButton() => _base(
        texts: const <String>['...and then the response was cut'],
        controls: [
          composer(),
          const ControlInfo(text: 'Continue', clickable: true, className: 'Button'),
        ],
      );

  static ScreenSnapshot login() => _base(
        texts: const <String>['Welcome back'],
        controls: const [ControlInfo(text: 'Log in', clickable: true, className: 'Button')],
      );

  static ScreenSnapshot captcha() => _base(texts: const <String>['Verify you are human']);

  static ScreenSnapshot passwordScreen() => _base(password: true);

  static ScreenSnapshot notClaude() => _base(claude: false);

  static ScreenSnapshot accessibilityOff() => _base(connected: false);

  static ScreenSnapshot offline() => _base(
        online: false,
        controls: [composer()],
      );

  static ScreenSnapshot networkError() => _base(
        texts: const <String>['Network error. Check your connection.'],
        controls: [composer()],
      );

  static ScreenSnapshot unknown() => _base(texts: const <String>['Some other screen']);
}

class FakeScreenBridge implements ScreenBridge {
  ScreenSnapshot? current = Snaps.ready();
  final List<ScreenSnapshot?> queue = <ScreenSnapshot?>[];
  final List<String> actions = <String>[];

  ActionResult typeResult = ActionResult.success;
  ActionResult sendResult = ActionResult.success;
  ActionResult continueResult = ActionResult.success;

  /// What the screen looks like right after a successful send / continue click.
  /// null means "Claude starts answering" (generating).
  ScreenSnapshot? afterSend;
  ScreenSnapshot? afterContinue;

  @override
  Future<ScreenSnapshot?> snapshot() async =>
      queue.isNotEmpty ? queue.removeAt(0) : current;

  @override
  Future<ActionResult> typeText(String text) async {
    actions.add('type:$text');
    if (typeResult.ok) current = Snaps.ready(composerText: text);
    return typeResult;
  }

  @override
  Future<ActionResult> clickSend() async {
    actions.add('send');
    if (sendResult.ok) current = afterSend ?? Snaps.generating();
    return sendResult;
  }

  @override
  Future<ActionResult> clickContinue() async {
    actions.add('continue');
    if (continueResult.ok) current = afterContinue ?? Snaps.generating();
    return continueResult;
  }
}

class Harness {
  Harness({
    EngineTuning tuning = const EngineTuning(),
    AppSettings settings = const AppSettings(),
  }) : _settings = settings {
    engine = AutoContinueEngine(
      bridge: bridge,
      monitor: ClaudeMonitor(),
      logs: logs,
      store: store,
      settings: () => _settings,
      now: () => clock,
      delay: (_) async {},
      tuning: tuning,
      autoSchedule: false,
      onNotice: notices.add,
    );
  }

  final FakeScreenBridge bridge = FakeScreenBridge();
  final InMemoryLogRepository logs = InMemoryLogRepository();
  final MemoryEngineStateStore store = MemoryEngineStateStore();
  final List<EngineNotice> notices = <EngineNotice>[];
  AppSettings _settings;
  DateTime clock = DateTime(2026, 1, 1, 22);
  late final AutoContinueEngine engine;

  set settings(AppSettings s) => _settings = s;

  Future<void> ticks(int n, {Duration step = const Duration(seconds: 5)}) async {
    for (var i = 0; i < n; i++) {
      await engine.tick();
      clock = clock.add(step);
    }
  }

  List<String> get sends =>
      bridge.actions.where((a) => a.startsWith('type:') || a == 'send').toList();

  static const String continueText = EngineConstants.continueText;
}
