import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static const int _databaseVersion = 6;
  static const String _databaseName = 'checktap_cache.db';

  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null) {
      return current;
    }

    final opened = await _open();
    _database = opened;
    return opened;
  }

  Future<Database> _open() async {
    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, _databaseName);

    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await _createBaseTables(database);
        await _createOfflineTables(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            "ALTER TABLE cached_tasks ADD COLUMN sync_state TEXT NOT NULL DEFAULT 'SYNCED'",
          );
          await database.execute(
            'ALTER TABLE cached_tasks ADD COLUMN server_version INTEGER NOT NULL DEFAULT 1',
          );
          await database.execute(
            'ALTER TABLE cached_tasks ADD COLUMN last_error TEXT',
          );
          await database.execute(
            'ALTER TABLE cached_tasks ADD COLUMN local_updated_at TEXT',
          );
          await database.execute('''
            CREATE TABLE sync_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              operation_id TEXT NOT NULL UNIQUE,
              entity_id TEXT NOT NULL,
              operation_type TEXT NOT NULL,
              base_version INTEGER NOT NULL DEFAULT 0,
              payload_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await database.execute(
            'CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_id)',
          );
        }
        if (oldVersion < 3) {
          await database.execute(
            'ALTER TABLE sync_queue ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0',
          );
          await database.execute(
            'ALTER TABLE sync_queue ADD COLUMN last_error TEXT',
          );
          await database.execute(
            'ALTER TABLE sync_queue ADD COLUMN next_retry_at TEXT',
          );
          await database.execute(
            "ALTER TABLE sync_queue ADD COLUMN state TEXT NOT NULL DEFAULT 'PENDING'",
          );
          await database.execute(
            'CREATE INDEX idx_sync_queue_state_retry ON sync_queue(state, next_retry_at)',
          );
        }
        if (oldVersion < 4) {
          await database.execute(
            'ALTER TABLE cached_tasks ADD COLUMN conflict_json TEXT',
          );
        }
        if (oldVersion < 5) {
          await database.insert('cache_meta', <String, Object?>{
            'key': 'offline_schema_version',
            'value': '5',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (oldVersion < 6) {
          await database.execute(
            'ALTER TABLE cached_users ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
          );
          await database.execute(
            'ALTER TABLE cached_users ADD COLUMN created_at TEXT',
          );
          await database.insert('cache_meta', <String, Object?>{
            'key': 'offline_schema_version',
            'value': '6',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      },
    );
  }

  Future<void> _createBaseTables(Database database) async {
    await database.execute('''
      CREATE TABLE cached_users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        is_admin INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        cached_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE cached_tasks (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        cached_at TEXT NOT NULL,
        sync_state TEXT NOT NULL DEFAULT 'SYNCED',
        server_version INTEGER NOT NULL DEFAULT 1,
        last_error TEXT,
        local_updated_at TEXT,
        conflict_json TEXT
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_cached_tasks_status
      ON cached_tasks(status)
    ''');

    await database.execute('''
      CREATE TABLE cache_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createOfflineTables(Database database) async {
    await database.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_id TEXT NOT NULL UNIQUE,
        entity_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        base_version INTEGER NOT NULL DEFAULT 0,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        next_retry_at TEXT,
        state TEXT NOT NULL DEFAULT 'PENDING'
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_id)',
    );
    await database.execute(
      'CREATE INDEX idx_sync_queue_state_retry ON sync_queue(state, next_retry_at)',
    );
    await database.insert('cache_meta', <String, Object?>{
      'key': 'offline_schema_version',
      'value': '6',
    });
  }

  Future<void> close() async {
    final current = _database;
    _database = null;
    await current?.close();
  }
}
