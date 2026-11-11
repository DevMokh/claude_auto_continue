import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/text_utils.dart';
import '../../models/log_entry.dart';
import '../../services/activity_log_repository.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  ActivityLogRepository? _repo;
  late Future<List<LogEntry>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<ActivityLogRepository>();
    if (!identical(repo, _repo)) {
      _repo?.removeListener(_reload);
      _repo = repo;
      _repo!.addListener(_reload);
      _future = repo.recent();
    }
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _repo!.recent();
    });
  }

  @override
  void dispose() {
    _repo?.removeListener(_reload);
    super.dispose();
  }

  IconData _icon(LogType t) {
    switch (t) {
      case LogType.monitoring:
        return Icons.visibility_outlined;
      case LogType.detection:
        return Icons.search;
      case LogType.usage:
        return Icons.hourglass_bottom;
      case LogType.wait:
        return Icons.schedule;
      case LogType.send:
        return Icons.send_outlined;
      case LogType.stop:
        return Icons.stop_circle_outlined;
      case LogType.attention:
        return Icons.warning_amber_rounded;
      case LogType.info:
        return Icons.info_outline;
    }
  }

  Color _color(LogType t) {
    switch (t) {
      case LogType.attention:
        return AppColors.red;
      case LogType.send:
        return AppColors.green;
      case LogType.usage:
      case LogType.wait:
        return AppColors.amber;
      case LogType.stop:
        return AppColors.grey;
      case LogType.monitoring:
      case LogType.detection:
      case LogType.info:
        return AppColors.purpleLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.t('logs_title'),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _repo?.clear(),
                  child: Text(s.t('clear')),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LogEntry>>(
              future: _future,
              builder: (context, snap) {
                final items = snap.data ?? const <LogEntry>[];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      s.t('logs_empty'),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_icon(e.type), color: _color(e.type)),
                      title: Text(s.logMessage(e)),
                      subtitle: e.details.isEmpty ? null : Text(e.details),
                      trailing: Text(
                        formatClock(e.time),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
