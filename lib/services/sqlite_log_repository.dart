import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/log_entry.dart';
import 'activity_log_repository.dart';

/// Local-only activity log. Nothing here is ever sent anywhere.
class SqliteLogRepository extends ActivityLogRepository {
  SqliteLogRepository._(this._db);

  final Database _db;
  static const int _maxRows = 2000;

  static Future<SqliteLogRepository> open() async {
    final path = p.join(await getDatabasesPath(), 'activity_log.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE logs ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'ts INTEGER NOT NULL, '
          'type TEXT NOT NULL, '
          'code TEXT NOT NULL, '
          'details TEXT NOT NULL)',
        );
      },
    );
    return SqliteLogRepository._(db);
  }

  @override
  Future<void> add(LogType type, String code, {String details = ''}) async {
    final entry = LogEntry(
      time: DateTime.now(),
      type: type,
      code: code,
      details: details,
    );
    await _db.insert('logs', entry.toMap());
    await _db.execute(
      'DELETE FROM logs WHERE id NOT IN '
      '(SELECT id FROM logs ORDER BY id DESC LIMIT $_maxRows)',
    );
    notifyListeners();
  }

  @override
  Future<List<LogEntry>> recent({int limit = 300}) async {
    final rows = await _db.query('logs', orderBy: 'id DESC', limit: limit);
    return rows.map(LogEntry.fromMap).toList();
  }

  @override
  Future<void> clear() async {
    await _db.delete('logs');
    notifyListeners();
  }
}
