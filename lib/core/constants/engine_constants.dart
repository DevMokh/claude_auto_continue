class EngineConstants {
  EngineConstants._();

  /// The only message this app ever types. Kept fixed on purpose.
  static const String continueText = 'كمل';
  static const String nativeChannel = 'dev.autocontinue/native';
}

/// Timing / threshold knobs. Tests override these; the app uses the defaults.
class EngineTuning {
  const EngineTuning({
    this.readyStableChecks = 3,
    this.limitConfirmChecks = 2,
    this.typeToClickDelay = const Duration(milliseconds: 900),
    this.minSendGap = const Duration(seconds: 30),
    this.continueClickCooldown = const Duration(seconds: 30),
    this.responseStartTimeout = const Duration(seconds: 45),
    this.composerClearTimeout = const Duration(seconds: 8),
    this.notForegroundChecks = 12,
    this.unknownChecks = 24,
  });

  /// Consecutive "ready" observations required before sending.
  final int readyStableChecks;

  /// Consecutive "usage limit" observations required to start a wait episode.
  final int limitConfirmChecks;

  /// Pause between typing the text and pressing send (lets the UI settle).
  final Duration typeToClickDelay;

  /// Hard floor between two sends, even across restarts.
  final Duration minSendGap;

  /// Floor between two presses of the Continue button.
  final Duration continueClickCooldown;

  /// After sending, how long we wait to see Claude start answering.
  final Duration responseStartTimeout;

  /// After sending, how long our text may remain in the composer.
  final Duration composerClearTimeout;

  final int notForegroundChecks;
  final int unknownChecks;
}
