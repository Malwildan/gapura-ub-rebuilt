import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Opens this reconstructed application's own database directory. It never
/// searches another app's sandbox or opens the installed official app's files.
class DbHelper {
  DbHelper({DatabaseFactory? factory, String? databasePath})
    : _factory = factory,
      _databasePath = databasePath;

  // Both literals are observed in the original APK. Its user_version was not
  // recovered; version 1 below is this reconstruction's own schema revision.
  static const filename = 'gapura-ub-mobile-v9.db';
  static const table = 'm_key_value_pair';
  static const createTable =
      'CREATE TABLE m_key_value_pair (key TEXT PRIMARY KEY, value TEXT, kategori TEXT)';

  final DatabaseFactory? _factory;
  final String? _databasePath;
  Future<Database>? _opening;

  Future<Database> get database async {
    final opening = _opening ??= _open();
    try {
      return await opening;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    // Resolve the mobile plugin only on actual storage access. Constructing
    // the facade, including a test subclass, has no platform side effects.
    final factory = _factory ?? databaseFactory;
    final destination =
        _databasePath ?? path.join(await factory.getDatabasesPath(), filename);
    return factory.openDatabase(
      destination,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(createTable),
      ),
    );
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) await (await opening).close();
    _opening = null;
  }
}
