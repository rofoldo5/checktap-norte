import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

import '../data/local/offline_cache_service.dart';
import '../data/local/sync_queue_store.dart';
import '../models/task_item.dart';
import 'task_service.dart';

class SyncSummary {
  const SyncSummary({
    required this.processed,
    required this.applied,
    required this.conflicts,
    required this.errors,
    required this.pending,
    required this.serverAvailable,
    this.unauthorized = false,
  });

  final int processed;
  final int applied;
  final int conflicts;
  final int errors;
  final int pending;
  final bool serverAvailable;
  final bool unauthorized;

  bool get hasChanges => processed > 0;
}

class SyncService {
  SyncService(this._remote, {OfflineCacheService? cache, SyncQueueStore? queue})
    : _cache = cache ?? OfflineCacheService(),
      _queue = queue ?? SyncQueueStore();

  final TaskService _remote;
  final OfflineCacheService _cache;
  final SyncQueueStore _queue;
  final Lock _lock = Lock();

  Future<SyncSummary> synchronize() {
    return _lock.synchronized(_synchronizeLocked);
  }

  Future<SyncSummary> _synchronizeLocked() async {
    await _queue.resetInterruptedOperations();
    var processed = 0;
    var applied = 0;
    var conflicts = 0;
    var errors = 0;
    var serverAvailable = true;
    var unauthorized = false;
    var safetyCounter = 0;

    while (safetyCounter < 100) {
      safetyCounter += 1;
      final operation = await _queue.readNext();
      if (operation == null) {
        break;
      }

      final localId = operation.localId;
      if (localId == null) {
        break;
      }

      await _queue.markSyncing(localId);
      await _cache.markTaskState(operation.entityId, LocalSyncState.syncing);

      try {
        final result = await _remote.processOperation(operation);
        processed += 1;

        if (result.status == 'APPLIED' || result.status == 'DUPLICATE') {
          final taskJson = result.taskJson;
          if (taskJson == null) {
            throw StateError('El servidor no devolvio la tarea sincronizada.');
          }
          final serverTask = TaskItem.fromJson(
            taskJson,
            syncState: LocalSyncState.synced,
          );
          final hasFollowing = await _queue.hasFollowingOperations(
            operation.entityId,
            localId,
          );
          if (hasFollowing) {
            final localTask = await _cache.readTask(operation.entityId);
            final merged =
                localTask?.copyWith(
                  version: serverTask.version,
                  syncState: LocalSyncState.pending,
                  syncError: null,
                ) ??
                serverTask.copyWith(syncState: LocalSyncState.pending);
            await _cache.upsertTask(merged);
          } else {
            await _cache.upsertTask(serverTask);
          }
          await _queue.remove(localId);
          await _queue.updateFollowingBaseVersions(
            operation.entityId,
            localId,
            serverTask.version,
          );
          applied += 1;
          continue;
        }

        if (result.status == 'CONFLICT') {
          final taskJson = result.taskJson;
          if (taskJson != null) {
            final serverTask = TaskItem.fromJson(
              taskJson,
              syncState: LocalSyncState.conflict,
              syncError: result.detail,
            );
            await _cache.upsertTask(serverTask);
            await _queue.updateFollowingBaseVersions(
              operation.entityId,
              localId,
              serverTask.version,
            );
          } else {
            await _cache.markTaskState(
              operation.entityId,
              LocalSyncState.conflict,
              error: result.detail,
            );
          }
          await _queue.remove(localId);
          conflicts += 1;
          continue;
        }

        final detail = result.detail ?? 'La operacion no pudo sincronizarse.';
        await _queue.markError(operation, detail);
        await _cache.markTaskState(
          operation.entityId,
          LocalSyncState.error,
          error: detail,
        );
        errors += 1;
        break;
      } on DioException catch (error) {
        final statusCode = error.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          unauthorized = true;
        }
        if (error.response == null || statusCode == null || statusCode >= 500) {
          serverAvailable = false;
          await _queue.markPending(localId);
          await _cache.markTaskState(
            operation.entityId,
            LocalSyncState.pending,
          );
          break;
        }

        final detail = _messageFromDio(error);
        await _queue.markError(operation, detail);
        await _cache.markTaskState(
          operation.entityId,
          LocalSyncState.error,
          error: detail,
        );
        errors += 1;
        break;
      } catch (error, stackTrace) {
        debugPrint('[SYNC] Error procesando ${operation.operationId}: $error');
        debugPrintStack(stackTrace: stackTrace);
        await _queue.markError(operation, error.toString());
        await _cache.markTaskState(
          operation.entityId,
          LocalSyncState.error,
          error: error.toString(),
        );
        errors += 1;
        break;
      }
    }

    final pending = await _queue.countPending();
    return SyncSummary(
      processed: processed,
      applied: applied,
      conflicts: conflicts,
      errors: errors,
      pending: pending,
      serverAvailable: serverAvailable,
      unauthorized: unauthorized,
    );
  }

  String _messageFromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] != null) {
      return data['detail'].toString();
    }
    return error.message ?? 'Error de sincronizacion';
  }
}
