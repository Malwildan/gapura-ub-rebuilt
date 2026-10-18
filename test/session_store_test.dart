import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/model/m_key_value_pair.dart';
import 'package:gapura_ub/service/session_store.dart';
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
  late SqliteSessionStore store;

  setUp(() {
    helper = DbHelper(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    store = SqliteSessionStore(database: helper);
  });

  tearDown(() => helper.close());

  Map<String, dynamic> session([String suffix = 'old']) => {
    'accessToken': 'fixture-access-$suffix',
    'refreshToken': 'fixture-refresh-$suffix',
    'idToken': 'fixture-id-$suffix',
    'expiresAt': 2000000000000,
    'username': 'fixture-account',
  };

  test(
    'constructing and closing unused storage never resolves the mobile plugin',
    () async {
      final unused = DbHelper();
      expect(SqliteSessionStore(database: unused), isA<SessionStore>());
      await unused.close();
    },
  );

  test('uses exact recovered filename and SQLite schema', () async {
    expect(DbHelper.filename, 'gapura-ub-mobile-v9.db');
    final db = await helper.database;
    final schema = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type='table' AND name='m_key_value_pair'",
    );
    expect(schema.single['sql'], DbHelper.createTable);
    final columns = await db.rawQuery('PRAGMA table_info(m_key_value_pair)');
    expect(columns.map((row) => row['name']), ['key', 'value', 'kategori']);
    expect(columns.map((row) => row['type']), ['TEXT', 'TEXT', 'TEXT']);
    expect(columns.first['pk'], 1);
    expect(await store.read(), isNull);
  });

  test(
    'stores individual original token keys and explicit reconstruction metadata',
    () async {
      final record = session();
      await store.write(record);
      final db = await helper.database;
      final rows = await db.query(DbHelper.table);
      expect(rows.map((row) => row['key']).toSet(), {
        'accessToken',
        'refreshToken',
        'idToken',
        SqliteSessionStore.expiresAtKey,
        SqliteSessionStore.usernameKey,
      });
      expect(rows.every((row) => row['kategori'] == null), true);
      expect(await store.read(), record);
      // Separate repository instances see the same SQLite-backed state.
      expect(await SqliteSessionStore(database: helper).read(), record);
      final copied = ModelKeyValuePair.fromMap(rows.first);
      expect(copied.toMap(), rows.first);
    },
  );

  test(
    'refresh rotates token rows and removes absent optional tokens',
    () async {
      await store.write(session());
      final replacement = {
        ...session('new'),
        'idToken': null,
        'refreshToken': null,
      };
      await store.write(replacement);
      expect(await store.read(), replacement);
      final db = await helper.database;
      expect(
        await db.query(
          DbHelper.table,
          where: 'key IN (?, ?)',
          whereArgs: ['refreshToken', 'idToken'],
        ),
        isEmpty,
      );
    },
  );

  test(
    'SQLite failure rolls back every row of a session replacement',
    () async {
      await store.write(session());
      final db = await helper.database;
      await db.execute('''CREATE TRIGGER reject_fixture_refresh
      BEFORE INSERT ON m_key_value_pair
      WHEN NEW.key = 'refreshToken' AND NEW.value = 'fixture-refresh-new'
      BEGIN SELECT RAISE(ABORT, 'fixture forced rollback'); END''');
      await expectLater(
        store.write(session('new')),
        throwsA(isA<DatabaseException>()),
      );
      expect(await store.read(), session());
    },
  );

  test('clear is atomic and preserves unrelated key-value rows', () async {
    await store.write(session());
    final db = await helper.database;
    await db.insert(
      DbHelper.table,
      const ModelKeyValuePair(
        key: 'fixture.preference',
        value: 'retained',
      ).toMap(),
    );
    await db.execute('''CREATE TRIGGER reject_fixture_delete
      BEFORE DELETE ON m_key_value_pair WHEN OLD.key = 'refreshToken'
      BEGIN SELECT RAISE(ABORT, 'fixture forced rollback'); END''');
    await expectLater(store.clear(), throwsA(isA<DatabaseException>()));
    expect(await store.read(), session());
    await db.execute('DROP TRIGGER reject_fixture_delete');
    await store.clear();
    expect(await store.read(), isNull);
    final remaining = await db.query(DbHelper.table);
    expect(remaining.length, 1);
    expect(remaining.single['key'], 'fixture.preference');
  });
}
