import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/repositories/task_repository.dart';
import '../services/session_store.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({required this.session, super.key});

  final SessionStore session;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final TaskRepository _repository;
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = TaskRepository(widget.session.apiClient);
  }

  String _dayLabel(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String _fileDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _date = selected);
    }
  }

  Future<void> _downloadAndShare(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final shareOrigin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await _repository.downloadDailyReport(_date);
      if (!mounted) {
        return;
      }
      await Share.shareXFiles(
        <XFile>[
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: 'informe-checktap-${_fileDate(_date)}.pdf',
          ),
        ],
        subject: 'Informe diario CheckTap ${_dayLabel(_date)}',
        text: 'Informe diario de tareas de CheckTap.',
        sharePositionOrigin: shareOrigin,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.response == null) {
        return 'La generacion del informe requiere conexion con el servidor.';
      }
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informe diario')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Icon(Icons.picture_as_pdf, size: 72),
          const SizedBox(height: 18),
          Text(
            'Generar informe PDF',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          const Text(
            'El informe resume las tareas completadas durante la fecha seleccionada y puede compartirse desde Android o iOS.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _loading ? null : _selectDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(_dayLabel(_date)),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (buttonContext) {
              return FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () => _downloadAndShare(buttonContext),
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                label: const Text('Generar y compartir PDF'),
              );
            },
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
