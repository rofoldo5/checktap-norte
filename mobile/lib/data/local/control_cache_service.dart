import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/control_item.dart';
import '../../models/task_item.dart';
import 'local_database.dart';

class ControlCacheSnapshot {
  const ControlCacheSnapshot({required this.sections, required this.checks});

  final List<ControlSectionItem> sections;
  final List<ControlCheckItem> checks;
}

class ControlCacheService {
  ControlCacheService({LocalDatabase? localDatabase})
      : _localDatabase = localDatabase ?? LocalDatabase.instance;

  final LocalDatabase _localDatabase;

  Future<ControlCacheSnapshot> readSnapshot({String? departmentId}) async {
    final sections = await readSections(departmentId: departmentId);
    final sectionIds = sections.map((item) => item.id).toSet();
    final checks = await readChecks().then(
      (items) => items.where((item) => sectionIds.contains(item.sectionId)).toList(),
    );
    return ControlCacheSnapshot(sections: sections, checks: checks);
  }

  Future<List<ControlSectionItem>> readSections({String? departmentId}) async {
    final database = await _localDatabase.database;
    final rows = await database.query(
      'cached_control_sections',
      where: departmentId == null ? null : 'department_id = ?',
      whereArgs: departmentId == null ? null : <Object?>[departmentId],
      orderBy: 'sort_order ASC, local_updated_at DESC, cached_at DESC',
    );
    final checks = await readChecks();
    final bySection = <String, List<ControlCheckItem>>{};
    for (final check in checks) {
      bySection.putIfAbsent(check.sectionId, () => <ControlCheckItem>[]).add(check);
    }

    final result = <ControlSectionItem>[];
    for (final row in rows) {
      try {
        final section = ControlSectionItem.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(row['payload_json'] as String) as Map,
          ),
          syncState: LocalSyncState.fromDatabase(row['sync_state'] as String?),
          syncError: row['last_error'] as String?,
        );
        if (!section.isActive) {
          continue;
        }
        final items = bySection[section.id] ?? const <ControlCheckItem>[];
        var upcoming = 0;
        var urgent = 0;
        var overdue = 0;
        var completed = 0;
        for (final check in items) {
          switch (check.dueState) {
            case 'PROXIMA':
              upcoming += 1;
            case 'URGENTE':
              urgent += 1;
              upcoming += 1;
            case 'VENCIDA':
              overdue += 1;
            case 'COMPLETADA':
              completed += 1;
          }
        }
        result.add(
          section.copyWith(
            checkCount: items.length,
            upcomingCount: upcoming,
            urgentCount: urgent,
            overdueCount: overdue,
            completedCount: completed,
          ),
        );
      } catch (_) {
        // Una fila dañada no debe bloquear el resto del modulo.
      }
    }
    return result;
  }

  Future<List<ControlCheckItem>> readChecks({String? sectionId}) async {
    final database = await _localDatabase.database;
    final rows = await database.query(
      'cached_control_checks',
      where: sectionId == null ? null : 'section_id = ?',
      whereArgs: sectionId == null ? null : <Object?>[sectionId],
      orderBy: 'due_at ASC, sort_order ASC, local_updated_at DESC, cached_at DESC',
    );
    final result = <ControlCheckItem>[];
    for (final row in rows) {
      try {
        result.add(
          ControlCheckItem.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(row['payload_json'] as String) as Map,
            ),
            syncState: LocalSyncState.fromDatabase(row['sync_state'] as String?),
            syncError: row['last_error'] as String?,
          ),
        );
      } catch (_) {
        // Ignorar una fila dañada.
      }
    }
    return result;
  }

  Future<ControlCheckItem?> readCheck(String id) async {
    final database = await _localDatabase.database;
    final rows = await database.query(
      'cached_control_checks',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    try {
      return ControlCheckItem.fromJson(
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

  Future<void> replaceServerSnapshotPreservingLocal(
    List<ControlSectionItem> sections,
    List<ControlCheckItem> checks,
  ) async {
    final database = await _localDatabase.database;
    final cachedAt = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      final localSectionRows = await transaction.query(
        'cached_control_sections',
        columns: <String>['id'],
        where: "sync_state != 'SYNCED'",
      );
      final localCheckRows = await transaction.query(
        'cached_control_checks',
        columns: <String>['id'],
        where: "sync_state != 'SYNCED'",
      );
      final protectedSections = localSectionRows.map((row) => row['id'] as String).toSet();
      final protectedChecks = localCheckRows.map((row) => row['id'] as String).toSet();

      await transaction.delete('cached_control_sections', where: "sync_state = 'SYNCED'");
      await transaction.delete('cached_control_checks', where: "sync_state = 'SYNCED'");

      final batch = transaction.batch();
      for (var index = 0; index < sections.length; index += 1) {
        final section = sections[index];
        if (protectedSections.contains(section.id)) {
          continue;
        }
        batch.insert(
          'cached_control_sections',
          _sectionRow(
            section.copyWith(syncState: LocalSyncState.synced, syncError: null),
            cachedAt: cachedAt,
            sortOrder: index,
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (var index = 0; index < checks.length; index += 1) {
        final check = checks[index];
        if (protectedChecks.contains(check.id)) {
          continue;
        }
        batch.insert(
          'cached_control_checks',
          _checkRow(
            check.copyWith(syncState: LocalSyncState.synced, syncError: null),
            cachedAt: cachedAt,
            sortOrder: index,
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertSection(ControlSectionItem section) async {
    final database = await _localDatabase.database;
    await database.insert(
      'cached_control_sections',
      _sectionRow(section),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertCheck(ControlCheckItem check) async {
    final database = await _localDatabase.database;
    await database.insert(
      'cached_control_checks',
      _checkRow(check),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markEntityState(
    String entityId,
    LocalSyncState state, {
    String? error,
  }) async {
    final database = await _localDatabase.database;
    final values = <String, Object?>{
      'sync_state': state.databaseValue,
      'last_error': error,
      'local_updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final checks = await database.update(
      'cached_control_checks',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[entityId],
    );
    if (checks == 0) {
      await database.update(
        'cached_control_sections',
        values,
        where: 'id = ?',
        whereArgs: <Object?>[entityId],
      );
    }
  }

  Future<void> deleteCheck(String id) async {
    final database = await _localDatabase.database;
    await database.delete(
      'cached_control_checks',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> deleteSection(String id) async {
    final database = await _localDatabase.database;
    await database.delete(
      'cached_control_checks',
      where: 'section_id = ?',
      whereArgs: <Object?>[id],
    );
    await database.delete(
      'cached_control_sections',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Map<String, Object?> _sectionRow(
    ControlSectionItem section, {
    String? cachedAt,
    int sortOrder = 0,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return <String, Object?>{
      'id': section.id,
      'department_id': section.department.id,
      'payload_json': jsonEncode(section.toJson()),
      'sort_order': sortOrder,
      'cached_at': cachedAt ?? now,
      'sync_state': section.syncState.databaseValue,
      'server_version': section.version,
      'last_error': section.syncError,
      'local_updated_at': now,
      'conflict_json': section.syncState == LocalSyncState.conflict
          ? jsonEncode(section.toJson())
          : null,
    };
  }

  Map<String, Object?> _checkRow(
    ControlCheckItem check, {
    String? cachedAt,
    int sortOrder = 0,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return <String, Object?>{
      'id': check.id,
      'section_id': check.sectionId,
      'status': check.status,
      'due_at': check.dueAt.toUtc().toIso8601String(),
      'payload_json': jsonEncode(check.toJson()),
      'sort_order': sortOrder,
      'cached_at': cachedAt ?? now,
      'sync_state': check.syncState.databaseValue,
      'server_version': check.version,
      'last_error': check.syncError,
      'local_updated_at': now,
      'conflict_json': check.syncState == LocalSyncState.conflict
          ? jsonEncode(check.toJson())
          : null,
    };
  }
}
