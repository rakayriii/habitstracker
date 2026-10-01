import 'package:flutter_test/flutter_test.dart';
import 'package:habitstracker/data/database/data_providers.dart';
import 'package:habitstracker/data/repositories/goal_repository.dart';
import 'package:habitstracker/domain/errors.dart';
import 'package:habitstracker/domain/models/goal.dart';
import 'package:habitstracker/features/goals/providers/goal_providers.dart';

import '../support/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() async => harness = await TestHarness.create());
  tearDown(() => harness.dispose());

  GoalRepository repository() => harness.container.read(goalRepositoryProvider);
  GoalActions actions() => harness.container.read(goalActionsProvider);

  group('goals', () {
    test('create writes a readable goal', () async {
      final goal = await actions().create(
        title: 'Dana darurat 6 bulan',
        category: GoalCategory.finance,
        targetValue: 30000000,
        currentValue: 5000000,
        deadline: DateTime(2026, 12, 31),
        priority: GoalPriority.high,
      );

      final stored = await repository().findById(goal.id);
      expect(stored, isNotNull);
      expect(stored!.title, 'Dana darurat 6 bulan');
      expect(stored.targetValue, 30000000);
      expect(stored.status, GoalStatus.active);
    });

    test('create rejects an empty title and a zero target', () async {
      await expectLater(
        actions().create(
          title: '  ',
          category: GoalCategory.finance,
          targetValue: 1000,
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        actions().create(
          title: 'Tidak valid',
          category: GoalCategory.finance,
          targetValue: 0,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('progress is the ratio of current to target, capped at 100',
        () async {
      final goal = await actions().create(
        title: 'Dana darurat',
        category: GoalCategory.finance,
        targetValue: 10000000,
        currentValue: 4000000,
      );
      expect(goal.progress, closeTo(0.4, 0.0001));
      expect(goal.remainingValue, 6000000);

      // Over funded on purpose: the bar must not exceed a full rail.
      await actions().setProgress(goal.id, 12000000);
      final over = await repository().findById(goal.id);
      expect(over!.progress, 1.0);
      expect(over.remainingValue, 0);
    });

    test('pace uses the deadline and the stored value', () async {
      final goal = await actions().create(
        title: 'Dana darurat',
        category: GoalCategory.finance,
        targetValue: 10000000,
        currentValue: 4000000,
        deadline: DateTime.now().add(const Duration(days: 120)),
      );

      expect(goal.daysLeft, 120);
      // 6.000.000 remaining over 120 days.
      expect(goal.requiredPerDay, 50000);
      expect(goal.requiredPerMonth, 1500000);
    });

    test('milestones are stored, toggled and deleted', () async {
      final goal = await actions().create(
        title: 'Dana darurat',
        category: GoalCategory.finance,
        targetValue: 10000000,
        currentValue: 0,
      );

      final milestone = await actions().addMilestone(
        goal.id,
        title: 'Dana darurat 1 bulan',
        targetValue: 2500000,
      );
      var stored = await repository().findById(goal.id);
      expect(stored!.milestones, hasLength(1));
      expect(stored.milestones.first.isCompleted, isFalse);

      await actions().setMilestoneCompleted(milestone.id, true);
      stored = await repository().findById(goal.id);
      expect(stored!.milestones.first.isCompleted, isTrue);
      expect(stored.completedMilestones, 1);

      await actions().deleteMilestone(milestone.id);
      stored = await repository().findById(goal.id);
      expect(stored!.milestones, isEmpty);
    });

    test('completing a goal fills the value and closes the milestones',
        () async {
      final goal = await actions().create(
        title: 'Anggaran bulanan',
        category: GoalCategory.finance,
        targetValue: 12000000,
        currentValue: 6000000,
      );
      await actions().addMilestone(goal.id, title: 'Separuh', targetValue: 6000000);

      await actions().complete(goal.id);
      final stored = await repository().findById(goal.id);
      expect(stored!.status, GoalStatus.completed);
      expect(stored.currentValue, stored.targetValue);
      expect(stored.completedMilestones, 1);
    });

    test('archive and status changes are persisted', () async {
      await actions().setStatus('goal-5k-run', GoalStatus.archived);
      final archived = await repository().findById('goal-5k-run');
      expect(archived!.status, GoalStatus.archived);

      await actions().setStatus('goal-5k-run', GoalStatus.active);
      final active = await repository().findById('goal-5k-run');
      expect(active!.status, GoalStatus.active);
    });

    test('delete removes the goal and its milestones', () async {
      final goal = await actions().create(
        title: 'Sementara',
        category: GoalCategory.other,
        targetValue: 100,
      );
      await actions().addMilestone(goal.id, title: 'Awal', targetValue: 50);

      await actions().delete(goal.id);
      expect(await repository().findById(goal.id), isNull);
    });

    test('a missing goal reports not found', () async {
      await expectLater(
        repository().setStatus('goal-nope', GoalStatus.completed),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('filters', () {
    test('status and category filter the same list', () async {
      // The harness container, so the filter reads the same in-memory database
      // as the rest of the suite.
      final container = harness.container;
      container.listen(visibleGoalsProvider, (_, _) {}, fireImmediately: true);
      final all = await container.read(goalsProvider.future);
      expect(all.length, 8);

      // The view derives from the goal stream, so once that has produced a
      // value the filtered list is available synchronously.
      GoalsView view() => container.read(visibleGoalsProvider).requireValue;

      container.read(goalFilterProvider.notifier).setStatus(GoalStatus.completed);
      final completed = view();
      expect(completed.visible.every((g) => g.status == GoalStatus.completed), isTrue);
      expect(completed.visible, hasLength(2));

      container.read(goalFilterProvider.notifier)
        ..clear()
        ..setCategory(GoalCategory.career);
      final career = view();
      expect(career.visible, hasLength(1));
      expect(career.visible.single.title, 'Sertifikasi CFP');

      // Two filters together can leave nothing behind.
      container.read(goalFilterProvider.notifier)
        ..setStatus(GoalStatus.active)
        ..setCategory(GoalCategory.career);
      expect(view().visible, isEmpty);
    });

    test('the home rail shows the three most urgent active goals', () async {
      final container = harness.container;
      container.listen(homeGoalsProvider, (_, _) {}, fireImmediately: true);
      await container.read(goalsProvider.future);
      final rail = container.read(homeGoalsProvider).requireValue;
      expect(rail, hasLength(3));
      expect(rail.every((goal) => goal.status == GoalStatus.active), isTrue);
      // Sorted by deadline, so the nearest one leads.
      expect(rail.first.daysLeft, lessThanOrEqualTo(rail.last.daysLeft));
    });
  });
}