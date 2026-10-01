import 'package:drift/drift.dart';

import '../../core/utils/id.dart';
import '../../domain/errors.dart';
import '../../domain/models/focus_item.dart';
import '../database/app_database.dart';

/// Focus items for a day.
///
/// The store is date keyed so Today's Focus is a single indexed read, and a
/// backlog from yesterday never appears in this morning's list.
class FocusRepository {
  FocusRepository(this._db);

  final AppDatabase _db;

  static FocusItem _map(FocusItemRow row) {
    return FocusItem(
      id: row.id,
      title: row.title,
      priority: FocusPriority.values.firstWhere(
        (priority) => priority.name == row.priority,
        orElse: () => FocusPriority.p2,
      ),
      date: row.date,
      completedAt: row.completedAt,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Stream<List<FocusItem>> watchForDate(DateTime date) {
    final day = dayOf(date);
    final query = _db.select(_db.focusItems)
      ..where((row) => row.date.equals(day))
      ..orderBy([
        (row) => OrderingTerm.asc(row.completedAt),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_map).toList(growable: false),
    );
  }

  /// Open items from earlier days, which the Home header counts so a backlog is
  /// visible instead of silently dropped.
  Stream<List<FocusItem>> watchOverdue(DateTime date) {
    final day = dayOf(date);
    final query = _db.select(_db.focusItems)
      ..where((row) => row.date.isSmallerThanValue(day) & row.completedAt.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.date)]);
    return query.watch().map(
      (rows) => rows.map(_map).toList(growable: false),
    );
  }

  Stream<FocusItem?> watchById(String id) {
    final query = _db.select(_db.focusItems)..where((row) => row.id.equals(id));
    return query.watchSingleOrNull().map((row) => row == null ? null : _map(row));
  }

  Future<FocusItem?> findById(String id) async {
    final row = await (_db.select(_db.focusItems)..where((f) => f.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<FocusItem> create({
    required String title,
    required FocusPriority priority,
    required DateTime date,
    String? notes,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Judul fokus wajib diisi', field: 'title');
    }
    final now = DateTime.now();
    final id = IdGen.next('focus');
    await _db.into(_db.focusItems).insert(
      FocusItemsCompanion.insert(
        id: id,
        title: trimmed,
        priority: priority.name,
        date: dayOf(date),
        notes: Value(_nullIfEmpty(notes)),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return FocusItem(
      id: id,
      title: trimmed,
      priority: priority,
      date: dayOf(date),
      notes: _nullIfEmpty(notes),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> update(
    String id, {
    required String title,
    required FocusPriority priority,
    DateTime? date,
    String? notes,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Judul fokus wajib diisi', field: 'title');
    }
    final changed = await (_db.update(_db.focusItems)
          ..where((f) => f.id.equals(id)))
        .write(
      FocusItemsCompanion(
        title: Value(trimmed),
        priority: Value(priority.name),
        date: date == null ? const Value.absent() : Value(dayOf(date)),
        notes: Value(_nullIfEmpty(notes)),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (changed == 0) throw NotFoundException('Fokus $id tidak ditemukan');
  }

  Future<void> setCompleted(String id, bool completed) async {
    final changed = await (_db.update(_db.focusItems)
          ..where((f) => f.id.equals(id)))
        .write(
      FocusItemsCompanion(
        completedAt: Value(completed ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (changed == 0) throw NotFoundException('Fokus $id tidak ditemukan');
  }

  Future<void> delete(String id) async {
    final deleted = await (_db.delete(_db.focusItems)..where((f) => f.id.equals(id)))
        .go();
    if (deleted == 0) throw NotFoundException('Fokus $id tidak ditemukan');
  }
}

String? _nullIfEmpty(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
