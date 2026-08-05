import '../models/app_user.dart';
import '../models/task_item.dart';

bool canEditTask(AppUser currentUser, TaskItem task) {
  return currentUser.isAdmin || task.createdBy.id == currentUser.id;
}

bool canWorkTask(AppUser currentUser, TaskItem task) {
  return currentUser.isAdmin ||
      task.createdBy.id == currentUser.id ||
      task.assignedTo?.id == currentUser.id;
}

bool canReopenTask(AppUser currentUser, TaskItem task) {
  return currentUser.isAdmin || task.createdBy.id == currentUser.id;
}
