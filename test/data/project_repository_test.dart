import 'package:flutter_test/flutter_test.dart';
import 'package:habitstracker/data/database/data_providers.dart';
import 'package:habitstracker/data/repositories/project_repository.dart';
import 'package:habitstracker/domain/errors.dart';
import 'package:habitstracker/domain/models/project.dart';
import 'package:habitstracker/features/projects/providers/project_providers.dart';

import '../support/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() async => harness = await TestHarness.create());
  tearDown(() => harness.dispose());

  ProjectRepository repository() =>
      harness.container.read(projectRepositoryProvider);
  ProjectActions actions() => harness.container.read(projectActionsProvider);

  group('projects', () {
    test('create writes a readable project with normalised tags', () async {
      final project = await actions().create(
        name: 'Ledger Pribadi',
        description: 'Dompet lokal tanpa server',
        status: ProjectStatus.inDevelopment,
        category: 'System',
        priority: TaskPriority.high,
        tags: const ['Flutter', 'Drift', 'Flutter', ' '],
      );

      final stored = await repository().findById(project.id);
      expect(stored!.name, 'Ledger Pribadi');
      expect(stored.status, ProjectStatus.inDevelopment);
      // The duplicate and the blank tag are dropped on the way in.
      expect(stored.tags, ['Flutter', 'Drift']);
    });

    test('create rejects an empty name', () async {
      await expectLater(
        actions().create(name: '   ', category: 'System'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('tasks are created, edited, completed and deleted', () async {
      final project = await actions().create(
        name: 'Dengan task',
        category: 'System',
      );

      final task = await actions().addTask(
        project.id,
        title: 'Rancang schema',
        priority: TaskPriority.high,
        dueDate: DateTime(2026, 12, 1),
      );

      var stored = await repository().findById(project.id);
      expect(stored!.tasks, hasLength(1));
      expect(stored.progress, 0);

      await actions().setTaskCompleted(task.id, true);
      stored = await repository().findById(project.id);
      expect(stored!.completedTasks, 1);
      expect(stored.progress, 1);

      await actions().updateTask(
        taskId: task.id,
        title: 'Rancang dan migrasi schema',
        priority: TaskPriority.medium,
      );
      stored = await repository().findById(project.id);
      expect(stored!.tasks.single.title, 'Rancang dan migrasi schema');

      await actions().deleteTask(task.id);
      stored = await repository().findById(project.id);
      expect(stored!.tasks, isEmpty);
    });

    test('progress is the completed share of the task list', () async {
      final project = await actions().create(
        name: 'Sepuluh task',
        category: 'System',
      );
      final tasks = [
        for (var i = 1; i <= 10; i++)
          await actions().addTask(project.id, title: 'Task $i'),
      ];
      for (final task in tasks.take(5)) {
        await actions().setTaskCompleted(task.id, true);
      }

      final stored = await repository().findById(project.id);
      expect(stored!.totalTasks, 10);
      expect(stored.completedTasks, 5);
      expect(stored.remainingTasks, 5);
      expect(stored.progress, closeTo(0.5, 0.0001));
    });

    test('a project with no tasks reports no progress', () async {
      final project = await actions().create(name: 'Kosong', category: 'Other');
      final stored = await repository().findById(project.id);
      expect(stored!.progress, 0);
      expect(stored.effectiveNextAction, isNull);
    });

    test('the next action falls back to the first open task', () async {
      final project = await actions().create(
        name: 'Dengan catatan',
        category: 'System',
        nextAction: 'Tunggu review',
      );
      expect(project.effectiveNextAction, 'Tunggu review');

      await actions().addTask(project.id, title: 'Kerjakan migrasi');
      await actions().update(
        id: project.id,
        name: project.name,
        status: ProjectStatus.inDevelopment,
        category: 'System',
        priority: TaskPriority.medium,
      );

      final stored = await repository().findById(project.id);
      expect(stored!.effectiveNextAction, 'Kerjakan migrasi');
    });

    test('status changes and archive are persisted', () async {
      await actions().setStatus('prj-seva', ProjectStatus.inDevelopment);
      final moved = await repository().findById('prj-seva');
      expect(moved!.status, ProjectStatus.inDevelopment);

      await actions().setStatus('prj-seva', ProjectStatus.archived);
      final archived = await repository().findById('prj-seva');
      expect(archived!.status, ProjectStatus.archived);
      expect(archived.status.isOpen, isFalse);
    });

    test('deleting a project takes its tasks with it', () async {
      await actions().delete('prj-mediavault');

      expect(await repository().findById('prj-mediavault'), isNull);
      final remaining = await repository().watchAll().first;
      expect(
        remaining.where((project) => project.id == 'prj-mediavault'),
        isEmpty,
      );
      expect(
        remaining.any((project) => project.id == 'prj-myos'),
        isTrue,
        reason: 'other projects are untouched',
      );
    });

    test('a missing project and a missing task report not found', () async {
      await expectLater(
        repository().setStatus('prj-nope', ProjectStatus.shipped),
        throwsA(isA<NotFoundException>()),
      );
      await expectLater(
        repository().deleteTask('task-nope'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('filters', () {
    test('status filter and open work count follow the data', () async {
      final container = harness.container;
      container.listen(visibleProjectsProvider, (_, _) {}, fireImmediately: true);
      await container.read(projectsProvider.future);

      ProjectsView view() =>
          container.read(visibleProjectsProvider).requireValue;

      expect(view().visible.length, 5);
      expect(view().openPoints, greaterThan(0));

      container.read(projectFilterProvider.notifier).setStatus(ProjectStatus.onHold);
      expect(view().visible.single.name, 'Seva');

      container.read(projectFilterProvider.notifier)
        ..clear()
        ..setStatus(ProjectStatus.shipped);
      final shipped = view();
      expect(shipped.visible.single.name, 'Portfolio v2');
      // A shipped project has no open work.
      expect(shipped.openPoints, 0);

      container.read(projectFilterProvider.notifier)
        ..clear()
        ..setQuery('tidak ada proyek bernama ini');
      expect(view().visible, isEmpty);
    });

    test('the home rail shows open projects, most complete first', () async {
      final container = harness.container;
      container.listen(homeProjectsProvider, (_, _) {}, fireImmediately: true);
      await container.read(projectsProvider.future);
      final rail = container.read(homeProjectsProvider).requireValue;

      expect(rail, hasLength(3));
      expect(rail.every((project) => project.status.isOpen), isTrue);
      expect(rail.first.progress, greaterThanOrEqualTo(rail.last.progress));
    });
  });
}