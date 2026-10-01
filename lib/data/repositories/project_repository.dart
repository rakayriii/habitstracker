import 'package:drift/drift.dart';

import '../../core/utils/id.dart';
import '../../core/utils/stream_utils.dart';
import '../../domain/errors.dart';
import '../../domain/models/project.dart';
import '../database/app_database.dart';

/// Projects, their tags and their tasks.
///
/// Progress is never stored. It is `completedTasks / totalTasks` computed on
/// the domain model, so completing a task on the detail screen moves the bar on
/// the list and on Home with no extra bookkeeping.
class ProjectRepository {
  ProjectRepository(this._db);

  final AppDatabase _db;

  static ProjectTask _mapTask(ProjectTaskRow row) {
    return ProjectTask(
      id: row.id,
      projectId: row.projectId,
      title: row.title,
      description: row.description,
      priority: TaskPriority.values.firstWhere(
        (priority) => priority.name == row.priority,
        orElse: () => TaskPriority.medium,
      ),
      dueDate: row.dueDate,
      sortOrder: row.sortOrder,
      completedAt: row.completedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static Project _map(
    ProjectRow row,
    List<ProjectTagRow> tags,
    List<ProjectTaskRow> tasks,
  ) {
    return Project(
      id: row.id,
      name: row.name,
      description: row.description,
      status: ProjectStatus.values.firstWhere(
        (status) => status.name == row.status,
        orElse: () => ProjectStatus.planned,
      ),
      category: row.category,
      priority: TaskPriority.values.firstWhere(
        (priority) => priority.name == row.priority,
        orElse: () => TaskPriority.medium,
      ),
      deadline: row.deadline,
      nextAction: row.nextAction,
      tags: [
        for (final tag in tags)
          if (tag.projectId == row.id) tag.label,
      ],
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      tasks: [
        for (final task in tasks)
          if (task.projectId == row.id) _mapTask(task),
      ],
    );
  }

  Stream<List<Project>> watchAll() {
    final projects = _db.select(_db.projects)
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    final tags = _db.select(_db.projectTags)
      ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]);
    final tasks = _db.select(_db.projectTasks)
      ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]);

    return combineLatest3(
      projects.watch(),
      tags.watch(),
      tasks.watch(),
      (projectRows, tagRows, taskRows) => [
        for (final project in projectRows)
          _map(project, tagRows, taskRows),
      ],
    );
  }

  Stream<Project?> watchById(String id) {
    return watchAll().map(
      (projects) => projects.where((project) => project.id == id).firstOrNull,
    );
  }

  Future<Project?> findById(String id) async {
    final row = await (_db.select(_db.projects)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    final tags = await (_db.select(_db.projectTags)
          ..where((t) => t.projectId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    final tasks = await (_db.select(_db.projectTasks)
          ..where((t) => t.projectId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return _map(row, tags, tasks);
  }

  Future<Project> create({
    required String name,
    String? description,
    ProjectStatus status = ProjectStatus.planned,
    String category = 'Other',
    TaskPriority priority = TaskPriority.medium,
    DateTime? deadline,
    String? nextAction,
    List<String> tags = const [],
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Nama proyek wajib diisi', field: 'name');
    }
    final now = DateTime.now();
    final id = IdGen.next('prj');
    await _db.transaction(() async {
      await _db.into(_db.projects).insert(
        ProjectsCompanion.insert(
          id: id,
          name: trimmed,
          description: Value(_nullIfEmpty(description)),
          status: status.name,
          category: Value(category.trim().isEmpty ? 'Other' : category.trim()),
          priority: priority.name,
          deadline: Value(deadline),
          nextAction: Value(_nullIfEmpty(nextAction)),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _replaceTags(id, tags);
    });
    final created = await findById(id);
    if (created == null) throw const StorageException('Proyek gagal disimpan');
    return created;
  }

  Future<void> update(
    String id, {
    required String name,
    String? description,
    required ProjectStatus status,
    required String category,
    required TaskPriority priority,
    DateTime? deadline,
    String? nextAction,
    List<String> tags = const [],
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Nama proyek wajib diisi', field: 'name');
    }
    await _db.transaction(() async {
      final changed = await (_db.update(_db.projects)
            ..where((p) => p.id.equals(id)))
          .write(
        ProjectsCompanion(
          name: Value(trimmed),
          description: Value(_nullIfEmpty(description)),
          status: Value(status.name),
          category: Value(category.trim().isEmpty ? 'Other' : category.trim()),
          priority: Value(priority.name),
          deadline: Value(deadline),
          nextAction: Value(_nullIfEmpty(nextAction)),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (changed == 0) throw NotFoundException('Proyek $id tidak ditemukan');
      await _replaceTags(id, tags);
    });
  }

  Future<void> setStatus(String id, ProjectStatus status) async {
    final changed = await (_db.update(_db.projects)..where((p) => p.id.equals(id)))
        .write(
      ProjectsCompanion(
        status: Value(status.name),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (changed == 0) throw NotFoundException('Proyek $id tidak ditemukan');
  }

  Future<void> delete(String id) async {
    // Tasks and tags go with it through the ON DELETE CASCADE foreign keys.
    final deleted = await (_db.delete(_db.projects)..where((p) => p.id.equals(id)))
        .go();
    if (deleted == 0) throw NotFoundException('Proyek $id tidak ditemukan');
  }

  Future<void> _replaceTags(String projectId, List<String> tags) async {
    await (_db.delete(_db.projectTags)..where((t) => t.projectId.equals(projectId)))
        .go();
    final cleaned = <String>{};
    for (final tag in tags) {
      final value = tag.trim();
      if (value.isEmpty) continue;
      if (value.length > 40) {
        throw const ValidationException(
          'Tag maksimal 40 karakter',
          field: 'tags',
        );
      }
      cleaned.add(value);
    }
    var order = 0;
    for (final label in cleaned) {
      await _db.into(_db.projectTags).insert(
        ProjectTagsCompanion.insert(
          id: IdGen.next('tag'),
          projectId: projectId,
          label: label,
          sortOrder: Value(order),
        ),
      );
      order++;
    }
  }

  Future<ProjectTask> addTask(
    String projectId, {
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Judul task wajib diisi', field: 'title');
    }
    final project = await findById(projectId);
    if (project == null) {
      throw NotFoundException('Proyek $projectId tidak ditemukan');
    }
    final now = DateTime.now();
    final id = IdGen.next('task');
    await _db.into(_db.projectTasks).insert(
      ProjectTasksCompanion.insert(
        id: id,
        projectId: projectId,
        title: trimmed,
        description: Value(_nullIfEmpty(description)),
        priority: priority.name,
        dueDate: Value(dueDate),
        sortOrder: Value(project.totalTasks),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return ProjectTask(
      id: id,
      projectId: projectId,
      title: trimmed,
      description: _nullIfEmpty(description),
      priority: priority,
      dueDate: dueDate,
      sortOrder: project.totalTasks,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateTask(
    String taskId, {
    required String title,
    String? description,
    required TaskPriority priority,
    DateTime? dueDate,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Judul task wajib diisi', field: 'title');
    }
    final changed = await (_db.update(_db.projectTasks)
          ..where((t) => t.id.equals(taskId)))
        .write(
      ProjectTasksCompanion(
        title: Value(trimmed),
        description: Value(_nullIfEmpty(description)),
        priority: Value(priority.name),
        dueDate: Value(dueDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (changed == 0) throw NotFoundException('Task $taskId tidak ditemukan');
  }

  Future<void> setTaskCompleted(String taskId, bool completed) async {
    final changed = await (_db.update(_db.projectTasks)
          ..where((t) => t.id.equals(taskId)))
        .write(
      ProjectTasksCompanion(
        completedAt: Value(completed ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (changed == 0) throw NotFoundException('Task $taskId tidak ditemukan');
  }

  Future<void> deleteTask(String taskId) async {
    final deleted = await (_db.delete(_db.projectTasks)
          ..where((t) => t.id.equals(taskId)))
        .go();
    if (deleted == 0) throw NotFoundException('Task $taskId tidak ditemukan');
  }
}

String? _nullIfEmpty(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
