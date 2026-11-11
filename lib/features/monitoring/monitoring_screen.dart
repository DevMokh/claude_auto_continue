import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/text_utils.dart';
import '../../models/automation_state.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/state_badge.dart';
import '../automation/app_controller.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final controller = context.watch<AppController>();
    final engine = controller.engine;
    final obs = engine.lastObservation;
    final interval = controller.settings.checkIntervalSec;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            s.t('monitor_title'),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Center(child: StateBadge(state: engine.state, large: true)),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                _kv(s.t('claude_status'),
                    obs == null ? '—' : s.claudeState(obs.state)),
                _kv(s.t('composer'),
                    obs == null ? '—' : (obs.composerEnabled ? s.t('composer_ready') : s.t('composer_not_ready'))),
                _kv(s.t('last_check'),
                    engine.lastCheckAt == null ? '—' : formatClock(engine.lastCheckAt!)),
                _kv(s.t('check_interval'), '$interval ${s.t('seconds')}'),
                _kv(s.t('continue_count'), '${engine.continueCount}'),
                if (engine.limitMessage != null && engine.limitMessage!.isNotEmpty)
                  _kv(s.t('limit_message'), truncateText(engine.limitMessage!, 90)),
              ],
            ),
          ),
          if (engine.attentionReason != null) ...[
            const SizedBox(height: 12),
            AppCard(
              borderColor: AppColors.red,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('attention_reason'),
                    style: const TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.attentionText(engine.attentionReason!),
                    style: const TextStyle(color: AppColors.text),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            s.t('timeline'),
            style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              children: [
                for (final st in AutomationState.values)
                  _TimelineRow(state: st, current: engine.state == st),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(k, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            flex: 6,
            child: Text(v, style: const TextStyle(color: AppColors.text)),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.state, required this.current});

  final AutomationState state;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final v = stateVisual(state);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 18,
            color: current ? v.color : AppColors.grey,
          ),
          const SizedBox(width: 10),
          Icon(v.icon, size: 18, color: current ? v.color : AppColors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.stateLabel(state),
              style: TextStyle(
                color: current ? AppColors.text : AppColors.muted,
                fontWeight: current ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
