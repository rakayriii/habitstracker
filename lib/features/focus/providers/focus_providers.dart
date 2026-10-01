import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/data_providers.dart';
import '../../../data/repositories/focus_repository.dart';
import '../../../domain/models/focus_item.dart';

/// Today's focus. The date comes from the injected clock, so a test can pin it
/// and the day rolls over on its own in production.
final todayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(clockProvider)();
  return dayOf(now);
});

final todayFocusProvider = StreamProvider<List<FocusItem>>((ref) {
  return ref.watch(focusRepositoryProvider).watchForDate(ref.watch(todayProvider));
});

/// Open items from previous days. The Home header counts them so a backlog is
/// visible rather than quietly dropped.
final overdueFocusProvider = StreamProvider<List<FocusItem>>((ref) {
  return ref.watch(focusRepositoryProvider).watchOverdue(ref.watch(todayProvider));
});

final focusItemProvider = StreamProvider.family<FocusItem?, String>((ref, id) {
  return ref.watch(focusRepositoryProvider).watchById(id);
});

final focusCountsProvider = Provider<({int done, int total})>((ref) {
  final items = ref.watch(todayFocusProvider).value ?? const <FocusItem>[];
  return (
    done: items.where((item) => item.isCompleted).length,
    total: items.length,
  );
});

/// The first open P1, or the first open item when no P1 is outstanding. This is
/// the "next up" line under the section header.
final nextFocusProvider = Provider<FocusItem?>((ref) {
  final items = ref.watch(todayFocusProvider).value ?? const <FocusItem>[];
  final open = items.where((item) => !item.isCompleted).toList()
    ..sort((a, b) {
      final byPriority = a.sortWeight.compareTo(b.sortWeight);
      return byPriority != 0 ? byPriority : a.createdAt.compareTo(b.createdAt);
    });
  return open.isEmpty ? null : open.first;
});

/// Writes for focus items.
class FocusActions {
  FocusActions(this._ref);

  final Ref _ref;

  FocusRepository get _repository => _ref.read(focusRepositoryProvider);

  Future<FocusItem> create({
    required String title,
    required FocusPriority priority,
    DateTime? date,
    String? notes,
  }) {
    return _repository.create(
      title: title,
      priority: priority,
      date: date ?? _ref.read(todayProvider),
      notes: notes,
    );
  }

  Future<void> update({
    required String id,
    required String title,
    required FocusPriority priority,
    DateTime? date,
    String? notes,
  }) {
    return _repository.update(
      id,
      title: title,
      priority: priority,
      date: date,
      notes: notes,
    );
  }

  Future<void> setCompleted(String id, bool completed) =>
      _repository.setCompleted(id, completed);

  Future<void> delete(String id) => _repository.delete(id);
}

final focusActionsProvider = Provider<FocusActions>(FocusActions.new);
