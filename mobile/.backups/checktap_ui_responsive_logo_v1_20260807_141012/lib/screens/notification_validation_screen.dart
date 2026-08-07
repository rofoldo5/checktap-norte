import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../firebase_options.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';
import '../services/notification_service.dart';

class NotificationValidationScreen extends StatefulWidget {
  const NotificationValidationScreen({super.key});

  @override
  State<NotificationValidationScreen> createState() =>
      _NotificationValidationScreenState();
}

class _NotificationValidationScreenState
    extends State<NotificationValidationScreen> {
  final NotificationService _service = NotificationService.instance;
  bool _busy = false;
  String? _feedback;
  Map<String, dynamic>? _backendStatus;

  @override
  void initState() {
    super.initState();
    _service.authorizationStatus.addListener(_refresh);
    _service.token.addListener(_refresh);
    _service.lastEvent.addListener(_refresh);
    _service.initializationError.addListener(_refresh);
    _service.backendRegistrationStatus.addListener(_refresh);
    unawaited(_loadStatus());
  }

  @override
  void dispose() {
    _service.authorizationStatus.removeListener(_refresh);
    _service.token.removeListener(_refresh);
    _service.lastEvent.removeListener(_refresh);
    _service.initializationError.removeListener(_refresh);
    _service.backendRegistrationStatus.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadStatus() async {
    try {
      await _service.refreshStatus();
      final status = await _service.fetchBackendStatus();
      if (mounted) {
        setState(() => _backendStatus = status);
      }
    } catch (error, stackTrace) {
      debugPrint('[FCM][STATUS] $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _feedback = 'No se pudo consultar el estado: $error');
      }
    }
  }

  Future<void> _activate() async {
    await _run(() async {
      final registered = await _service.registerCurrentDevice(
        requestPermission: true,
        force: true,
      );
      if (!registered) {
        _feedback =
            'No se pudo completar el registro. Revise permiso y conexion.';
        return;
      }
      _backendStatus = await _service.fetchBackendStatus();
      _feedback = 'Notificaciones activadas y dispositivo registrado.';
    });
  }

  Future<void> _showLocalTest() async {
    await _run(() async {
      var status = _service.authorizationStatus.value;
      if (status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        final result = await _service.requestPermissionAndToken();
        status = result.authorizationStatus;
      }

      if (status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        _feedback = 'Autorice las notificaciones para ejecutar la prueba.';
        return;
      }

      await _service.showLocalTestNotification();
      _feedback = 'Prueba local enviada. Revise la bandeja de notificaciones.';
    });
  }

  Future<void> _showBackendTest() async {
    await _run(() async {
      final result = await _service.sendBackendTest();
      final attempted = result['attempted'] ?? 0;
      final success = result['success_count'] ?? 0;
      final failed = result['failure_count'] ?? 0;
      _backendStatus = await _service.fetchBackendStatus();
      _feedback =
          'Prueba servidor: intentos $attempted, enviados $success, fallos $failed.';
    });
  }

  Future<void> _showDepartmentTest() async {
    await _run(() async {
      final result = await _service.sendDepartmentTest();
      final attempted = result['attempted'] ?? 0;
      final success = result['success_count'] ?? 0;
      final failed = result['failure_count'] ?? 0;
      _feedback =
          'Prueba de equipo: dispositivos $attempted, enviados $success, fallos $failed.';
    });
  }

  Future<void> _updateStatus() async {
    await _run(() async {
      await _service.refreshStatus();
      _backendStatus = await _service.fetchBackendStatus();
      _feedback = 'Estado de Firebase y del servidor actualizado.';
    });
  }

  Future<void> _regenerateToken() async {
    await _run(() async {
      final currentToken = await _service.regenerateToken();
      if (currentToken == null || currentToken.isEmpty) {
        _feedback = 'FCM no devolvio un token nuevo.';
        return;
      }
      _backendStatus = await _service.fetchBackendStatus();
      _feedback = 'Token FCM regenerado y registrado automaticamente.';
    });
  }

  Future<void> _copyToken() async {
    final currentToken = _service.token.value;
    if (currentToken == null || currentToken.isEmpty) {
      _showSnackBar('Primero active las notificaciones para generar el token.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: currentToken));
    if (!mounted) {
      return;
    }
    _showSnackBar('Token FCM copiado. No lo comparta publicamente.');
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _feedback = null;
    });

    try {
      await operation();
    } catch (error, stackTrace) {
      debugPrint('[FCM][UI] $error');
      debugPrintStack(stackTrace: stackTrace);
      _feedback = 'Error: $error';
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _permissionLabel(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized => 'Autorizado',
      AuthorizationStatus.provisional => 'Provisional',
      AuthorizationStatus.denied => 'Denegado o no solicitado',
      AuthorizationStatus.notDetermined => 'Sin solicitar',
    };
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}:'
        '${twoDigits(local.second)}';
  }

  String _backendValue(String key, {String fallback = 'No disponible'}) {
    final value = _backendStatus?[key];
    return value?.toString() ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final token = _service.token.value;
    final error = _service.initializationError.value;
    final event = _service.lastEvent.value;
    final project = DefaultFirebaseOptions.currentPlatform;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _StatusCard(
            title: 'Firebase de la aplicacion',
            icon: Icons.local_fire_department,
            children: <Widget>[
              _StatusRow(label: 'Proyecto', value: project.projectId),
              _StatusRow(label: 'App ID', value: project.appId),
              _StatusRow(
                label: 'Inicializacion',
                value: error == null ? 'Correcta' : 'Con error',
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _StatusCard(
            title: 'Servidor CheckTap',
            icon: Icons.dns,
            children: <Widget>[
              _StatusRow(
                label: 'Registro',
                value: _service.backendRegistrationStatus.value ?? 'Pendiente',
              ),
              _StatusRow(
                label: 'Firebase',
                value: _backendValue('initialized'),
              ),
              _StatusRow(label: 'Proyecto', value: _backendValue('project_id')),
              _StatusRow(
                label: 'Dispositivos',
                value: _backendValue('active_registrations', fallback: '0'),
              ),
              if (_backendStatus?['error'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(
                    _backendStatus!['error'].toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _StatusCard(
            title: 'Dispositivo',
            icon: Icons.phone_android,
            children: <Widget>[
              _StatusRow(
                label: 'Permiso',
                value: _permissionLabel(_service.authorizationStatus.value),
              ),
              _StatusRow(
                label: 'Token FCM',
                value: NotificationService.maskToken(token),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _busy ? null : _activate,
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Activar y registrar'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _showBackendTest,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Prueba servidor'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _showDepartmentTest,
                    icon: const Icon(Icons.groups),
                    label: const Text('Prueba de equipo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _showLocalTest,
                    icon: const Icon(Icons.notification_add),
                    label: const Text('Prueba local'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _regenerateToken,
                    icon: const Icon(Icons.sync_lock),
                    label: const Text('Regenerar token'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || token == null ? null : _copyToken,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar token FCM'),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _updateStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar estado'),
                  ),
                ],
              ),
              if (_busy) ...<Widget>[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_feedback != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(_feedback!),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _StatusCard(
            title: 'Ultimo evento',
            icon: Icons.history,
            children: <Widget>[
              if (event == null)
                const Text('Todavia no se ha recibido ninguna notificacion.')
              else ...<Widget>[
                _StatusRow(label: 'Origen', value: event.source),
                _StatusRow(
                  label: 'Fecha',
                  value: _formatDate(event.receivedAt),
                ),
                if (event.messageId != null)
                  _StatusRow(label: 'Message ID', value: event.messageId!),
                if (event.title != null)
                  _StatusRow(label: 'Titulo', value: event.title!),
                if (event.body != null)
                  _StatusRow(label: 'Mensaje', value: event.body!),
                if (event.data.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SelectableText('Datos: ${event.data}'),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const _StatusCard(
            title: 'Operacion automatica',
            icon: Icons.auto_awesome,
            children: <Widget>[
              Text(
                'El dispositivo se registra despues del login y cuando FCM '
                'renueva el token. El servidor avisa a todos los dispositivos '
                'del departamento cuando alguien crea, modifica, inicia, '
                'completa o reabre una tarea. El aviso identifica a la persona '
                'que realizo la accion.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(CheckTapRadius.lg),
        border: Border.all(color: CheckTapColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: CheckTapColors.navy.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CheckTapColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(CheckTapRadius.sm),
                ),
                child: Icon(icon, color: CheckTapColors.primary, size: 21),
              ),
              const SizedBox(width: CheckTapSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: CheckTapSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
