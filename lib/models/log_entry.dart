enum LogType {
  monitoring,
  detection,
  usage,
  wait,
  send,
  stop,
  attention,
  info,
}

class LogEntry {
  const LogEntry({
    this.id,
    required this.time,
    required this.type,
    required this.code,
    this.details = '',
  });

  factory LogEntry.fromMap(Map<String, Object?> m) {
    final typeName = m['type'] as String? ?? 'info';
    return LogEntry(
      id: m['id'] as int?,
      time: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
      type: LogType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => LogType.info,
      ),
      code: m['code'] as String? ?? '',
      details: m['details'] as String? ?? '',
    );
  }

  final int? id;
  final DateTime time;
  final LogType type;
  final String code;
  final String details;

  Map<String, Object?> toMap() => <String, Object?>{
        'ts': time.millisecondsSinceEpoch,
        'type': type.name,
        'code': code,
        'details': details,
      };
}
