import 'package:drift/drift.dart';

import '../../core/utils/id.dart';
import '../../core/utils/stream_utils.dart';
import '../../domain/errors.dart';
import '../../domain/models/goal.dart';
import '../database/app_database.dart';

/// Goals and their milestones.
///
/// A goal's progress is `currentValue / targetValue`, computed in the domain
/// model, never stored. Milestones are thresholds on the same value and are
/// completed explicitly by the user, so a milestone list can disagree with the
/// progress bar on purpose: the bar is the money, the milestone is the promise.
class GoalRepository {
  GoalRepository(this._db);

  final AppDatabase _db;

  static GoalMilestone _mapMilestone(GoalMilestoneRow row) {
    return GoalMilestone(
      id: row.id,
      goalId: row.goalId,
      title: row.title,
      targetValue: row.targetValue,
      sortOrder: row.sortOrder,
      completedAt: row.completedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static Goal _map(GoalRow row, List<GoalMilestoneRow> milestones) {
    return Goal(
      id: row.id,
      title: row.title,
      description: row.description,
      category: GoalCategory.values.firstWhere(
        (category) => category.name == row.category,
        orElse: () => GoalCategory.other,
      ),
      targetValue: row.targetValue,
      currentValue: row.currentValue,
      deadline: row.deadline,
      priority: GoalPriority.values.firstWhere(
        (priority) => priority.name == row.priority,
        orElse: () => GoalPriority.medium,
      ),
      status: GoalStatus.values.firstWhere(
        (status) => status.name == row.status,
        orElse: () => GoalStatus.active,
      ),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      milestones: [for (final milestone in milestones) _mapMilestone(milestone)],
    );
  }

  Stream<List<Goal>> watchAll() {
    final goals = _db.select(_db.goals)
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    final milestones = _db.select(_db.goalMilestones)
      ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]);

    // The milestone stream is watched too, so completing a milestone refreshes
    // every screen that shows the goal without any manual invalidation.
    return combineLatest2(
      goals.watch(),
      milestones.watch(),
      (goalRows, milestoneRows) => [
        for (final goal in goalRows)
          _map(
            goal,
            milestoneRows.where((m) => m.goalId == goal.id).toList(),
          ),
      ],
    );
  }

  Stream<Goal?> watchById(String id) {
    return watchAll().map(
      (goals) => goals.where((goal) => goal.id == id).firstOrNull,
    );
  }

