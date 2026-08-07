import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/repositories/task_repository.dart';
import '../models/daily_report.dart';
import '../models/department.dart';
import '../services/session_store.dart';
import '../ui/components/empty_state.dart';
import '../ui/components/section_header.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';

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
        title: const Text('Informes'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadingList ? null : _loadInitial,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            CheckTapSpacing.md,
            CheckTapSpacing.sm,
            CheckTapSpacing.md,
            40,
          ),
          children: <Widget>[
            const SectionHeader(
              title: 'Informes del equipo',
              subtitle:
                  'Consulta, descarga o comparte los resúmenes diarios por departamento.',
            ),
            const SizedBox(height: CheckTapSpacing.md),
            Container(
              padding: const EdgeInsets.all(CheckTapSpacing.lg),
              decoration: BoxDecoration(
                gradient: CheckTapColors.brandGradient,
                borderRadius: BorderRadius.circular(CheckTapRadius.xl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(
                            CheckTapRadius.md,
                          ),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: CheckTapSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Resumen diario automático',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'El servidor genera un PDF por departamento y avisa a todos sus integrantes.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.84),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CheckTapSpacing.lg),
                  DropdownButtonFormField<String?>(
                    key: ValueKey<String?>(_selectedDepartmentId),
                    initialValue: _selectedDepartmentId,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    decoration: InputDecoration(
                      labelText: 'Departamento',
                      prefixIcon: const Icon(Icons.apartment_rounded),
                      fillColor: Colors.white.withValues(alpha: 0.96),
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
                  const SizedBox(height: CheckTapSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                          onPressed: _loading ? null : _selectDate,
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(_dayLabel(_date)),
                        ),
                      ),
                      const SizedBox(width: CheckTapSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: CheckTapColors.primary,
                          ),
                          onPressed: _loading ? null : _generateNow,
                          icon: _loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Generar ahora'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: CheckTapSpacing.md),
              Container(
                padding: const EdgeInsets.all(CheckTapSpacing.sm),
                decoration: BoxDecoration(
                  color: CheckTapColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(CheckTapRadius.md),
                  border: Border.all(
                    color: CheckTapColors.danger.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline_rounded,
                      color: CheckTapColors.danger,
                    ),
                    const SizedBox(width: CheckTapSpacing.xs),
                    Expanded(
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CheckTapColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: CheckTapSpacing.xl),
            const SectionHeader(
              title: 'Informes disponibles',
              subtitle: 'Los más recientes aparecen primero.',
            ),
            const SizedBox(height: CheckTapSpacing.sm),
            if (_loadingList)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_reports.isEmpty)
              const CheckTapEmptyState(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Todavía no hay informes',
                message:
                    'El primero aparecerá después de la hora programada o al generarlo manualmente.',
              )
            else
              ..._reports.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: CheckTapSpacing.sm),
                  child: _ReportCard(
                    report: report,
                    dateLabel: _dayLabel(report.reportDate),
                    sizeLabel: _sizeLabel(report.fileSize),
                    loading: _loading,
                    onShare: (buttonContext) =>
                        _shareGenerated(report, buttonContext),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.dateLabel,
    required this.sizeLabel,
    required this.loading,
    required this.onShare,
  });

  final DailyReportItem report;
  final String dateLabel;
  final String sizeLabel;
  final bool loading;
  final void Function(BuildContext context) onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : () => onShare(context),
        borderRadius: BorderRadius.circular(CheckTapRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(CheckTapSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(CheckTapRadius.lg),
            border: Border.all(color: CheckTapColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: CheckTapColors.danger.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(CheckTapRadius.md),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: CheckTapColors.danger,
                ),
              ),
              const SizedBox(width: CheckTapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      report.department.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CheckTapColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _ReportMetric(
                          label: 'Creadas',
                          value: report.createdCount,
                          color: CheckTapColors.primary,
                        ),
                        _ReportMetric(
                          label: 'Completadas',
                          value: report.completedCount,
                          color: CheckTapColors.success,
                        ),
                        _ReportMetric(
                          label: 'Pendientes',
                          value: report.pendingCount,
                          color: CheckTapColors.warning,
                        ),
                        _ReportMetric(
                          label: 'En curso',
                          value: report.inProgressCount,
                          color: CheckTapColors.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      sizeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: CheckTapColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: 'Descargar o compartir',
                  onPressed: loading ? null : () => onShare(buttonContext),
                  icon: const Icon(Icons.ios_share_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CheckTapRadius.pill),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
