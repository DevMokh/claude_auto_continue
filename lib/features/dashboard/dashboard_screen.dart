import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/stat_tile.dart';
import '../../shared/widgets/state_badge.dart';
import '../automation/accessibility_disclosure.dart';
import '../automation/app_controller.dart';
import '../automation/setup_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final controller = context.watch<AppController>();
    final engine = controller.engine;
    final claude = engine.lastObservation?.state;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.t('app_name'),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Center(child: StateBadge(state: engine.state, large: true)),
          if (engine.attentionReason != null) ...[
            const SizedBox(height: 10),
            Text(
              s.attentionText(engine.attentionReason!),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.red),
            ),
          ],
          const SizedBox(height: 22),
          _StartStopButton(controller: controller),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () => controller.native.openClaude(),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(s.t('open_claude')),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: s.t('claude_status'),
                  value: claude == null ? '—' : s.claudeState(claude),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: s.t('auto_status'),
                  value: s.stateLabel(engine.state),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: s.t('continue_count'),
                  value: '${engine.continueCount}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: s.t('wait_time'),
                  valueWidget: ElapsedText(read: () => engine.waitElapsed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SetupCard(controller: controller),
        ],
      ),
    );
  }
}

class _StartStopButton extends StatelessWidget {
  const _StartStopButton({required this.controller});

  final AppController controller;

  Future<void> _toggle(BuildContext context) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (controller.engine.isRunning) {
      await controller.stop();
      return;
    }
    final result = await controller.start();
    if (!context.mounted) return;
    switch (result) {
      case StartResult.started:
        break;
      case StartResult.needsAccessibility:
        await showAccessibilityDisclosure(context, controller.native);
        break;
      case StartResult.claudeMissing:
        messenger.showSnackBar(SnackBar(content: Text(s.t('err_claude_missing'))));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final running = controller.engine.isRunning;
    return SizedBox(
      height: 72,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: running ? AppColors.red : AppColors.purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        onPressed: () => _toggle(context),
        icon: Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 34),
        label: Text(running ? s.t('stop') : s.t('start')),
      ),
    );
  }
}
