import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/text_utils.dart';
import 'app_card.dart';

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, this.value, this.valueWidget});

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          valueWidget ??
              Text(
                value ?? '—',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
        ],
      ),
    );
  }
}

/// Ticks every second so the waiting time visibly counts up.
class ElapsedText extends StatefulWidget {
  const ElapsedText({super.key, required this.read});

  final Duration? Function() read;

  @override
  State<ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<ElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.read();
    return Text(
      d == null ? '—' : formatDuration(d),
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
