import 'package:flutter/foundation.dart';

enum GoalCategory {
  finance('Finance'),
  health('Health'),
  learning('Learning'),
  system('System'),
  career('Career'),
  other('Other');

  const GoalCategory(this.label);

  final String label;
}

enum GoalStatus {
  active('Active'),
  completed('Completed'),
  archived('Archived');

  const GoalStatus(this.label);

  final String label;
}

enum GoalPriority {
  low('Low'),
  medium('Medium'),
  high('High');

  const GoalPriority(this.label);

  final String label;
}

@immutable
class GoalMilestone {
  const GoalMilestone({
    required this.id,
    required this.goalId,
    required this.title,
    required this.targetValue,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String goalId;
  final String title;
  final int targetValue;
  final int sortOrder;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => completedAt != null;
}

@immutable
class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.category,
    required this.targetValue,
    required this.currentValue,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.deadline,
    this.milestones = const [],
  });

  final String id;
  final String title;
  final String? description;
  final GoalCategory category;

  /// Rupiah, or a plain count for non-currency goals.
  final int targetValue;
  final int currentValue;
  final DateTime? deadline;
  final GoalPriority priority;
  final GoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GoalMilestone> milestones;

  bool get isCurrency => category == GoalCategory.finance;

  /// currentValue / targetValue, hard clamped to 0..1. A goal can be
  /// over-funded, the bar never is.
  double get progress {
    if (targetValue <= 0) return 0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  int get remainingValue =>
      (targetValue - currentValue).clamp(0, targetValue);

  int get daysLeft {
    final end = deadline;
    if (end == null) return 0;
    final today = DateTime.now();
    return DateTime(end.year, end.month, end.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  bool get isOverdue => deadline != null && daysLeft < 0 && status == GoalStatus.active;

  int get completedMilestones => milestones.where((m) => m.isCompleted).length;

  /// Remaining amount divided by the days left. Zero when there is no
  /// deadline: a goal without a date has no daily rate.
  int get requiredPerDay {
    final end = deadline;
    if (end == null) return 0;
    final days = daysLeft;
    if (days <= 0) return remainingValue;
    return (remainingValue / days).round();
  }

  /// The same figure expressed monthly, using a 30 day month so the number
  /// matches what a person would budget.
  int get requiredPerMonth => (requiredPerDay * 30).round();

  /// Progres harus sudah mengejar porsi waktu yang berjalan. The window opens
  /// one year before the deadline, which is the planning horizon the product
  /// assumes when no explicit start date is stored.
  bool get isOnTrack {
    if (status != GoalStatus.active) return true;
    final end = deadline;
    if (end == null) return true;
    final start = DateTime(end.year - 1, end.month, end.day);
    final total = end.difference(start).inDays;
    if (total <= 0) return true;
    final elapsed = DateTime.now().difference(start).inDays;
    return progress >= (elapsed / total).clamp(0.0, 1.0);
  }

  /// Short pace label used on the cards. Empty when there is no deadline.
  String get pace {
    if (status == GoalStatus.completed) return 'Selesai';
    if (status == GoalStatus.archived) return 'Diarsipkan';
    final end = deadline;
    if (end == null) return 'Tanpa tenggat';
    if (daysLeft < 0) return 'Terlambat';
    if (daysLeft <= 30) return '$daysLeft hari lagi';
    if (daysLeft <= 400) return '${(daysLeft / 30).round()} bulan lagi';
    final years = daysLeft / 365;
    return '${years.toStringAsFixed(1).replaceAll('.', ',')} tahun lagi';
  }
}
