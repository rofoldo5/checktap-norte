import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/task_permissions.dart';
import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/department.dart';
import '../models/task_item.dart';
import '../services/background_sync.dart';
import '../services/notification_service.dart';
import '../services/realtime_service.dart';
import '../services/session_store.dart';
import '../services/sync_trigger_service.dart';
import '../widgets/task_form_dialog.dart';
import '../features/dashboard/domain/dashboard_snapshot.dart';
import '../features/dashboard/presentation/widgets/activity_tile.dart';
import '../ui/components/checktap_logo.dart';
import '../ui/components/checktap_shell.dart';
import '../ui/components/empty_state.dart';
import '../ui/components/metric_card.dart';
import '../ui/components/search_field.dart';
import '../ui/components/section_header.dart';
import '../ui/components/sync_banner.dart';
import '../ui/components/task_card.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';
import 'department_management_screen.dart';
import 'notification_validation_screen.dart';
import 'report_screen.dart';
import 'task_detail_screen.dart';
import 'user_management_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({required this.session, super.key});

  final SessionStore session;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen>
    with WidgetsBindingObserver {
  late final TaskRepository _repository;
  final RealtimeService _realtimeService = RealtimeService();
  final SyncTriggerService _syncTriggerService = SyncTriggerService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<TaskItem> _tasks = <TaskItem>[];
  List<AppUser> _users = <AppUser>[];
  List<DepartmentSummary> _departments = <DepartmentSummary>[];
  bool _loading = true;
  bool _syncRunning = false;
  bool _realtimeConnected = false;
  bool _offlineMode = false;
  bool _usingCachedData = false;
  String? _error;
  String _filter = 'TODAS';
  String? _selectedDepartmentId;
  DateTime? _lastSyncAt;
  int _pendingOperations = 0;
  int _navigationIndex = 0;
  String _searchQuery = '';

  String? get _statusFilter => _filter == 'TODAS' ? null : _filter;

  bool get _hasCachedContent {
    return _tasks.isNotEmpty ||
        _users.isNotEmpty ||
        _departments.isNotEmpty ||
        _lastSyncAt != null;
  }

  List<DepartmentSummary> get _activeDepartments => _departments
      .where((department) => department.isActive)
      .toList(growable: false);

  void _normalizeDepartmentSelection() {
    final active = _activeDepartments;
    if (_selectedDepartmentId != null &&
        active.any((department) => department.id == _selectedDepartmentId)) {
      return;
    }
    _selectedDepartmentId = active.length == 1 ? active.first.id : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = TaskRepository(widget.session.apiClient);
    _offlineMode = widget.session.offlineSession;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _startServices();
    });
  }

  Future<void> _startServices() async {
    await _loadOfflineFirst();
    _syncTriggerService.start(() async {
      await _synchronizeAndRefresh(showLoader: false);
    });
    _realtimeService.connect(
      token: widget.session.token!,
      onTaskChanged: () {
        unawaited(_synchronizeAndRefresh(showLoader: false));
      },
      onConnectionChanged: (connected) {
        if (mounted && _realtimeConnected != connected) {
          setState(() => _realtimeConnected = connected);
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_synchronizeAndRefresh(showLoader: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _syncTriggerService.dispose();
    _realtimeService.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineFirst() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    var cacheHasContent = false;
    try {
      final cached = await _repository.loadCached(
        status: _statusFilter,
        departmentId: _selectedDepartmentId,
      );
      cacheHasContent = cached.hasContent;
      if (mounted && cacheHasContent) {
        _applyDashboardData(cached, cachedData: true);
      }
    } catch (error, stackTrace) {
      debugPrint('[OFFLINE] No fue posible leer la cache: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    await _synchronizeAndRefresh(showLoader: !cacheHasContent);
  }

  Future<void> _loadCachedForCurrentFilter() async {
    try {
      final cached = await _repository.loadCached(
        status: _statusFilter,
        departmentId: _selectedDepartmentId,
      );
      if (!mounted) {
        return;
      }
      _applyDashboardData(cached, cachedData: true);
    } catch (error, stackTrace) {
      debugPrint('[OFFLINE] Error leyendo cache filtrada: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _applyDashboardData(DashboardData data, {required bool cachedData}) {
    setState(() {
      _tasks = data.tasks;
      _users = data.users;
      _departments = data.departments;
      _normalizeDepartmentSelection();
      _lastSyncAt = data.lastSyncAt;
      _pendingOperations = data.pendingOperations;
      _usingCachedData = cachedData;
      _loading = false;
    });
  }

  Future<void> _synchronizeAndRefresh({required bool showLoader}) async {
    if (_syncRunning || !widget.session.isAuthenticated) {
      return;
    }

    _syncRunning = true;
    if (mounted) {
      setState(() {
        if (showLoader) {
          _loading = true;
        }
        _error = null;
      });
    }

    try {
      final summary = await _repository.synchronizePending();
      if (summary.unauthorized) {
        await _returnToLogin();
        return;
      }

      await widget.session.refreshCurrentUser();
      final data = await _repository.refreshFromServer(
        status: _statusFilter,
        departmentId: _selectedDepartmentId,
      );
      await widget.session.markServerAvailable();
      unawaited(
        NotificationService.instance.registerCurrentDevice().then<void>((_) {}),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _tasks = data.tasks;
        _users = data.users;
        _departments = data.departments;
        _normalizeDepartmentSelection();
        _lastSyncAt = data.lastSyncAt;
        _pendingOperations = data.pendingOperations;
        _offlineMode = false;
        _usingCachedData = false;
        _error = null;
      });

      if (summary.conflicts > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${summary.conflicts} cambio(s) entraron en conflicto. '
              'Se conserva la version confirmada por el servidor.',
            ),
          ),
        );
      }
    } on DioException catch (error) {
      if (_isUnauthorized(error)) {
        await _returnToLogin();
        return;
      }

      await _loadCachedForCurrentFilter();
      if (!mounted) {
        return;
      }
      setState(() {
        _offlineMode = true;
        _usingCachedData = _hasCachedContent;
        _error = _hasCachedContent ? null : _messageFromError(error);
      });
    } catch (error, stackTrace) {
      debugPrint('[DASHBOARD] Error sincronizando datos: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _loadCachedForCurrentFilter();
      if (!mounted) {
        return;
      }
      setState(() {
        _offlineMode = true;
        _usingCachedData = _hasCachedContent;
        _error = _hasCachedContent
            ? null
            : 'No fue posible cargar datos locales ni remotos: $error';
      });
    } finally {
      _syncRunning = false;
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _returnToLogin() async {
    await NotificationService.instance.unregisterCurrentDevice();
    await widget.session.logout();
    NotificationService.instance.detachApiClient();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  bool _isUnauthorized(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode == 401 || statusCode == 403;
  }

  String _messageFromError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] != null) {
      return data['detail'].toString();
    }
    return 'No fue posible conectar con el servidor.';
  }

  Future<void> _runTaskAction(Future<TaskItem> Function() action) async {
    try {
      await action();
      await _loadCachedForCurrentFilter();
      await BackgroundSyncScheduler.scheduleOneOff();
      unawaited(_synchronizeAndRefresh(showLoader: false));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showCreateDialog() async {
    final activeDepartments = _activeDepartments;
    if (activeDepartments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay departamentos activos disponibles.'),
        ),
      );
      return;
    }

    final initialDepartmentId =
        _selectedDepartmentId != null &&
            activeDepartments.any(
              (department) => department.id == _selectedDepartmentId,
            )
        ? _selectedDepartmentId!
        : activeDepartments.first.id;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TaskFormDialog(
        dialogTitle: 'Nueva tarea',
        submitLabel: 'Crear',
        departments: activeDepartments,
        users: _users,
        initialDepartmentId: initialDepartmentId,
        errorMessage: (error) {
          if (error is DioException) {
            return _messageFromError(error);
          }
          return error.toString();
        },
        onSubmit: (value) async {
          await _repository.createTask(
            currentUser: widget.session.user!,
            title: value.title,
            description: value.description,
            priority: value.priority,
            department: value.department,
            assignees: value.assignees,
          );
        },
      ),
    );

    if (created == true && mounted) {
      await _loadCachedForCurrentFilter();
      await BackgroundSyncScheduler.scheduleOneOff();
      unawaited(_synchronizeAndRefresh(showLoader: false));
    }
  }

  Future<void> _changeDepartment(String? departmentId) async {
    setState(() => _selectedDepartmentId = departmentId);
    await _loadCachedForCurrentFilter();
    unawaited(_synchronizeAndRefresh(showLoader: _tasks.isEmpty));
  }

  Future<void> _changeFilter(String value) async {
    setState(() => _filter = value);
    await _loadCachedForCurrentFilter();
    unawaited(_synchronizeAndRefresh(showLoader: _tasks.isEmpty));
  }

  Future<void> _resolveConflict(TaskItem task) async {
    await _repository.resolveConflict(task.id);
    await _loadCachedForCurrentFilter();
  }

  Future<void> _openTask(TaskItem task) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TaskDetailScreen(
          session: widget.session,
          task: task,
          users: _users,
          departments: _activeDepartments,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _loadCachedForCurrentFilter();
      unawaited(_synchronizeAndRefresh(showLoader: false));
    }
  }

  Future<void> _openUsers() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UserManagementScreen(session: widget.session),
      ),
    );
    if (mounted) {
      unawaited(_synchronizeAndRefresh(showLoader: false));
    }
  }

  Future<void> _openDepartments() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DepartmentManagementScreen(session: widget.session),
      ),
    );
    if (mounted) {
      unawaited(_synchronizeAndRefresh(showLoader: false));
    }
  }

  Future<void> _openReports() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReportScreen(session: widget.session),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationValidationScreen(),
      ),
    );
  }

  String _connectionTooltip() {
    if (_offlineMode) {
      return 'Modo sin conexion';
    }
    if (_realtimeConnected) {
      return 'Servidor y tiempo real conectados';
    }
    return 'Servidor disponible; tiempo real reconectando';
  }

  IconData _connectionIcon() {
    if (_offlineMode) {
      return Icons.cloud_off;
    }
    if (_realtimeConnected) {
      return Icons.cloud_done;
    }
    return Icons.cloud_queue;
  }

  String _formatLastSync() {
    final value = _lastSyncAt?.toLocal();
    if (value == null) {
      return 'Sin sincronizacion previa';
    }
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  List<TaskItem> get _visibleTasks {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _tasks;
    }
    return _tasks
        .where((task) {
          final haystack = <String>[
            task.title,
            task.description ?? '',
            task.department.name,
            task.createdBy.name,
            task.assigneeLabel,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      setState(() => _searchQuery = value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _selectNavigation(int index) {
    if (index == 3) {
      unawaited(_openReports());
      return;
    }
    if (index == 4) {
      _scaffoldKey.currentState?.openDrawer();
      return;
    }
    setState(() => _navigationIndex = index);
  }

  void _showTasksWithFilter(String filter) {
    setState(() {
      _navigationIndex = 1;
      _filter = filter;
    });
    unawaited(_changeFilter(filter));
  }

  void _closeDrawerThen(Future<void> Function() action) {
    Navigator.of(context).pop();
    unawaited(Future<void>.microtask(action));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final showFab = _navigationIndex == 0 || _navigationIndex == 1;

    return Scaffold(
      key: _scaffoldKey,
      appBar: CheckTapTopBar(
        title: const CheckTapWordmark(fontSize: 20),
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        connectionIcon: _connectionIcon(),
        connectionTooltip: _connectionTooltip(),
        onSync: () => _synchronizeAndRefresh(showLoader: false),
        syncing: _syncRunning,
        pendingOperations: _pendingOperations,
      ),
      drawer: CheckTapDrawer(
        user: widget.session.user!,
        isAdmin: widget.session.user!.isAdmin,
        pendingOperations: _pendingOperations,
        onUsers: () => _closeDrawerThen(_openUsers),
        onDepartments: () => _closeDrawerThen(_openDepartments),
        onReports: () => _closeDrawerThen(_openReports),
        onNotifications: () => _closeDrawerThen(_openNotifications),
        onLogout: () => _closeDrawerThen(_returnToLogin),
      ),
      floatingActionButton: showFab
          ? FloatingActionButton(
              tooltip: 'Nueva tarea',
              onPressed: _showCreateDialog,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: isWide ? null : _buildBottomNavigation(),
      body: Column(
        children: <Widget>[
          if (_offlineMode || _usingCachedData || _pendingOperations > 0)
            SyncBanner(
              offline: _offlineMode,
              cached: _usingCachedData,
              pendingOperations: _pendingOperations,
              lastSyncLabel: 'Última sincronización: ${_formatLastSync()}',
              onRetry: _syncRunning
                  ? null
                  : () => _synchronizeAndRefresh(showLoader: false),
            ),
          Expanded(
            child: isWide
                ? Row(
                    children: <Widget>[
                      _buildNavigationRail(),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildCurrentPage()),
                    ],
                  )
                : _buildCurrentPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 120),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (_navigationIndex) {
        0 => _buildDashboardPage(),
        1 => _buildTasksPage(),
        2 => _buildActivityPage(),
        _ => _buildDashboardPage(),
      },
    );
  }

  Widget _buildBottomNavigation() {
    return NavigationBar(
      selectedIndex: _navigationIndex.clamp(0, 2).toInt(),
      onDestinationSelected: _selectNavigation,
      destinations: const <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.checklist_outlined),
          selectedIcon: Icon(Icons.checklist_rounded),
          label: 'Tareas',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_graph_outlined),
          selectedIcon: Icon(Icons.auto_graph_rounded),
          label: 'Actividad',
        ),
        NavigationDestination(
          icon: Icon(Icons.picture_as_pdf_outlined),
          selectedIcon: Icon(Icons.picture_as_pdf_rounded),
          label: 'Informes',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          label: 'Más',
        ),
      ],
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      minWidth: 82,
      groupAlignment: -0.75,
      labelType: NavigationRailLabelType.all,
      selectedIndex: _navigationIndex.clamp(0, 2).toInt(),
      onDestinationSelected: _selectNavigation,
      destinations: const <NavigationRailDestination>[
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Inicio'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.checklist_outlined),
          selectedIcon: Icon(Icons.checklist_rounded),
          label: Text('Tareas'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.auto_graph_outlined),
          selectedIcon: Icon(Icons.auto_graph_rounded),
          label: Text('Actividad'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.picture_as_pdf_outlined),
          label: Text('Informes'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.more_horiz_rounded),
          label: Text('Más'),
        ),
      ],
    );
  }

  Widget _buildDashboardPage() {
    final snapshot = DashboardSnapshot.fromTasks(_tasks);
    final currentUser = widget.session.user!;

    if (_loading && _tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _tasks.isEmpty) {
      return CheckTapEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos cargar tu panel',
        message: _error!,
        actionLabel: 'Reintentar',
        onAction: () => _synchronizeAndRefresh(showLoader: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _synchronizeAndRefresh(showLoader: false),
      child: ListView(
        key: const PageStorageKey<String>('dashboard-page'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          CheckTapSpacing.md,
          CheckTapSpacing.sm,
          CheckTapSpacing.md,
          110,
        ),
        children: <Widget>[
          _DashboardHero(
            userName: currentUser.name,
            departments: _activeDepartments,
            selectedDepartmentId: _selectedDepartmentId,
            onDepartmentChanged: _loading ? null : _changeDepartment,
          ),
          const SizedBox(height: CheckTapSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns,
                mainAxisSpacing: CheckTapSpacing.sm,
                crossAxisSpacing: CheckTapSpacing.sm,
                childAspectRatio: constraints.maxWidth >= 760 ? 1.25 : 1.08,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  MetricCard(
                    label: 'Pendientes',
                    value: snapshot.pending,
                    color: CheckTapColors.primary,
                    icon: Icons.schedule_rounded,
                    onTap: () => _showTasksWithFilter('PENDIENTE'),
                  ),
                  MetricCard(
                    label: 'En curso',
                    value: snapshot.inProgress,
                    color: CheckTapColors.cyan,
                    icon: Icons.play_circle_outline_rounded,
                    onTap: () => _showTasksWithFilter('EN_PROGRESO'),
                  ),
                  MetricCard(
                    label: 'Completadas',
                    value: snapshot.completed,
                    color: CheckTapColors.success,
                    icon: Icons.check_circle_outline_rounded,
                    onTap: () => _showTasksWithFilter('COMPLETADA'),
                  ),
                  MetricCard(
                    label: 'Prioridad alta',
                    value: snapshot.highPriority,
                    color: CheckTapColors.danger,
                    icon: Icons.priority_high_rounded,
                    onTap: () {
                      setState(() {
                        _navigationIndex = 1;
                        _filter = 'TODAS';
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: CheckTapSpacing.xl),
          SectionHeader(
            title: 'Requieren atención',
            subtitle: 'Tareas prioritarias para el equipo',
            actionLabel: 'Ver todas',
            onAction: () => setState(() => _navigationIndex = 1),
          ),
          const SizedBox(height: CheckTapSpacing.sm),
          if (snapshot.attentionTasks.isEmpty)
            const _CompactInfoCard(
              icon: Icons.verified_rounded,
              title: 'Todo está bajo control',
              message: 'No hay tareas de alta prioridad pendientes.',
              color: CheckTapColors.success,
            )
          else
            ...snapshot.attentionTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: CheckTapSpacing.sm),
                child: CheckTapTaskCard(
                  key: ValueKey<String>('attention-${task.id}'),
                  compact: true,
                  task: task,
                  canEdit: canEditTask(currentUser, task),
                  canWork: canWorkTask(currentUser, task),
                  canReopen: canReopenTask(currentUser, task),
                  onOpen: () => _openTask(task),
                  onStart: () =>
                      _runTaskAction(() => _repository.startTask(task)),
                  onComplete: () => _runTaskAction(
                    () => _repository.completeTask(task, currentUser),
                  ),
                  onReopen: () =>
                      _runTaskAction(() => _repository.reopenTask(task)),
                  onResolveConflict: () => _resolveConflict(task),
                ),
              ),
            ),
          const SizedBox(height: CheckTapSpacing.lg),
          SectionHeader(
            title: 'Actividad del equipo',
            subtitle: 'Últimos movimientos registrados',
            actionLabel: 'Ver actividad',
            onAction: () => setState(() => _navigationIndex = 2),
          ),
          const SizedBox(height: CheckTapSpacing.sm),
          if (snapshot.activity.isEmpty)
            const _CompactInfoCard(
              icon: Icons.auto_graph_rounded,
              title: 'Sin actividad reciente',
              message: 'Los movimientos del equipo aparecerán aquí.',
              color: CheckTapColors.info,
            )
          else
            ...snapshot.activity
                .take(3)
                .map(
                  (activity) => Padding(
                    padding: const EdgeInsets.only(bottom: CheckTapSpacing.sm),
                    child: ActivityTile(activity: activity),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTasksPage() {
    return Column(
      key: const ValueKey<String>('tasks-page'),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CheckTapSpacing.md,
            CheckTapSpacing.sm,
            CheckTapSpacing.md,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeader(
                title: 'Tareas',
                subtitle: 'Organiza y acompaña el trabajo de tu equipo',
              ),
              const SizedBox(height: CheckTapSpacing.md),
              CheckTapSearchField(
                controller: _searchController,
                hintText: 'Buscar tareas, personas o departamentos…',
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
              ),
              const SizedBox(height: CheckTapSpacing.sm),
              _DepartmentSelector(
                departments: _activeDepartments,
                selectedDepartmentId: _selectedDepartmentId,
                onChanged: _loading ? null : _changeDepartment,
              ),
              const SizedBox(height: CheckTapSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _FilterChip(
                      label: 'Todas',
                      value: 'TODAS',
                      selectedValue: _filter,
                      onSelected: _changeFilter,
                    ),
                    _FilterChip(
                      label: 'Pendientes',
                      value: 'PENDIENTE',
                      selectedValue: _filter,
                      onSelected: _changeFilter,
                    ),
                    _FilterChip(
                      label: 'En curso',
                      value: 'EN_PROGRESO',
                      selectedValue: _filter,
                      onSelected: _changeFilter,
                    ),
                    _FilterChip(
                      label: 'Completadas',
                      value: 'COMPLETADA',
                      selectedValue: _filter,
                      onSelected: _changeFilter,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildTaskBody()),
      ],
    );
  }

  Widget _buildActivityPage() {
    final snapshot = DashboardSnapshot.fromTasks(_tasks);
    return RefreshIndicator(
      onRefresh: () => _synchronizeAndRefresh(showLoader: false),
      child: snapshot.activity.isEmpty
          ? ListView(
              key: const ValueKey<String>('activity-empty-page'),
              physics: const AlwaysScrollableScrollPhysics(),
              children: const <Widget>[
                SizedBox(height: 120),
                CheckTapEmptyState(
                  icon: Icons.auto_graph_rounded,
                  title: 'Sin actividad reciente',
                  message:
                      'Cuando el equipo cree, inicie o complete tareas, lo verás aquí.',
                ),
              ],
            )
          : ListView.separated(
              key: const ValueKey<String>('activity-page'),
              padding: const EdgeInsets.fromLTRB(
                CheckTapSpacing.md,
                CheckTapSpacing.sm,
                CheckTapSpacing.md,
                110,
              ),
              itemCount: snapshot.activity.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: CheckTapSpacing.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: CheckTapSpacing.xs),
                    child: SectionHeader(
                      title: 'Actividad del equipo',
                      subtitle: 'Historial reciente de las tareas visibles',
                    ),
                  );
                }
                return ActivityTile(activity: snapshot.activity[index - 1]);
              },
            ),
    );
  }

  Widget _buildTaskBody() {
    final visibleTasks = _visibleTasks;
    if (_loading && _tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _tasks.isEmpty) {
      return CheckTapEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos cargar las tareas',
        message: _error!,
        actionLabel: 'Reintentar',
        onAction: () => _synchronizeAndRefresh(showLoader: true),
      );
    }

    if (visibleTasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _synchronizeAndRefresh(showLoader: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            const SizedBox(height: 70),
            CheckTapEmptyState(
              icon: _searchQuery.isEmpty
                  ? Icons.inbox_outlined
                  : Icons.search_off_rounded,
              title: _searchQuery.isEmpty
                  ? 'No hay tareas en esta vista'
                  : 'No encontramos coincidencias',
              message: _offlineMode
                  ? 'Puedes crear tareas sin conexión; se enviarán cuando vuelva la red.'
                  : _searchQuery.isEmpty
                  ? 'Crea la primera tarea o cambia los filtros activos.'
                  : 'Prueba con otro título, persona o departamento.',
              actionLabel: _searchQuery.isEmpty
                  ? 'Crear tarea'
                  : 'Limpiar búsqueda',
              onAction: _searchQuery.isEmpty ? _showCreateDialog : _clearSearch,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _synchronizeAndRefresh(showLoader: false),
      child: ListView.separated(
        key: const PageStorageKey<String>('task-list'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          CheckTapSpacing.md,
          CheckTapSpacing.sm,
          CheckTapSpacing.md,
          110,
        ),
        itemCount: visibleTasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: CheckTapSpacing.sm),
        itemBuilder: (context, index) {
          final task = visibleTasks[index];
          final currentUser = widget.session.user!;
          return CheckTapTaskCard(
            key: ValueKey<String>(task.id),
            task: task,
            canEdit: canEditTask(currentUser, task),
            canWork: canWorkTask(currentUser, task),
            canReopen: canReopenTask(currentUser, task),
            onOpen: () => _openTask(task),
            onStart: () => _runTaskAction(() => _repository.startTask(task)),
            onComplete: () => _runTaskAction(
              () => _repository.completeTask(task, currentUser),
            ),
            onReopen: () => _runTaskAction(() => _repository.reopenTask(task)),
            onResolveConflict: () => _resolveConflict(task),
          );
        },
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.userName,
    required this.departments,
    required this.selectedDepartmentId,
    required this.onDepartmentChanged,
  });

  final String userName;
  final List<DepartmentSummary> departments;
  final String? selectedDepartmentId;
  final ValueChanged<String?>? onDepartmentChanged;

  String get _firstName {
    final normalized = userName.trim();
    if (normalized.isEmpty) {
      return 'equipo';
    }
    return normalized.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.lg),
      decoration: BoxDecoration(
        gradient: CheckTapColors.quietGradient,
        borderRadius: BorderRadius.circular(CheckTapRadius.xl),
        border: Border.all(color: CheckTapColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '¡Buenos días!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CheckTapColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _firstName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: CheckTapSpacing.md),
                _DepartmentSelector(
                  departments: departments,
                  selectedDepartmentId: selectedDepartmentId,
                  onChanged: onDepartmentChanged,
                  compact: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: CheckTapSpacing.md),
          Container(
            width: 118,
            height: 94,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(CheckTapRadius.lg),
            ),
            child: const CheckTapLogo(width: 108),
          ),
        ],
      ),
    );
  }
}

class _DepartmentSelector extends StatelessWidget {
  const _DepartmentSelector({
    required this.departments,
    required this.selectedDepartmentId,
    required this.onChanged,
    this.compact = false,
  });

  final List<DepartmentSummary> departments;
  final String? selectedDepartmentId;
  final ValueChanged<String?>? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      key: ValueKey<String?>(selectedDepartmentId),
      initialValue: selectedDepartmentId,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(
        labelText: compact ? null : 'Departamento actual',
        prefixIcon: const Icon(Icons.apartment_rounded),
        contentPadding: EdgeInsets.symmetric(
          horizontal: CheckTapSpacing.sm,
          vertical: compact ? 8 : 12,
        ),
      ),
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todos mis departamentos'),
        ),
        ...departments.map(
          (department) => DropdownMenuItem<String?>(
            value: department.id,
            child: Text(
              department.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;
    return Padding(
      padding: const EdgeInsets.only(right: CheckTapSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: CheckTapColors.primary,
        labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? Colors.white : CheckTapColors.text,
        ),
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}

class _CompactInfoCard extends StatelessWidget {
  const _CompactInfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(CheckTapRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: CheckTapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CheckTapColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
