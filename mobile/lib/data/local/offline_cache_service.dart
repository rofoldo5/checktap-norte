import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/app_user.dart';
import '../../models/department.dart';
import '../../models/task_item.dart';
import 'local_database.dart';

class CachedDashboardData {
  const CachedDashboardData({
    required this.tasks,
    required this.users,
    required this.departments,
    required this.lastSyncAt,
    required this.pendingOperations,
  });

  final List<TaskItem> tasks;
  final List<AppUser> users;
  final List<DepartmentSummary> departments;
  final DateTime? lastSyncAt;
  final int pendingOperations;

  bool get hasCachedContent {
    return tasks.isNotEmpty ||
        users.isNotEmpty ||
        departments.isNotEmpty ||
        lastSyncAt != null;
  }
}

class OfflineCacheService {
  OfflineCacheService({LocalDatabase? localDatabase})
    : _localDatabase = localDatabase ?? LocalDatabase.instance;

  static const String _lastSyncKey = 'last_successful_sync';
  static const String _lastBackgroundSyncKey = 'last_background_sync';

  final LocalDatabase _localDatabase;

  Future<CachedDashboardData> readDashboard({
    String? status,
    String? departmentId,
  }) async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      readTasks(status: status, departmentId: departmentId),
      readUsers(),
      readDepartments(),
      readLastSyncAt(),
      countPendingOperations(),
    ]);

    return CachedDashboardData(
      tasks: results[0] as List<TaskItem>,
      users: results[1] as List<AppUser>,
      departments: results[2] as List<DepartmentSummary>,
      lastSyncAt: results[3] as DateTime?,
      pendingOperations: results[4] as int,
    );
  }

  Future<List<TaskItem>> readTasks({
    String? status,
    String? departmentId,
  }) async {
    final database = await _localDatabase.database;
    final clauses = <String>[];
    final arguments = <Object?>[];
    if (status != null) {
      clauses.add('status = ?');
      arguments.add(status);
    }
    if (departmentId != null) {
      clauses.add('department_id = ?');
      arguments.add(departmentId);
    }

    final rows = await database.query(
      'cached_tasks',
      columns: <String>['payload_json', 'sync_state', 'last_error'],
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'sort_order ASC, local_updated_at DESC, cached_at DESC',
    );

    final tasks = <TaskItem>[];
    for (final row in rows) {
      try {
        final payload = jsonDecode(row['payload_json'] as String);
        tasks.add(
          TaskItem.fromJson(
            Map<String, dynamic>.from(payload as Map),
            syncState: LocalSyncState.fromDatabase(
              row['sync_state'] as String?,
            ),
            syncError: row['last_error'] as String?,
          ),
        );
      } catch (_) {
        // Una fila dañada no debe bloquear el resto del tablero.
      }
    }
    return tasks;
  }

  Future<TaskItem?> readTask(String id) async {
    final database = await _localDatabase.database;
    final rows = await database.query(
      'cached_tasks',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    try {
      return TaskItem.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(row['payload_json'] as String) as Map,
        ),
        syncState: LocalSyncState.fromDatabase(row['sync_state'] as String?),
        syncError: row['last_error'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<AppUser>> readUsers() async {
    final database = await _localDatabase.database;
    final rows = await database.query(
      'cached_users',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map(
          (row) => AppUser(
            id: row['id'] as String,
            name: row['name'] as String,
            email: row['email'] as String,
            isAdmin: (row['is_admin'] as int? ?? 0) == 1,
            isActive: (row['is_active'] as int? ?? 1) == 1,
            departmentIds:
                (jsonDecode(row['department_ids_json'] as String? ?? '[]')
                        as List<dynamic>)
                    .map((item) => item.toString())
                    .toList(),
            createdAt: row['created_at'] == null
                ? null
                : DateTime.tryParse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<List<DepartmentSummary>> readDepartments() async {
    final database = await _localDatabase.database;
    final rows = await database.query(
      'cached_departments',
      orderBy: 'is_active DESC, name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => DepartmentSummary(
            id: row['id'] as String,
            name: row['name'] as String,
            isActive: (row['is_active'] as int? ?? 1) == 1,
            memberCount: row['member_count'] as int? ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<void> replaceServerTasksPreservingLocal(List<TaskItem> tasks) async {
    final database = await _localDatabase.database;
    final cachedAt = DateTime.now().toUtc().toIso8601String();

    await database.transaction((transaction) async {
      final localRows = await transaction.query(
        'cached_tasks',
        columns: <String>['id'],
        where: "sync_state != 'SYNCED'",
      );
      final protectedIds = localRows.map((row) => row['id'] as String).toSet();

      await transaction.delete('cached_tasks', where: "sync_state = 'SYNCED'");

      final batch = transaction.batch();
      for (var index = 0; index < tasks.length; index += 1) {
        final task = tasks[index];
        if (protectedIds.contains(task.id)) {
          continue;
        }
        batch.insert(
          'cached_tasks',
          _taskRow(
            task.copyWith(syncState: LocalSyncState.synced, syncError: null),
            cachedAt: cachedAt,
            sortOrder: index,
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> replaceUsers(List<AppUser> users) async {
    final database = await _localDatabase.database;
    final cachedAt = DateTime.now().toUtc().toIso8601String();

    await database.transaction((transaction) async {
      await transaction.delete('cached_users');
      final batch = transaction.batch();
      for (final user in users) {
        batch.insert('cached_users', <String, Object?>{
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'is_admin': user.isAdmin ? 1 : 0,
          'is_active': user.isActive ? 1 : 0,
          'created_at': user.createdAt?.toUtc().toIso8601String(),
          'department_ids_json': jsonEncode(user.departmentIds),
          'cached_at': cachedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> replaceDepartments(List<DepartmentSummary> departments) async {
    final database = await _localDatabase.database;
    final cachedAt = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      await transaction.delete('cached_departments');
      final batch = transaction.batch();
      for (final department in departments) {
        batch.insert('cached_departments', <String, Object?>{
          'id': department.id,
          'name': department.name,
          'is_active': department.isActive ? 1 : 0,
          'member_count': department.memberCount,
          'cached_at': cachedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertTask(TaskItem task) async {
    final database = await _localDatabase.database;
    await database.insert(
      'cached_tasks',
      _taskRow(task),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markTaskState(
    String taskId,
    LocalSyncState state, {
    String? error,
  }) async {
    final database = await _localDatabase.database;
    await database.update(
      'cached_tasks',
      <String, Object?>{
        'sync_state': state.databaseValue,
        'last_error': error,
        'local_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[taskId],
    );
  }

  Future<void> resolveConflict(String taskId) async {
    final database = await _localDatabase.database;
    await database.update(
      'cached_tasks',
      <String, Object?>{
        'sync_state': LocalSyncState.synced.databaseValue,
        'last_error': null,
        'conflict_json': null,
        'local_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[taskId],
    );
  }

  Future<void> writeLastSyncAt(DateTime value) async {
    await writeMeta(_lastSyncKey, value.toUtc().toIso8601String());
  }

  Future<DateTime?> readLastSyncAt() async {
    final value = await readMeta(_lastSyncKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<void> writeLastBackgroundSyncAt(DateTime value) async {
    await writeMeta(_lastBackgroundSyncKey, value.toUtc().toIso8601String());
  }

  Future<void> writeMeta(String key, String value) async {
    final database = await _localDatabase.database;
    await database.insert('cache_meta', <String, Object?>{
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> readMeta(String key) async {
    final database = await _localDatabase.database;
    final rows = await database.query(
      'cache_meta',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<int> countPendingOperations() async {
    final database = await _localDatabase.database;
    final result = await database.rawQuery(
      "SELECT COUNT(*) AS total FROM sync_queue WHERE state IN ('PENDING', 'SYNCING', 'ERROR')",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Map<String, Object?> _taskRow(
    TaskItem task, {
    String? cachedAt,
    int sortOrder = 0,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return <String, Object?>{
      'id': task.id,
      'status': task.status,
      'department_id': task.department.id == DepartmentSummary.unknown.id
          ? null
          : task.department.id,
      'payload_json': jsonEncode(task.toJson()),
      'sort_order': sortOrder,
      'cached_at': cachedAt ?? now,
      'sync_state': task.syncState.databaseValue,
      'server_version': task.version,
      'last_error': task.syncError,
      'local_updated_at': now,
      'conflict_json': task.syncState == LocalSyncState.conflict
          ? jsonEncode(task.toJson())
          : null,
    };
  }
}
