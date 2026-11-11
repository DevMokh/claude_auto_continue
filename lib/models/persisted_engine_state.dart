/// The slice of engine state that must survive process death.
class PersistedEngineState {
  const PersistedEngineState({
    this.running = false,
    this.state = 'idle',
    this.episodeId = 0,
    this.limitStartedAt,
    this.sentInEpisode = false,
    this.continueCount = 0,
    this.lastSendAt,
  });

  final bool running;
  final String state;
  final int episodeId;
  final DateTime? limitStartedAt;
  final bool sentInEpisode;
  final int continueCount;
  final DateTime? lastSendAt;
}