  Future<Goal?> findById(String id) async {
    final row = await (_db.select(_db.goals)..where((g) => g.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    final milestones = await (_db.select(_db.goalMilestones)
          ..where((m) => m.goalId.equals(id))
          ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]))
        .get();
    return _map(row, milestones);
  }

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
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Judul target wajib diisi', field: 'title');
    }
    if (targetValue <= 0) {
      throw const ValidationException(
        'Target nilai harus lebih besar dari nol',
        field: 'targetValue',
      );
    }
    if (currentValue < 0) {
      throw const ValidationException(
        'Nilai saat ini tidak boleh negatif',
        field: 'currentValue',
      );
    }
    final now = DateTime.now();
    final id = IdGen.next('goal');

    await _db.transaction(() async {
      await _db.into(_db.goals).insert(
        GoalsCompanion.insert(
          id: id,
          title: trimmed,
          description: Value(_nullIfEmpty(description)),
          category: category.name,
          status: status.name,
          targetValue: targetValue,
          currentValue: Value(currentValue),
          priority: priority.name,
          deadline: Value(deadline),
          createdAt: now,
          updatedAt: now,
        ),
      );
      var order = 0;
      for (final milestone in milestones) {
        if (milestone.title.trim().isEmpty || milestone.targetValue <= 0) {
          continue;
        }
        await _db.into(_db.goalMilestones).insert(
          GoalMilestonesCompanion.insert(
            id: IdGen.next('ms'),
            goalId: id,
            title: milestone.title.trim(),
            targetValue: milestone.targetValue,
            sortOrder: Value(order),
            completedAt: Value(
              currentValue >= milestone.targetValue ? now : null,
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
        order++;
      }
    });

    final created = await findById(id);
    if (created == null) throw const StorageException('Target gagal disimpan');
    return created;
  }

  Future<void> update(
    String id, {
    required String title,
    required GoalCategory category,
    required int targetValue,
    required int currentValue,
    String? description,
    DateTime? deadline,
    required GoalPriority priority,
    required GoalStatus status,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Judul target wajib diisi', field: 'title');
    }
    if (targetValue <= 0) {
      throw const ValidationException(
        'Target nilai harus lebih besar dari nol',
        field: 'targetValue',
      );
    }
    if (currentValue < 0) {
      throw const ValidationException(
        'Nilai saat ini tidak boleh negatif',
        field: 'currentValue',
      );
    }
    final changed = await (_db.update(_db.goals)..where((g) => g.id.equals(id)))
        .write(
          GoalsCompanion(
            title: Value(trimmed),
            description: Value(_nullIfEmpty(description)),
            category: Value(category.name),
            targetValue: Value(targetValue),
            currentValue: Value(currentValue),
            priority: Value(priority.name),
            status: Value(status.name),
            deadline: Value(deadline),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed == 0) throw NotFoundException('Target $id tidak ditemukan');
  }

  /// Sets the progress value. Kept separate from [update] because this is the
  /// one field a dashboard widget changes on its own, and it must never be
  /// able to drive the value negative.
  Future<void> setProgress(String id, int currentValue) async {
    if (currentValue < 0) {
      throw const ValidationException(
        'Nilai saat ini tidak boleh negatif',
        field: 'currentValue',
      );
    }
    final changed = await (_db.update(_db.goals)..where((g) => g.id.equals(id)))
        .write(
          GoalsCompanion(
            currentValue: Value(currentValue),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed == 0) throw NotFoundException('Target $id tidak ditemukan');
  }

  Future<void> addProgress(String id, int delta) async {
    final goal = await findById(id);
    if (goal == null) throw NotFoundException('Target $id tidak ditemukan');
    await setProgress(id, goal.currentValue + delta);
  }

  Future<void> setStatus(String id, GoalStatus status) async {
    final changed = await (_db.update(_db.goals)..where((g) => g.id.equals(id)))
        .write(
          GoalsCompanion(
            status: Value(status.name),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed == 0) throw NotFoundException('Target $id tidak ditemukan');
  }

  /// Marks a goal complete and, when a completion value is supplied, records it
  /// as the final progress.
  Future<void> complete(String id, {int? finalValue}) async {
    final goal = await findById(id);
    if (goal == null) throw NotFoundException('Target $id tidak ditemukan');
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
        GoalsCompanion(
          status: Value(GoalStatus.completed.name),
          currentValue: Value(finalValue ?? goal.targetValue),
          updatedAt: Value(now),
        ),
      );
      if (finalValue == null) {
        // Everything below the target is now reached.
        await (_db.update(_db.goalMilestones)
              ..where(
                (m) => m.goalId.equals(id) & m.completedAt.isNull(),
              ))
            .write(GoalMilestonesCompanion(completedAt: Value(now)));
      }
    });
  }

  Future<void> delete(String id) async {
    final deleted = await (_db.delete(_db.goals)..where((g) => g.id.equals(id)))
        .go();
    if (deleted == 0) throw NotFoundException('Target $id tidak ditemukan');
  }

  Future<GoalMilestone> addMilestone(
    String goalId, {
    required String title,
    required int targetValue,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException(
        'Nama milestone wajib diisi',
        field: 'title',
      );
    }
    if (targetValue <= 0) {
      throw const ValidationException(
        'Nilai milestone harus lebih besar dari nol',
        field: 'targetValue',
      );
    }
    final goal = await findById(goalId);
    if (goal == null) throw NotFoundException('Target $goalId tidak ditemukan');
    final now = DateTime.now();
    final id = IdGen.next('ms');
    await _db.into(_db.goalMilestones).insert(
      GoalMilestonesCompanion.insert(
        id: id,
        goalId: goalId,
        title: trimmed,
        targetValue: targetValue,
        sortOrder: Value(goal.milestones.length),
        completedAt: Value(goal.currentValue >= targetValue ? now : null),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return GoalMilestone(
      id: id,
      goalId: goalId,
      title: trimmed,
      targetValue: targetValue,
      sortOrder: goal.milestones.length,
      completedAt: goal.currentValue >= targetValue ? now : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateMilestone(
    String milestoneId, {
    required String title,
    required int targetValue,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException(
        'Nama milestone wajib diisi',
        field: 'title',
      );
    }
    if (targetValue <= 0) {
      throw const ValidationException(
        'Nilai milestone harus lebih besar dari nol',
        field: 'targetValue',
      );
    }
    final changed = await (_db.update(_db.goalMilestones)
          ..where((m) => m.id.equals(milestoneId)))
        .write(
          GoalMilestonesCompanion(
            title: Value(trimmed),
            targetValue: Value(targetValue),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed == 0) {
      throw NotFoundException('Milestone $milestoneId tidak ditemukan');
    }
  }

  Future<void> setMilestoneCompleted(String milestoneId, bool completed) async {
    final changed = await (_db.update(_db.goalMilestones)
          ..where((m) => m.id.equals(milestoneId)))
        .write(
          GoalMilestonesCompanion(
            completedAt: Value(completed ? DateTime.now() : null),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed == 0) {
      throw NotFoundException('Milestone $milestoneId tidak ditemukan');
    }
  }

  Future<void> deleteMilestone(String milestoneId) async {
    final deleted = await (_db.delete(_db.goalMilestones)
          ..where((m) => m.id.equals(milestoneId)))
        .go();
    if (deleted == 0) {
      throw NotFoundException('Milestone $milestoneId tidak ditemukan');
    }
  }
}

String? _nullIfEmpty(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
