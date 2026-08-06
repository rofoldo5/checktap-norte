import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/repositories/task_repository.dart';
import '../models/daily_report.dart';
import '../models/department.dart';
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
  List<DailyReportItem> _reports = <DailyReportItem>[];
  List<DepartmentSummary> _departments = <DepartmentSummary>[];
  String? _selectedDepartmentId;
  bool _loading = false;
  bool _loadingList = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = TaskRepository(widget.session.apiClient);
    _loadInitial();
  }

  List<DepartmentSummary> get _activeDepartments => _departments
      .where((department) => department.isActive)
      .toList(growable: false);

  String _dayLabel(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String _fileDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingList = true;
      _error = null;
    });
    try {
      final departments = await _repository.listDepartments();
      final active = departments
          .where((department) => department.isActive)
          .toList(growable: false);
      final selected = active.length == 1 ? active.first.id : null;
      final reports = await _repository.listGeneratedReports(
        departmentId: selected,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _departments = departments;
        _selectedDepartmentId = selected;
        _reports = reports;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingList = false);
      }
    }
  }

  Future<void> _loadReports() async {
    setState(() {
      _loadingList = true;
      _error = null;
    });
    try {
      final reports = await _repository.listGeneratedReports(
        departmentId: _selectedDepartmentId,
      );
      if (mounted) {
        setState(() => _reports = reports);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingList = false);
      }
    }
  }

  Future<void> _changeDepartment(String? departmentId) async {
    setState(() => _selectedDepartmentId = departmentId);
    await _loadReports();
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

  Future<void> _generateNow() async {
    var departmentId = _selectedDepartmentId;
    if (departmentId == null) {
      final active = _activeDepartments;
      if (active.length == 1) {
        departmentId = active.first.id;
      } else {
        setState(
          () => _error =
              'Seleccione un departamento antes de generar el informe.',
        );
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repository.generateDailyReport(
        date: _date,
        departmentId: departmentId,
      );
      await _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Informe generado. El departamento recibira el aviso una sola vez.',
            ),
          ),
        );
      }
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

  Future<void> _shareGenerated(
    DailyReportItem report,
    BuildContext buttonContext,
  ) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final shareOrigin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await _repository.downloadGeneratedReport(report.id);
      await Share.shareXFiles(
        <XFile>[
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name:
                'checktap-${report.department.name}-${_fileDate(report.reportDate)}.pdf',
          ),
        ],
        subject:
            'Informe CheckTap ${report.department.name} ${_dayLabel(report.reportDate)}',
        text: 'Informe diario del equipo ${report.department.name}.',
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
        return 'Los informes requieren conexion con el servidor.';
      }
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informes por departamento'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadingList ? null : _loadInitial,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.schedule_send),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Resumen diario automatico',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'El servidor genera un PDF independiente por departamento y avisa a todos sus integrantes.',
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      key: ValueKey<String?>(_selectedDepartmentId),
                      initialValue: _selectedDepartmentId,
                      decoration: const InputDecoration(
                        labelText: 'Departamento',
                        prefixIcon: Icon(Icons.domain),
                        border: OutlineInputBorder(),
                      ),
                      items: <DropdownMenuItem<String?>>[
                        if (_activeDepartments.length > 1)
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos los departamentos'),
                          ),
                        ..._activeDepartments.map(
                          (department) => DropdownMenuItem<String?>(
                            value: department.id,
                            child: Text(department.name),
                          ),
                        ),
                      ],
                      onChanged: _loadingList ? null : _changeDepartment,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _selectDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_dayLabel(_date)),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _loading ? null : _generateNow,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: const Text('Generar informe ahora'),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Informes disponibles',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_loadingList)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_reports.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Todavia no hay informes para esta seleccion. El primero aparecera despues de la hora programada o al generarlo manualmente.',
                  ),
                ),
              )
            else
              ..._reports.map(
                (report) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf),
                    title: Text(
                      '${report.department.name} · ${_dayLabel(report.reportDate)}',
                    ),
                    subtitle: Text(
                      'Creadas ${report.createdCount} · '
                      'Completadas ${report.completedCount} · '
                      'Pendientes ${report.pendingCount} · '
                      'En progreso ${report.inProgressCount}\n'
                      '${_sizeLabel(report.fileSize)}',
                    ),
                    isThreeLine: true,
                    trailing: Builder(
                      builder: (buttonContext) => IconButton(
                        tooltip: 'Descargar o compartir',
                        onPressed: _loading
                            ? null
                            : () => _shareGenerated(report, buttonContext),
                        icon: const Icon(Icons.download),
                      ),
                    ),
                    onTap: _loading
                        ? null
                        : () => _shareGenerated(report, context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
