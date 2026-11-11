import 'package:claude_auto_continue/models/app_settings.dart';
import 'package:claude_auto_continue/models/persisted_engine_state.dart';
import 'package:claude_auto_continue/services/engine_state_store.dart';
import 'package:claude_auto_continue/services/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('engine state survives a "process restart" (new store instance)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs1 = await SharedPreferences.getInstance();
    final store1 = PrefsEngineStateStore(prefs1);
    final started = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    await store1.save(
      PersistedEngineState(
        running: true,
        state: 'waitingForUsageReset',
        episodeId: 3,
        limitStartedAt: started,
        sentInEpisode: false,
        continueCount: 4,
        lastSendAt: started,
      ),
    );

    final store2 = PrefsEngineStateStore(await SharedPreferences.getInstance());
    final loaded = await store2.load();
    expect(loaded.running, isTrue);
    expect(loaded.state, 'waitingForUsageReset');
    expect(loaded.episodeId, 3);
    expect(loaded.limitStartedAt, started);
    expect(loaded.continueCount, 4);
    expect(loaded.lastSendAt, started);
  });

  test('clearing optional timestamps removes them', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = PrefsEngineStateStore(await SharedPreferences.getInstance());
    await store.save(PersistedEngineState(limitStartedAt: DateTime(2026)));
    await store.save(const PersistedEngineState());
    expect((await store.load()).limitStartedAt, isNull);
  });

  test('settings load defaults, persist and clamp bad values', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      's.maxAttempts': 9999,
      's.interval': 0,
    });
    final repo = await SettingsRepository.load();
    expect(repo.value.maxContinueAttempts, 100);
    expect(repo.value.checkIntervalSec, 2);
    expect(repo.value.sendContinueEnabled, isTrue);

    await repo.update(repo.value.copyWith(sendContinueEnabled: false, localeCode: 'ar'));
    final again = await SettingsRepository.load();
    expect(again.value.sendContinueEnabled, isFalse);
    expect(again.value.localeCode, 'ar');
  });

  test('defaults are the safe ones', () {
    const d = AppSettings();
    expect(d.autoStopOnProblem, isTrue);
    expect(d.maxContinueAttempts, 20);
  });
}
