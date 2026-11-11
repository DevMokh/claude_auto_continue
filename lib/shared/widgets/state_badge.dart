import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/automation_state.dart';

class StateVisual {
  const StateVisual(this.color, this.icon);

  final Color color;
  final IconData icon;
}

StateVisual stateVisual(AutomationState s) {
  switch (s) {
    case AutomationState.idle:
      return const StateVisual(AppColors.grey, Icons.hourglass_empty);
    case AutomationState.monitoring:
      return const StateVisual(AppColors.purple, Icons.visibility_outlined);
    case AutomationState.claudeWorking:
      return const StateVisual(AppColors.blue, Icons.autorenew);
    case AutomationState.waitingForUsageReset:
      return const StateVisual(AppColors.amber, Icons.schedule);
    case AutomationState.usageAvailable:
      return const StateVisual(AppColors.green, Icons.check_circle_outline);
    case AutomationState.sendingContinue:
      return const StateVisual(AppColors.purpleLight, Icons.send_outlined);
    case AutomationState.waitingForResponse:
      return const StateVisual(AppColors.blue, Icons.more_horiz);
    case AutomationState.needsAttention:
      return const StateVisual(AppColors.red, Icons.warning_amber_rounded);
    case AutomationState.stopped:
      return const StateVisual(AppColors.grey, Icons.stop_circle_outlined);
  }
}

class StateBadge extends StatelessWidget {
  const StateBadge({super.key, required this.state, this.large = false});

  final AutomationState state;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final v = stateVisual(state);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 22 : 12,
        vertical: large ? 14 : 8,
      ),
      decoration: BoxDecoration(
        color: v.color.withAlpha(40),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: v.color.withAlpha(140)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(v.icon, color: v.color, size: large ? 26 : 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              s.stateLabel(state),
              style: TextStyle(
                color: v.color,
                fontSize: large ? 18 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
