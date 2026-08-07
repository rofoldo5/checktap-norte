import '../models/app_user.dart';
import '../models/task_item.dart';

bool _isDepartmentMember(AppUser user, TaskItem task) {
  if (user.isAdmin) {
    return true;
  }
  if (user.departmentIds.isEmpty ||
      task.department.id == 'pending-department') {
    // Compatibilidad temporal con cache 0.8.x hasta la primera sincronizacion.
    return task.createdBy.id == user.id || task.assignedTo?.id == user.id;
  }
  return user.departmentIds.contains(task.department.id);
}

bool canEditTask(AppUser user, TaskItem task) {
  return user.isAdmin || task.createdBy.id == user.id;
}

bool canWorkTask(AppUser user, TaskItem task) {
  return _isDepartmentMember(user, task);
}

bool canReopenTask(AppUser user, TaskItem task) {
  return _isDepartmentMember(user, task);
}
