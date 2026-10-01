import 'package:flutter/foundation.dart';

enum TransactionType {
  income('Income', 'Uang masuk'),
  expense('Expense', 'Uang keluar'),
  transfer('Transfer', 'Perpindahan antar akun');

  const TransactionType(this.label, this.hint);

  final String label;
  final String hint;
}

@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.title,
    required this.accountId,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.accountName = '',
    this.targetAccountId,
    this.targetAccountName,
    this.notes,
  });

  final String id;

  /// Always stored positive. Direction comes from [type].
  final int amount;
  final TransactionType type;
  final String category;
  final String title;
  final String accountId;
  final String accountName;
  final String? targetAccountId;
  final String? targetAccountName;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isTransfer => type == TransactionType.transfer;

  /// Signed effect on the net worth of the whole portfolio, used by the
  /// cashflow and net worth series calculations.
  int get portfolioEffect =>
      type == TransactionType.income ? amount : -amount;

  String get displayCategory =>
      category.trim().isEmpty ? type.label : category.trim();

  Transaction copyWith({
    String? accountName,
    String? targetAccountName,
  }) {
    return Transaction(
      id: id,
      amount: amount,
      type: type,
      category: category,
      title: title,
      accountId: accountId,
      accountName: accountName ?? this.accountName,
      targetAccountId: targetAccountId,
      targetAccountName: targetAccountName ?? this.targetAccountName,
      date: date,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
