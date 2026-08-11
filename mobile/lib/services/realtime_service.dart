import 'dart:async';
import 'dart:convert';

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
    void Function(Map<String, dynamic> event)? onEvent,
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
        final decoded = _decodeEvent(event);
        if (decoded?['event'] == 'connected') {
          debugPrint('[WS] Conexion establecida');
          onConnectionChanged?.call(true);
          return;
        }
        debugPrint('[WS] Evento recibido: $event');
        if (decoded != null) {
          onEvent?.call(decoded);
          final eventName = decoded['event']?.toString() ?? '';
          if (eventName.startsWith('task.')) {
            onTaskChanged();
          }
          return;
        }
        onTaskChanged();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[WS] Error: $error');
        onConnectionChanged?.call(false);
        _scheduleReconnect(token, onTaskChanged, onConnectionChanged, onEvent);
      },
      onDone: () {
        debugPrint('[WS] Conexion cerrada');
        onConnectionChanged?.call(false);
        _scheduleReconnect(token, onTaskChanged, onConnectionChanged, onEvent);
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
    void Function(Map<String, dynamic> event)? onEvent,
  ) {
    if (_disposed) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connect(
        token: token,
        onTaskChanged: onTaskChanged,
        onConnectionChanged: onConnectionChanged,
        onEvent: onEvent,
      );
    });
  }

  Map<String, dynamic>? _decodeEvent(dynamic event) {
    if (event is! String) {
      return null;
    }
    try {
      final decoded = jsonDecode(event);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _heartbeat?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
  }
}
