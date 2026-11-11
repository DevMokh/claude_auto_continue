import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import 'accessibility_disclosure.dart';
import 'app_controller.dart';

class SetupCard extends StatelessWidget {
  const SetupCard({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final st = controller.setup;
    final native = controller.native;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('setup_title'),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _Row(
            ok: st.accessibilityConnected,
            title: s.t('setup_accessibility'),
            actionLabel: s.t('fix'),
            onAction: () => showAccessibilityDisclosure(context, native),
          ),
          _Row(
            ok: st.claudeInstalled,
            title: s.t('setup_claude'),
          ),
          _Row(
            ok: st.notificationsGranted,
            title: s.t('setup_notifications'),
            actionLabel: s.t('fix'),
            onAction: () async {
              await native.requestNotificationPermission();
              await controller.refreshSetup();
            },
          ),
          _Row(
            ok: st.batteryIgnored,
            title: s.t('setup_battery'),
            actionLabel: s.t('fix'),
            onAction: native.openBatterySettings,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.ok,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final bool ok;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error_outline,
            color: ok ? AppColors.green : AppColors.amber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: const TextStyle(color: AppColors.text)),
          ),
          if (!ok && actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
