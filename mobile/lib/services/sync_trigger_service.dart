import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class SyncTriggerService {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  bool _started = false;

  void start(Future<void> Function() onSyncRequested) {
    if (_started) {
      return;
    }
    _started = true;

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any(
        (result) => result != ConnectivityResult.none,
      );
      if (hasNetwork) {
        onSyncRequested();
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      onSyncRequested();
    });
  }

  Future<void> dispose() async {
    _started = false;
    _timer?.cancel();
    await _subscription?.cancel();
  }
}
