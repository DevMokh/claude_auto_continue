import 'package:flutter/foundation.dart';

import '../models/log_entry.dart';

abstract class ActivityLogRepository extends ChangeNotifier {
  Future<void> add(LogType type, String code, {String details = ''});
  Future<List<LogEntry>> recent({int limit = 300});
  Future<void> clear();
}

/// Used by tests and as a fallback if the database cannot be opened.
class InMemoryLogRepository extends ActivityLogRepository {
  final List<LogEntry> entries = <LogEntry>[];
  int _nextId = 1;

  @override
  Future<void> add(LogType type, String code, {String details = ''}) async {
    entries.add(
      LogEntry(
        id: _nextId++,
        time: DateTime.now(),
        type: type,
        code: code,
        details: details,
      ),
    );
    notifyListeners();
  }

  @override
  Future<List<LogEntry>> recent({int limit = 300}) async {
    final list = entries.reversed.take(limit).toList();
    return list;
  }

  @override
  Future<void> clear() async {
    entries.clear();
    notifyListeners();
  }

  bool hasCode(String code) => entries.any((e) => e.code == code);
}
