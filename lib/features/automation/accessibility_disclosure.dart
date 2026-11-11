import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/native_channel.dart';

/// Prominent disclosure shown BEFORE sending the user to system settings.
Future<void> showAccessibilityDisclosure(
  BuildContext context,
  NativeChannel native,
) async {
  final s = AppStrings.of(context);
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.t('acs_title')),
      content: SingleChildScrollView(child: Text(s.t('acs_body'))),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(s.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(s.t('open_settings')),
        ),
      ],
    ),
  );
  if (go == true) {
    await native.openAccessibilitySettings();
  }
}
