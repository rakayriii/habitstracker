import 'package:flutter/foundation.dart';

enum ProjectStatus {
  planned('Planned', 'Belum dimulai'),
  inDevelopment('In dev', 'Sedang dikerjakan'),
  onHold('On hold', 'Ditunda, menunggu keputusan'),
  shipped('Shipped', 'Rilis selesai'),
  archived('Archived', 'Diarsipkan');

  const ProjectStatus(this.label, this.hint);

  final String label;
  final String hint;

  bool get isOpen =>
      this != ProjectStatus.shipped && this != ProjectStatus.archived;
}

enum TaskPriority {
  low('Low'),
  medium('Medium'),
  high('High');

  const TaskPriority(this.label);

  final String label;
}

@immutable
class ProjectTask {
  const ProjectTask({
    required this.id,
    required this.projectId,
    required this.title,
    required this.priority,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.dueDate,
    this.completedAt,
  });

  final String id;
  final String projectId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final DateTime? dueDate;
  final int sortOrder;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => completedAt != null;

  bool get isOverdue {
    final due = dueDate;
    if (due == null || isCompleted) return false;
    final now = DateTime.now();
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }
}

@immutable
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.status,
    required this.category,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.deadline,
    this.nextAction,
    this.tags = const [],
    this.tasks = const [],
  });

  final String id;
  final String name;
  final String? description;
  final ProjectStatus status;
  final String category;
  final TaskPriority priority;
  final DateTime? deadline;
  final String? nextAction;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProjectTask> tasks;

  int get totalTasks => tasks.length;
  int get completedTasks => tasks.where((task) => task.isCompleted).length;
  int get remainingTasks => totalTasks - completedTasks;

  /// Progress comes from the task list, never from a typed percentage. A
  /// project with no tasks has no progress to report.
  double get progress {
    if (totalTasks == 0) return 0;
    return completedTasks / totalTasks;
  }

  /// The next action is the project's own note when it has one, otherwise the
  /// oldest open task. Both are real stored data.
  String? get effectiveNextAction {
    final note = nextAction?.trim();
    if (note != null && note.isNotEmpty) return note;
    for (final task in tasks) {
      if (!task.isCompleted) return task.title;
    }
    return null;
  }

  /// How long ago the project record last changed, stated the way a person
  /// would say it. A future timestamp (clock skew) reads as "baru saja".
  String age(DateTime now) {
    final diff = now.difference(updatedAt);
    if (diff.isNegative) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    final days = diff.inDays;
    if (days == 1) return 'kemarin';
    if (days < 30) return '$days hari lalu';
    final months = (days / 30).round();
    return '$months bulan lalu';
  }

  ProjectTask? get nextOpenTask {
    ProjectTask? best;
    for (final task in tasks) {
      if (task.isCompleted) continue;
      if (best == null) {
        best = task;
        continue;
      }
      final bestDue = best.dueDate;
      final due = task.dueDate;
      if (due == null && bestDue == null) {
        if (task.sortOrder < best.sortOrder) best = task;
      } else if (due != null && (bestDue == null || due.isBefore(bestDue))) {
        best = task;
      }
    }
    return best;
  }
}
