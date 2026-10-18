import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/service/theme_preferences.dart';
import 'package:gapura_ub/utils/db_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

void main() {
  setUpAll(() {
    if (Platform.isWindows) {
      open.overrideFor(
        OperatingSystem.windows,
        () => DynamicLibrary.open('winsqlite3.dll'),
      );
    }
    sqfliteFfiInit();
  });

  late DbHelper helper;
  late ThemePreferences preferences;
  setUp(() {
    helper = DbHelper(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    preferences = ThemePreferences(database: helper);
  });
  tearDown(() => helper.close());

  test(
    'absent preference atomically creates the recovered system row',
    () async {
      expect(await preferences.read(), 'system');
      final db = await helper.database;
      expect(await db.query(DbHelper.table), [
        {'key': 'themeCode', 'value': 'system', 'kategori': 'theme'},
      ]);
      expect(await preferences.read(), 'system');
      expect(await db.query(DbHelper.table), hasLength(1));
    },
  );

  test(
    'changes persist across instances and preserve unrelated rows',
    () async {
      final db = await helper.database;
      await db.insert(DbHelper.table, {
        'key': 'unrelated-fixture',
        'value': 'retained',
        'kategori': null,
      });
      for (final code in ['light', 'dark', 'system']) {
        await preferences.write(code);
        expect(await ThemePreferences(database: helper).read(), code);
        expect(
          await db.query(
            DbHelper.table,
            where: 'key = ?',
            whereArgs: ['themeCode'],
          ),
          [
            {'key': 'themeCode', 'value': code, 'kategori': 'theme'},
          ],
        );
      }
      expect(
        await db.query(
          DbHelper.table,
          where: 'key = ?',
          whereArgs: ['unrelated-fixture'],
        ),
        [
          {'key': 'unrelated-fixture', 'value': 'retained', 'kategori': null},
        ],
      );
    },
  );

  test('unknown persisted value maps to system without rewriting it', () async {
    final db = await helper.database;
    for (final value in ['unknown', 'LIGHT', '', null]) {
      await db.insert(DbHelper.table, {
        'key': 'themeCode',
        'value': value,
        'kategori': 'theme',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      expect(await preferences.read(), 'system');
      expect((await db.query(DbHelper.table)).single['value'], value);
    }
  });

  test('invalid code fails before opening any database', () async {
    final unopened = DbHelper();
    final prefs = ThemePreferences(database: unopened);
    for (final value in ['LIGHT', 'auto', '', ' dark ']) {
      await expectLater(prefs.write(value), throwsFormatException);
    }
    await unopened.close();
  });

  test('failed change rolls back the previous preference', () async {
    await preferences.write('light');
    final db = await helper.database;
    await db.execute('''CREATE TRIGGER reject_fixture_dark
      BEFORE INSERT ON m_key_value_pair
      WHEN NEW.key = 'themeCode' AND NEW.value = 'dark'
      BEGIN SELECT RAISE(ABORT, 'fixture forced rollback'); END''');
    await expectLater(preferences.write('dark'), throwsStateError);
    expect(await preferences.read(), 'light');
  });

  test(
    'storage failure reports a preference error without row contents',
    () async {
      final db = await helper.database;
      await db.execute('DROP TABLE m_key_value_pair');
      await expectLater(
        preferences.read(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Preferensi tema tidak dapat dibaca dari penyimpanan.',
          ),
        ),
      );
    },
  );
}
