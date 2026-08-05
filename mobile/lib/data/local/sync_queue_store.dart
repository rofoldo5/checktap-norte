import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/sync_operation.dart';
import 'local_database.dart';

class SyncQueueStore {
  SyncQueueStore({LocalDatabase? localDatabase})
    : _localDatabase = localDatabase ?? LocalDatabase.instance;

  final LocalDatabase _localDatabase;

  Future<void> enqueue(SyncOperation operation) async {
    final database = await _localDatabase.database;
    await database.insert(
      'sync_queue',
      operation.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<SyncOperation?> readNext() async {
    final database = await _localDatabase.database;
    final rows = await database.query(
      'sync_queue',
      where: "state IN ('PENDING', 'ERROR')",
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final operation = SyncOperation.fromDatabase(rows.first);
    final retryAt = operation.nextRetryAt;
    if (retryAt != null && retryAt.isAfter(DateTime.now().toUtc())) {
      return null;
    }
    return operation;
  }

  Future<int> countPending() async {
    final database = await _localDatabase.database;
    final rows = await database.rawQuery(
      "SELECT COUNT(*) AS total FROM sync_queue WHERE state IN ('PENDING', 'SYNCING', 'ERROR')",
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> markSyncing(int localId) async {
    final database = await _localDatabase.database;
    await database.update(
      'sync_queue',
      <String, Object?>{'state': 'SYNCING'},
      where: 'id = ?',
      whereArgs: <Object?>[localId],
    );
  }

  Future<void> markPending(int localId) async {
    final database = await _localDatabase.database;
    await database.update(
      'sync_queue',
      <String, Object?>{'state': 'PENDING'},
      where: 'id = ?',
      whereArgs: <Object?>[localId],
    );
  }

  Future<void> markError(SyncOperation operation, String error) async {
    final database = await _localDatabase.database;
    final attempts = operation.attempts + 1;
    final seconds = _retrySeconds(attempts);
    final retryAt = DateTime.now().toUtc().add(Duration(seconds: seconds));
    await database.update(
      'sync_queue',
      <String, Object?>{
        'state': 'ERROR',
        'attempts': attempts,
        'last_error': error,
        'next_retry_at': retryAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[operation.localId],
    );
  }

  Future<void> remove(int localId) async {
    final database = await _localDatabase.database;
    await database.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: <Object?>[localId],
    );
  }

  Future<void> updateFollowingBaseVersions(
    String entityId,
    int afterLocalId,
    int version,
  ) async {
    final database = await _localDatabase.database;
    await database.update(
      'sync_queue',
      <String, Object?>{'base_version': version},
      where: 'entity_id = ? AND id > ?',
      whereArgs: <Object?>[entityId, afterLocalId],
    );
  }

  Future<bool> updatePendingCreatePayload(
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    final database = await _localDatabase.database;
    final rows = await database.query(
      'sync_queue',
      columns: <String>['id'],
      where:
          "entity_id = ? AND operation_type = 'CREATE_TASK' AND state IN ('PENDING', 'ERROR')",
      whereArgs: <Object?>[entityId],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    await database.update(
      'sync_queue',
      <String, Object?>{
        'payload_json': jsonEncode(payload),
        'state': 'PENDING',
        'attempts': 0,
        'last_error': null,
        'next_retry_at': null,
      },
      where: 'id = ?',
      whereArgs: <Object?>[rows.first['id']],
    );
    return true;
  }

  Future<bool> updatePendingTaskEdit(
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    final database = await _localDatabase.database;
    final rows = await database.query(
      'sync_queue',
      columns: <String>['id'],
      where:
          "entity_id = ? AND operation_type = 'UPDATE_TASK' AND state IN ('PENDING', 'ERROR')",
      whereArgs: <Object?>[entityId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    await database.update(
      'sync_queue',
      <String, Object?>{
        'payload_json': jsonEncode(payload),
        'state': 'PENDING',
        'attempts': 0,
        'last_error': null,
        'next_retry_at': null,
      },
      where: 'id = ?',
      whereArgs: <Object?>[rows.first['id']],
    );
    return true;
  }

  Future<void> resetInterruptedOperations() async {
    final database = await _localDatabase.database;
    await database.update('sync_queue', <String, Object?>{
      'state': 'PENDING',
    }, where: "state = 'SYNCING'");
  }

  int _retrySeconds(int attempts) {
    const schedule = <int>[5, 15, 30, 60, 120, 300, 600, 900];
    final index = attempts.clamp(1, schedule.length).toInt() - 1;
    return schedule[index];
  }
}
