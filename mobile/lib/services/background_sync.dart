import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../core/api_client.dart';
import '../data/local/offline_cache_service.dart';
import '../data/repositories/task_repository.dart';
import 'secure_session_storage.dart';

const String checkTapBackgroundTask = 'checktap.background.sync';
const String checkTapPeriodicUniqueName = 'checktap-periodic-sync';

@pragma('vm:entry-point')
void checkTapCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    try {
      const storage = SecureSessionStorage();
      final token = await storage.readToken();
      if (token == null || token.isEmpty) {
        return true;
      }

      final apiClient = ApiClient()..setToken(token);
      final repository = TaskRepository(apiClient);
      final summary = await repository.synchronizePending();
      if (summary.unauthorized) {
        await storage.clear();
        return true;
      }
      if (!summary.serverAvailable) {
        return false;
      }

      await repository.refreshFromServer();
      await OfflineCacheService().writeLastBackgroundSyncAt(
        DateTime.now().toUtc(),
      );
      return summary.errors == 0;
    } catch (error, stackTrace) {
      debugPrint('[BACKGROUND_SYNC] $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  });
}

class BackgroundSyncScheduler {
  BackgroundSyncScheduler._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    final supported =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (_initialized || kIsWeb || !supported) {
      return;
    }
    try {
      await Workmanager().initialize(checkTapCallbackDispatcher);
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Workmanager().registerPeriodicTask(
          checkTapPeriodicUniqueName,
          checkTapBackgroundTask,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
        );
      }
      _initialized = true;
    } catch (error) {
      debugPrint('[BACKGROUND_SYNC] No se pudo registrar: $error');
    }
  }

  static Future<void> scheduleOneOff() async {
    final supported =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!_initialized ||
        kIsWeb ||
        !supported ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await Workmanager().registerOneOffTask(
        'checktap-sync-${DateTime.now().millisecondsSinceEpoch}',
        checkTapBackgroundTask,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (error) {
      debugPrint('[BACKGROUND_SYNC] No se pudo programar reintento: $error');
    }
  }
}
