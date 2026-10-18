import 'package:sqflite/sqflite.dart';

import '../model/m_key_value_pair.dart';
import '../utils/db_helper.dart';

/// Recovered preference contract: themeCode / light|dark|system / theme.
/// Uses only this application's private key-value database.
class ThemePreferences {
  ThemePreferences({DbHelper? database}) : _database = database ?? DbHelper();

  final DbHelper _database;
  static const _key = 'themeCode';
  static const _codes = {'light', 'dark', 'system'};

  Future<String> read() async {
    try {
      final db = await _database.database;
      return await db.transaction((txn) async {
        final rows = await txn.query(
          DbHelper.table,
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [_key],
          limit: 1,
        );
        if (rows.isEmpty) {
          await txn.insert(
            DbHelper.table,
            const ModelKeyValuePair(
              key: _key,
              value: 'system',
              kategori: 'theme',
            ).toMap(),
          );
          return 'system';
        }
        final value = rows.single['value'];
        return value is String && _codes.contains(value) ? value : 'system';
      });
    } catch (_) {
      throw StateError('Preferensi tema tidak dapat dibaca dari penyimpanan.');
    }
  }

  Future<void> write(String code) async {
    if (!_codes.contains(code)) {
      throw const FormatException(
        'Pilihan tema harus light, dark, atau system.',
      );
    }
    try {
      final db = await _database.database;
      await db.transaction(
        (txn) => txn.insert(
          DbHelper.table,
          ModelKeyValuePair(key: _key, value: code, kategori: 'theme').toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      );
    } catch (_) {
      throw StateError('Preferensi tema tidak dapat disimpan.');
    }
  }
}
