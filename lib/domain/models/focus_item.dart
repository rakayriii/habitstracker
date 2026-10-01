import 'package:flutter/foundation.dart';

enum FocusPriority {
  p1('P1', 'Prioritas tinggi'),
  p2('P2', 'Prioritas sedang'),
  p3('P3', 'Bila ada ruang');

  const FocusPriority(this.label, this.hint);

  final String label;
  final String hint;
}

@immutable
class FocusItem {
  const FocusItem({
    required this.id,
    required this.title,
    required this.priority,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.notes,
  });

  final String id;
  final String title;
  final FocusPriority priority;

  /// The day this item belongs to. Today's Focus only reads the current day,
  /// so a backlog never leaks into the morning view.
  final DateTime date;
  final DateTime? completedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => completedAt != null;

  int get sortWeight => switch (priority) {
    FocusPriority.p1 => 0,
    FocusPriority.p2 => 1,
    FocusPriority.p3 => 2,
  };
}

/// A day truncated to midnight, used for focus grouping. Comparing truncated
/// days avoids timezone drift between "stored" and "today".
DateTime dayOf(DateTime date) => DateTime(date.year, date.month, date.day);
