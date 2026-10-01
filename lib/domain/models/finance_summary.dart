import 'package:flutter/foundation.dart';

/// Reporting window for the finance dashboard. Every cashflow figure on the
/// Finance screen is computed for exactly one of these.
enum FinancePeriod {
  thisMonth('Bulan ini'),
  lastMonth('Bulan lalu'),
  thisYear('Tahun ini');

  const FinancePeriod(this.label);

  final String label;

  /// Half open range, [start, endExclusive).
  ({DateTime start, DateTime endExclusive}) range(DateTime now) {
    return switch (this) {
      FinancePeriod.thisMonth => (
        start: DateTime(now.year, now.month),
        endExclusive: DateTime(now.year, now.month + 1),
      ),
      FinancePeriod.lastMonth => (
        start: DateTime(now.year, now.month - 1),
        endExclusive: DateTime(now.year, now.month),
      ),
      FinancePeriod.thisYear => (
        start: DateTime(now.year),
        endExclusive: DateTime(now.year + 1),
      ),
    };
  }
}

@immutable
class AllocationSlice {
  const AllocationSlice({
    required this.accountId,
    required this.label,
    required this.value,
    required this.weight,
  });

  final String accountId;
  final String label;
  final int value;
  final double weight;
}

@immutable
class MonthlyCashflow {
  const MonthlyCashflow({
    required this.label,
    required this.income,
    required this.expenses,
  });

  final String label;
  final int income;
  final int expenses;

  int get retained => income - expenses;
  double get retentionRate => income == 0 ? 0 : retained / income;
}

@immutable
class FinanceSummary {
  const FinanceSummary({
    required this.netWorth,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.income,
    required this.expenses,
    required this.allocation,
    required this.cashflow,
    required this.netWorthDelta,
    required this.trend,
    required this.liquidValue,
  });

  const FinanceSummary.empty()
    : netWorth = 0,
      totalAssets = 0,
      totalLiabilities = 0,
      income = 0,
      expenses = 0,
      allocation = const [],
      cashflow = const [],
      netWorthDelta = 0,
      trend = const [],
      liquidValue = 0;

  final int netWorth;
  final int totalAssets;
  final int totalLiabilities;

  /// Income and expenses for the selected [FinancePeriod]. Transfers are
  /// excluded: they move money, they do not create or destroy it.
  final int income;
  final int expenses;
  final List<AllocationSlice> allocation;
  final List<MonthlyCashflow> cashflow;

  /// Net worth change over the trailing window, derived from the ledger.
  final int netWorthDelta;

  /// Daily net worth for the same window, oldest first. Empty when the ledger
  /// is younger than the window, and the card then omits the chart rather than
  /// drawing a shape that means nothing.
  final List<double> trend;

  /// Cash on hand: the balance of every asset account that can be spent today
  /// (cash, bank, e-wallet). Investments and gold are deliberately excluded.
  final int liquidValue;

  /// The window the percentage change is measured against. Null when that
  /// baseline is not a positive number, because a percentage of a negative
  /// base is a figure nobody can read.
  double? get netWorthDeltaRatio {
    final baseline = netWorth - netWorthDelta;
    if (baseline <= 0) return null;
    return netWorthDelta / baseline;
  }

  int get retained => income - expenses;
  double get retentionRate => income == 0 ? 0 : retained / income;
}
