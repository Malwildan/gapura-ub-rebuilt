import 'package:sqflite/sqflite.dart';

import '../model/m_key_value_pair.dart';
import '../utils/db_helper.dart';

abstract class SessionStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> session);
  Future<void> clear();
}

/// Uses the recovered token keys and row schema. Metadata keys are explicitly
/// reconstruction-specific, because their original persistence is unproven.
class SqliteSessionStore implements SessionStore {
  SqliteSessionStore({DbHelper? database}) : _database = database ?? DbHelper();

  final DbHelper _database;
  static const expiresAtKey = 'gapura.reconstruction.expiresAt';
  static const usernameKey = 'gapura.reconstruction.username';
  static const _keys = [
    'accessToken',
    'refreshToken',
    'idToken',
    expiresAtKey,
    usernameKey,
  ];
  static const _where = 'key IN (?, ?, ?, ?, ?)';

  @override
  Future<Map<String, dynamic>?> read() async {
    final db = await _database.database;
    final rows = await db.query(
      DbHelper.table,
      where: _where,
      whereArgs: _keys,
    );
    final values = {
      for (final row in rows)
        ModelKeyValuePair.fromMap(row).key: ModelKeyValuePair.fromMap(
          row,
        ).value,
    };
    final access = values['accessToken'];
    if (access == null || access.isEmpty) return null;
    return {
      'accessToken': access,
      'refreshToken': values['refreshToken'],
      'idToken': values['idToken'],
      'expiresAt': int.tryParse(values[expiresAtKey] ?? '') ?? 0,
      'username': values[usernameKey] ?? '',
    };
  }

  @override
  Future<void> write(Map<String, dynamic> session) async {
    final access = session['accessToken'];
    final expiresAt = session['expiresAt'];
    if (access is! String || access.isEmpty || expiresAt is! int) {
      throw const FormatException('Sesi IAM tidak dapat disimpan.');
    }
    final values = <String, String?>{
      'accessToken': access,
      'refreshToken': session['refreshToken'] as String?,
      'idToken': session['idToken'] as String?,
      expiresAtKey: '$expiresAt',
      usernameKey: session['username'] as String?,
    };
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final entry in values.entries) {
        if (entry.value == null) {
          await txn.delete(
            DbHelper.table,
            where: 'key = ?',
            whereArgs: [entry.key],
          );
        } else {
          await txn.insert(
            DbHelper.table,
            ModelKeyValuePair(key: entry.key, value: entry.value).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  @override
  Future<void> clear() async {
    final db = await _database.database;
    await db.transaction(
      (txn) => txn.delete(DbHelper.table, where: _where, whereArgs: _keys),
    );
  }
}
