import 'package:shared_preferences/shared_preferences.dart';

import '../models/persisted_engine_state.dart';

abstract class EngineStateStore {
  Future<PersistedEngineState> load();
  Future<void> save(PersistedEngineState state);
}

class MemoryEngineStateStore implements EngineStateStore {
  PersistedEngineState value = const PersistedEngineState();

  @override
  Future<PersistedEngineState> load() async => value;

  @override
  Future<void> save(PersistedEngineState state) async {
    value = state;
  }
}

class PrefsEngineStateStore implements EngineStateStore {
  PrefsEngineStateStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _running = 'engine.running';
  static const String _state = 'engine.state';
  static const String _episode = 'engine.episode';
  static const String _limitStartedAt = 'engine.limitStartedAt';
  static const String _sentInEpisode = 'engine.sentInEpisode';
  static const String _count = 'engine.count';
  static const String _lastSendAt = 'engine.lastSendAt';

  DateTime? _readTime(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<PersistedEngineState> load() async {
    return PersistedEngineState(
      running: _prefs.getBool(_running) ?? false,
      state: _prefs.getString(_state) ?? 'idle',
      episodeId: _prefs.getInt(_episode) ?? 0,
      limitStartedAt: _readTime(_limitStartedAt),
      sentInEpisode: _prefs.getBool(_sentInEpisode) ?? false,
      continueCount: _prefs.getInt(_count) ?? 0,
      lastSendAt: _readTime(_lastSendAt),
    );
  }

  @override
  Future<void> save(PersistedEngineState s) async {
    await _prefs.setBool(_running, s.running);
    await _prefs.setString(_state, s.state);
    await _prefs.setInt(_episode, s.episodeId);
    await _prefs.setBool(_sentInEpisode, s.sentInEpisode);
    await _prefs.setInt(_count, s.continueCount);
    if (s.limitStartedAt == null) {
      await _prefs.remove(_limitStartedAt);
    } else {
      await _prefs.setInt(
        _limitStartedAt,
        s.limitStartedAt!.millisecondsSinceEpoch,
      );
    }
    if (s.lastSendAt == null) {
      await _prefs.remove(_lastSendAt);
    } else {
      await _prefs.setInt(_lastSendAt, s.lastSendAt!.millisecondsSinceEpoch);
    }
  }
}
