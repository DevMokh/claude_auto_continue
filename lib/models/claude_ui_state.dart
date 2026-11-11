/// What the monitor concluded about the Claude screen.
enum ClaudeUiState {
  /// Accessibility service is not connected: nothing can be observed.
  unavailable,

  /// Claude is not the foreground app.
  notClaude,

  /// Login / security challenge on screen. Automation must stop.
  needsLogin,

  /// The phone has no validated internet connection.
  offline,

  /// Claude shows a connection / generic error.
  connectionError,

  /// A usage-limit banner is visible.
  usageLimit,

  /// Claude is answering right now (stop button visible).
  generating,

  /// Composer is present, enabled, nothing is generating, no limit banner.
  ready,

  /// Claude is in the foreground but the screen could not be classified.
  unknown,
}

class ClaudeObservation {
  const ClaudeObservation({
    required this.state,
    required this.capturedAt,
    this.continueButtonVisible = false,
    this.limitMessage,
    this.composerText,
    this.composerPresent = false,
    this.composerEnabled = false,
    this.stopVisible = false,
  });

  final ClaudeUiState state;
  final DateTime capturedAt;
  final bool continueButtonVisible;
  final String? limitMessage;
  final String? composerText;
  final bool composerPresent;
  final bool composerEnabled;
  final bool stopVisible;
}
