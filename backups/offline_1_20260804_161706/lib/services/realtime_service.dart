import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/app_config.dart';

class RealtimeService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  Timer? _reconnectTimer;
  bool _disposed = false;

  void connect({
    required String token,
    required void Function() onTaskChanged,
    void Function(bool connected)? onConnectionChanged,
  }) {
    if (_disposed) {
      return;
    }

    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    onConnectionChanged?.call(false);

    final uri = Uri.parse(AppConfig.websocketUrl(token));
    debugPrint('[WS] Conectando a ${uri.replace(query: 'token=***')}');

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    _subscription = channel.stream.listen(
      (event) {
        if (event is String && event.contains('connected')) {
          debugPrint('[WS] Conexion establecida');
          onConnectionChanged?.call(true);
          return;
        }
        debugPrint('[WS] Evento recibido: $event');
        onTaskChanged();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[WS] Error: $error');
        onConnectionChanged?.call(false);
        _scheduleReconnect(
          token,
          onTaskChanged,
          onConnectionChanged,
        );
      },
      onDone: () {
        debugPrint('[WS] Conexion cerrada');
        onConnectionChanged?.call(false);
        _scheduleReconnect(
          token,
          onTaskChanged,
          onConnectionChanged,
        );
      },
      cancelOnError: true,
    );

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      _channel?.sink.add('ping');
    });
  }

  void _scheduleReconnect(
    String token,
    void Function() onTaskChanged,
    void Function(bool connected)? onConnectionChanged,
  ) {
    if (_disposed) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect(
        token: token,
        onTaskChanged: onTaskChanged,
        onConnectionChanged: onConnectionChanged,
      );
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _heartbeat?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
  }
}
