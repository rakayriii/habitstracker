import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/data_providers.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../domain/models/goal.dart';

@immutable
class GoalFilter {
  const GoalFilter({this.status, this.category});

  final GoalStatus? status;
  final GoalCategory? category;

  bool get isActive => status != null || category != null;

  GoalFilter copyWith({
    GoalStatus? status,
    GoalCategory? category,
    bool clearStatus = false,
    bool clearCategory = false,
  }) {
    return GoalFilter(
      status: clearStatus ? null : (status ?? this.status),
      category: clearCategory ? null : (category ?? this.category),
    );
  }
}

class GoalFilterNotifier extends Notifier<GoalFilter> {
  @override
  GoalFilter build() => const GoalFilter();

  void setStatus(GoalStatus? status) {
    state = status == null
        ? state.copyWith(clearStatus: true)
        : state.copyWith(status: status);
  }

  void setCategory(GoalCategory? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(category: category);
  }

  void clear() => state = const GoalFilter();
}

final goalFilterProvider = NotifierProvider<GoalFilterNotifier, GoalFilter>(
  GoalFilterNotifier.new,
);

final goalsProvider = StreamProvider<List<Goal>>((ref) {
  return ref.watch(goalRepositoryProvider).watchAll();
});

final goalProvider = StreamProvider.family<Goal?, String>((ref, id) {
  return ref.watch(goalRepositoryProvider).watchById(id);
});

/// The list as the screen shows it, plus the counts the filter rail needs so a
/// chip can say how many rows it will reveal.
@immutable
class GoalsView {
  const GoalsView({
    required this.visible,
    required this.total,
    required this.statusCounts,
    required this.categoryCounts,
  });

  final List<Goal> visible;
  final int total;
  final Map<GoalStatus, int> statusCounts;
  final Map<GoalCategory, int> categoryCounts;
}

final visibleGoalsProvider = Provider<AsyncValue<GoalsView>>((ref) {
  final goals = ref.watch(goalsProvider);
  final filter = ref.watch(goalFilterProvider);

  return goals.whenData((all) {
    final statusCounts = <GoalStatus, int>{};
    final categoryCounts = <GoalCategory, int>{};
    for (final goal in all) {
      statusCounts[goal.status] = (statusCounts[goal.status] ?? 0) + 1;
      categoryCounts[goal.category] =
          (categoryCounts[goal.category] ?? 0) + 1;
    }

    // Active goals first, then by how close the deadline is, then by priority.
    final filtered = [
      for (final goal in all)
        if (filter.status == null || goal.status == filter.status)
          if (filter.category == null || goal.category == filter.category) goal,
    ]..sort((a, b) {
        if (a.status != b.status) {
          return a.status.index.compareTo(b.status.index);
        }
        if (a.deadline != null && b.deadline != null) {
          final byDate = a.deadline!.compareTo(b.deadline!);
          if (byDate != 0) return byDate;
        } else if (a.deadline != null) {
          return -1;
        } else if (b.deadline != null) {
          return 1;
        }
        return b.priority.index.compareTo(a.priority.index);
      });

    return GoalsView(
      visible: filtered,
      total: all.length,
      statusCounts: statusCounts,
      categoryCounts: categoryCounts,
    );
  });
});

/// Active goals for the Home rail, closest deadline first.
final homeGoalsProvider = Provider<AsyncValue<List<Goal>>>((ref) {
  return ref.watch(goalsProvider).whenData((all) {
    final active = all.where((goal) => goal.status == GoalStatus.active).toList()
      ..sort((a, b) {
        if (a.deadline == null && b.deadline == null) {
          return b.progress.compareTo(a.progress);
        }
        if (a.deadline == null) return 1;
        if (b.deadline == null) return -1;
        return a.deadline!.compareTo(b.deadline!);
      });
    return active.take(3).toList();
  });
});

/// Aggregate progress across the active goals. Unweighted on purpose: the list
/// mixes rupiah targets with session counts, so a weighted average would be
/// dominated by whichever goal carries the biggest number.
final goalCompletionProvider = Provider<AsyncValue<double>>((ref) {
  return ref.watch(goalsProvider).whenData((all) {
    final active = all.where((goal) => goal.status == GoalStatus.active).toList();
    if (active.isEmpty) return 0.0;
    final total = active.fold<double>(0, (sum, goal) => sum + goal.progress);
    return total / active.length;
  });
});

final onTrackCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(goalsProvider).whenData(
    (all) => all
        .where((goal) => goal.status == GoalStatus.active && goal.isOnTrack)
        .length,
  );
});

/// Writes for the Goals module.
class GoalActions {
  GoalActions(this._ref);

  final Ref _ref;

  GoalRepository get _repository => _ref.read(goalRepositoryProvider);

  Future<Goal> create({
    required String title,
    required GoalCategory category,
    required int targetValue,
    int currentValue = 0,
    String? description,
    DateTime? deadline,
    GoalPriority priority = GoalPriority.medium,
    GoalStatus status = GoalStatus.active,
    List<({String title, int targetValue})> milestones = const [],
  }) {
    return _repository.create(
      title: title,
      category: category,
      targetValue: targetValue,
      currentValue: currentValue,
      description: description,
      deadline: deadline,
      priority: priority,
      status: status,
      milestones: milestones,
    );
  }

  Future<void> update({
    required String id,
    required String title,
    required GoalCategory category,
    required int targetValue,
    required int currentValue,
    String? description,
    DateTime? deadline,
    required GoalPriority priority,
    required GoalStatus status,
  }) {
    return _repository.update(
      id,
      title: title,
      category: category,
      targetValue: targetValue,
      currentValue: currentValue,
      description: description,
      deadline: deadline,
      priority: priority,
      status: status,
    );
  }

  Future<void> setProgress(String id, int value) =>
      _repository.setProgress(id, value);

  Future<void> addProgress(String id, int delta) =>
      _repository.addProgress(id, delta);

  Future<void> setStatus(String id, GoalStatus status) =>
      _repository.setStatus(id, status);

  Future<void> complete(String id, {int? finalValue}) =>
      _repository.complete(id, finalValue: finalValue);

  Future<void> delete(String id) => _repository.delete(id);

  Future<GoalMilestone> addMilestone(
    String goalId, {
    required String title,
    required int targetValue,
  }) {
    return _repository.addMilestone(
      goalId,
      title: title,
      targetValue: targetValue,
    );
  }

  Future<void> updateMilestone(
    String milestoneId, {
    required String title,
    required int targetValue,
  }) {
    return _repository.updateMilestone(
      milestoneId,
      title: title,
      targetValue: targetValue,
    );
  }

  Future<void> setMilestoneCompleted(String milestoneId, bool completed) =>
      _repository.setMilestoneCompleted(milestoneId, completed);

  Future<void> deleteMilestone(String milestoneId) =>
      _repository.deleteMilestone(milestoneId);
}

final goalActionsProvider = Provider<GoalActions>(GoalActions.new);
