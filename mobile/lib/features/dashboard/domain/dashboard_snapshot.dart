import '../../../models/task_item.dart';

class DashboardActivity {
  const DashboardActivity({
    required this.actor,
    required this.action,
    required this.taskTitle,
    required this.at,
    required this.iconCodePoint,
  });

  final String actor;
  final String action;
  final String taskTitle;
  final DateTime at;
  final int iconCodePoint;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.highPriority,
    required this.attentionTasks,
    required this.activity,
  });

  final int pending;
  final int inProgress;
  final int completed;
  final int highPriority;
  final List<TaskItem> attentionTasks;
  final List<DashboardActivity> activity;

  factory DashboardSnapshot.fromTasks(List<TaskItem> tasks) {
    final pending = tasks.where((task) => task.status == 'PENDIENTE').length;
    final inProgress = tasks
        .where((task) => task.status == 'EN_PROGRESO')
        .length;
    final completed = tasks.where((task) => task.status == 'COMPLETADA').length;
    final highPriority = tasks
        .where((task) => task.priority == 'ALTA' && task.status != 'COMPLETADA')
        .length;

    final attention = <TaskItem>[
      ...tasks.where(
        (task) => task.priority == 'ALTA' && task.status != 'COMPLETADA',
      ),
      ...tasks.where(
        (task) => task.status == 'EN_PROGRESO' && task.priority != 'ALTA',
      ),
      ...tasks.where(
        (task) => task.status == 'PENDIENTE' && task.priority != 'ALTA',
      ),
    ];
    final uniqueAttention = <String, TaskItem>{};
    for (final task in attention) {
      uniqueAttention.putIfAbsent(task.id, () => task);
    }

    final activity = tasks.map((task) {
      if (task.completedAt != null && task.completedBy != null) {
        return DashboardActivity(
          actor: task.completedBy!.name,
          action: 'completó',
          taskTitle: task.title,
          at: task.completedAt!,
          iconCodePoint: 0xe156,
        );
      }
      if (task.status == 'EN_PROGRESO') {
        return DashboardActivity(
          actor: task.assignees.isNotEmpty
              ? task.assignees.first.name
              : task.createdBy.name,
          action: 'inició',
          taskTitle: task.title,
          at: task.updatedAt,
          iconCodePoint: 0xe1c4,
        );
      }
      return DashboardActivity(
        actor: task.createdBy.name,
        action: 'creó',
        taskTitle: task.title,
        at: task.createdAt,
        iconCodePoint: 0xe145,
      );
    }).toList();

    int actionPriority(DashboardActivity item) {
      return switch (item.action) {
        'completó' => 0,
        'inició' => 1,
        _ => 2,
      };
    }

    activity.sort((a, b) {
      final byTime = b.at.compareTo(a.at);
      if (byTime != 0) {
        return byTime;
      }
      return actionPriority(a).compareTo(actionPriority(b));
    });

    return DashboardSnapshot(
      pending: pending,
      inProgress: inProgress,
      completed: completed,
      highPriority: highPriority,
      attentionTasks: uniqueAttention.values.take(3).toList(growable: false),
      activity: activity,
    );
  }
}
