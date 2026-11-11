import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../services/settings_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../automation/app_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final repo = context.watch<SettingsRepository>();
    final v = repo.value;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            s.t('settings_title'),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(s.t('s_auto_resume')),
                  subtitle: Text(s.t('s_auto_resume_sub')),
                  value: v.autoResume,
                  onChanged: (x) => repo.update(v.copyWith(autoResume: x)),
                ),
                SwitchListTile(
                  title: Text(s.t('s_notifications')),
                  value: v.notificationsEnabled,
                  onChanged: (x) => repo.update(v.copyWith(notificationsEnabled: x)),
                ),
                SwitchListTile(
                  title: Text(s.t('s_click_continue')),
                  value: v.clickContinueEnabled,
                  onChanged: (x) => repo.update(v.copyWith(clickContinueEnabled: x)),
                ),
                SwitchListTile(
                  title: Text(s.t('s_send_continue')),
                  value: v.sendContinueEnabled,
                  onChanged: (x) => repo.update(v.copyWith(sendContinueEnabled: x)),
                ),
                SwitchListTile(
                  title: Text(s.t('s_auto_stop')),
                  value: v.autoStopOnProblem,
                  onChanged: (x) => repo.update(v.copyWith(autoStopOnProblem: x)),
                ),
                SwitchListTile(
                  title: Text(s.t('s_keep_screen')),
                  value: v.keepScreenOn,
                  onChanged: (x) => repo.update(v.copyWith(keepScreenOn: x)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.t('s_max_attempts')}: ${v.maxContinueAttempts}'),
                Slider(
                  value: v.maxContinueAttempts.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: '${v.maxContinueAttempts}',
                  onChanged: (x) =>
                      repo.update(v.copyWith(maxContinueAttempts: x.round())),
                ),
                const SizedBox(height: 8),
                Text('${s.t('s_interval')}: ${v.checkIntervalSec}'),
                Slider(
                  value: v.checkIntervalSec.toDouble(),
                  min: 2,
                  max: 60,
                  divisions: 58,
                  label: '${v.checkIntervalSec}',
                  onChanged: (x) =>
                      repo.update(v.copyWith(checkIntervalSec: x.round())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('s_language')),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(value: 'system', label: Text(s.t('lang_system'))),
                    ButtonSegment<String>(value: 'ar', label: Text(s.t('lang_ar'))),
                    ButtonSegment<String>(value: 'en', label: Text(s.t('lang_en'))),
                  ],
                  selected: <String>{v.localeCode},
                  onSelectionChanged: (sel) =>
                      repo.update(v.copyWith(localeCode: sel.first)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('s_calibration'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  s.t('s_calibration_sub'),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  s.t('s_capture_hint'),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _capture(context),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: Text(s.t('s_capture')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('s_privacy'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  s.t('s_privacy_body'),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _capture(BuildContext context) async {
    final controller = context.read<AppController>();
    final s = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.t('capture_started'))),
    );
    // The service only sees Claude, so the user must switch to it first.
    await Future<void>.delayed(const Duration(seconds: 8));
    final dump = await controller.native.dumpTree();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('s_capture')),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              dump,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: dump)),
            child: Text(s.t('copy')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.t('close')),
          ),
        ],
      ),
    );
  }
}
