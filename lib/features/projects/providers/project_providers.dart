import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/data_providers.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../domain/models/project.dart';

@immutable
class ProjectFilter {
  const ProjectFilter({this.status, this.query = ''});

  final ProjectStatus? status;
  final String query;

  bool get isActive => status != null || query.isNotEmpty;

  ProjectFilter copyWith({
    ProjectStatus? status,
    String? query,
    bool clearStatus = false,
  }) {
    return ProjectFilter(
      status: clearStatus ? null : (status ?? this.status),
      query: query ?? this.query,
    );
  }
}

class ProjectFilterNotifier extends Notifier<ProjectFilter> {
  @override
  ProjectFilter build() => const ProjectFilter();

  void setStatus(ProjectStatus? status) {
    state = status == null
        ? state.copyWith(clearStatus: true)
        : state.copyWith(status: status);
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void clear() => state = const ProjectFilter();
}

final projectFilterProvider =
    NotifierProvider<ProjectFilterNotifier, ProjectFilter>(
      ProjectFilterNotifier.new,
    );

final projectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(projectRepositoryProvider).watchAll();
});

final projectProvider = StreamProvider.family<Project?, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).watchById(id);
});

/// The list as the screen shows it. Open work first, then by how far along the
/// project is, then by deadline.
@immutable
class ProjectsView {
  const ProjectsView({
    required this.visible,
    required this.total,
    required this.statusCounts,
    required this.openPoints,
  });

  final List<Project> visible;
  final int total;
  final Map<ProjectStatus, int> statusCounts;

  /// Tasks still open across the visible projects.
  final int openPoints;
}

final visibleProjectsProvider = Provider<AsyncValue<ProjectsView>>((ref) {
  final projects = ref.watch(projectsProvider);
  final filter = ref.watch(projectFilterProvider);

  return projects.whenData((all) {
    final query = filter.query.trim().toLowerCase();
    final statusCounts = <ProjectStatus, int>{};
    for (final project in all) {
      statusCounts[project.status] = (statusCounts[project.status] ?? 0) + 1;
    }

    final filtered = [
      for (final project in all)
        if (filter.status == null || project.status == filter.status)
          if (query.isEmpty ||
              project.name.toLowerCase().contains(query) ||
              project.category.toLowerCase().contains(query) ||
              project.tags.any((tag) => tag.toLowerCase().contains(query)))
            project,
    ]..sort((a, b) {
        if (a.status.isOpen != b.status.isOpen) {
          return a.status.isOpen ? -1 : 1;
        }
        if (a.deadline != null && b.deadline != null) {
          return a.deadline!.compareTo(b.deadline!);
        } else if (a.deadline != null) {
          return -1;
        } else if (b.deadline != null) {
          return 1;
        }
        return b.progress.compareTo(a.progress);
      });

    return ProjectsView(
      visible: filtered,
      total: all.length,
      statusCounts: statusCounts,
      openPoints: filtered.fold(0, (sum, p) => sum + p.remainingTasks),
    );
  });
});

/// Open projects for the Home rail, most complete first.
final homeProjectsProvider = Provider<AsyncValue<List<Project>>>((ref) {
  return ref.watch(projectsProvider).whenData((all) {
    final open = all.where((project) => project.status.isOpen).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    return open.take(3).toList();
  });
});

final openTaskCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref
      .watch(projectsProvider)
      .whenData(
        (all) => all
            .where((project) => project.status.isOpen)
            .fold(0, (sum, project) => sum + project.remainingTasks),
      );
});

/// Writes for the Projects module.
class ProjectActions {
  ProjectActions(this._ref);

  final Ref _ref;

  ProjectRepository get _repository => _ref.read(projectRepositoryProvider);

  Future<Project> create({
    required String name,
    String? description,
    ProjectStatus status = ProjectStatus.planned,
    String category = 'Other',
    TaskPriority priority = TaskPriority.medium,
    DateTime? deadline,
    String? nextAction,
    List<String> tags = const [],
  }) {
    return _repository.create(
      name: name,
      description: description,
      status: status,
      category: category,
      priority: priority,
      deadline: deadline,
      nextAction: nextAction,
      tags: tags,
    );
  }

  Future<void> update({
    required String id,
    required String name,
    String? description,
    required ProjectStatus status,
    required String category,
    required TaskPriority priority,
    DateTime? deadline,
    String? nextAction,
    List<String> tags = const [],
  }) {
    return _repository.update(
      id,
      name: name,
      description: description,
      status: status,
      category: category,
      priority: priority,
      deadline: deadline,
      nextAction: nextAction,
      tags: tags,
    );
  }

  Future<void> setStatus(String id, ProjectStatus status) =>
      _repository.setStatus(id, status);

  Future<void> delete(String id) => _repository.delete(id);

  Future<ProjectTask> addTask(
    String projectId, {
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
  }) {
    return _repository.addTask(
      projectId,
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
    );
  }

  Future<void> updateTask({
    required String taskId,
    required String title,
    String? description,
    required TaskPriority priority,
    DateTime? dueDate,
  }) {
    return _repository.updateTask(
      taskId,
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
    );
  }

  Future<void> setTaskCompleted(String taskId, bool completed) =>
      _repository.setTaskCompleted(taskId, completed);

  Future<void> deleteTask(String taskId) => _repository.deleteTask(taskId);
}

final projectActionsProvider = Provider<ProjectActions>(ProjectActions.new);
