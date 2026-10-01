import '../../core/utils/formatters.dart';
import '../models/account.dart';
import '../models/finance_summary.dart';
import '../models/transaction.dart';

/// Pure business calculations for the finance module.
///
/// Everything here is a function of persisted data: no clock reads other than
/// the `now` that callers pass in, no globals, no database access. That keeps
/// the arithmetic testable without a database and keeps it out of the widgets.
class FinanceCalculator {
  const FinanceCalculator._();

  /// Effect of one transaction on one account balance, in rupiah.
  ///
  /// Liability accounts invert the sign: an expense on a credit card increases
  /// the amount owed, so the stored balance stays positive and reads as
  /// "tagihan", while the portfolio effect stays negative.
  static int effectOnAccount(
    Transaction transaction,
    String accountId,
    bool isLiability,
  ) {
    var delta = 0;
    switch (transaction.type) {
      case TransactionType.income:
      case TransactionType.expense:
        if (transaction.accountId == accountId) {
          delta = transaction.type == TransactionType.income
              ? transaction.amount
              : -transaction.amount;
        }
      case TransactionType.transfer:
        if (transaction.accountId == accountId) {
          delta = -transaction.amount;
        } else if (transaction.targetAccountId == accountId) {
          delta = transaction.amount;
        }
    }
    return isLiability ? -delta : delta;
  }

  /// Balance of every account from the full ledger. The cached
  /// [Account.balance] column is refreshed from this, so the two can never
  /// disagree.
  static Map<String, int> balancesFrom({
    required List<Account> accounts,
    required List<Transaction> transactions,
  }) {
    final balances = {for (final account in accounts) account.id: 0};
    for (final transaction in transactions) {
      for (final account in accounts) {
        final delta = effectOnAccount(
          transaction,
          account.id,
          account.isLiability,
        );
        if (delta != 0) balances[account.id] = balances[account.id]! + delta;
      }
    }
    return balances;
  }

  /// Net worth at the end of [day].
  ///
  /// Transfers cancel out, income adds, expense subtracts, which is also the
  /// correct reading for a liability account: charging the card reduces net
  /// worth.
  static int netWorthOn({
    required List<Transaction> transactions,
    required DateTime day,
  }) {
    final cutoff = DateTime(day.year, day.month, day.day, 23, 59, 59);
    var total = 0;
    for (final transaction in transactions) {
      if (!transaction.date.isAfter(cutoff)) {
        total += transaction.portfolioEffect;
      }
    }
    return total;
  }

  /// Daily net worth for the trailing [days] window, oldest first. Two points
  /// minimum or the caller should not draw a line.
  static List<double> netWorthSeries({
    required List<Transaction> transactions,
    required DateTime now,
    int days = 30,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var offset = days - 1; offset >= 0; offset--)
        netWorthOn(
          transactions: transactions,
          day: today.subtract(Duration(days: offset)),
        ).toDouble(),
    ];
  }

  static FinanceSummary summarise({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required FinancePeriod period,
    required DateTime now,
    int trendDays = 30,
  }) {
    final assets = accounts.where((a) => a.isAsset && !a.isArchived).toList();
    final liabilities = accounts
        .where((a) => a.isLiability && !a.isArchived)
        .toList();

    final totalAssets = assets.fold(0, (sum, a) => sum + a.balance);
    final totalLiabilities = liabilities.fold(0, (sum, a) => sum + a.balance);
    final netWorth = totalAssets - totalLiabilities;

    final range = period.range(now);
    var income = 0;
    var expenses = 0;
    for (final transaction in transactions) {
      final inRange =
          !transaction.date.isBefore(range.start) &&
          transaction.date.isBefore(range.endExclusive);
      if (!inRange) continue;
      switch (transaction.type) {
        case TransactionType.income:
          income += transaction.amount;
        case TransactionType.expense:
          expenses += transaction.amount;
        case TransactionType.transfer:
          break;
      }
    }

    final allocation = totalAssets <= 0
        ? const <AllocationSlice>[]
        : [
            for (final account in assets)
              AllocationSlice(
                accountId: account.id,
                label: account.name,
                value: account.balance,
                // A negative asset balance (overdrawn) cannot be a share of
                // the allocation, so it is reported as zero rather than
                // producing a nonsense percentage.
                weight: account.balance <= 0
                    ? 0
                    : account.balance / totalAssets,
              ),
          ]..sort((a, b) => b.value.compareTo(a.value));

    final series = netWorthSeries(
      transactions: transactions,
      now: now,
      days: trendDays,
    );
    final delta = series.length < 2 ? 0 : (series.last - series.first).round();

    return FinanceSummary(
      netWorth: netWorth,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      income: income,
      expenses: expenses,
      allocation: allocation,
      cashflow: monthlyCashflow(
        transactions: transactions,
        now: now,
        months: 6,
      ),
      netWorthDelta: delta,
      trend: series,
      liquidValue: assets
          .where(
            (account) =>
                account.type == AccountType.cash ||
                account.type == AccountType.bank ||
                account.type == AccountType.ewallet,
          )
          .fold(0, (sum, account) => sum + account.balance),
    );
  }

  static List<MonthlyCashflow> monthlyCashflow({
    required List<Transaction> transactions,
    required DateTime now,
    int months = 6,
  }) {
    final result = <MonthlyCashflow>[];
    for (var offset = months - 1; offset >= 0; offset--) {
      final start = DateTime(now.year, now.month - offset);
      final end = DateTime(now.year, now.month - offset + 1);
      var income = 0;
      var expenses = 0;
      for (final transaction in transactions) {
        if (transaction.date.isBefore(start) ||
            !transaction.date.isBefore(end)) {
          continue;
        }
        if (transaction.type == TransactionType.income) {
          income += transaction.amount;
        } else if (transaction.type == TransactionType.expense) {
          expenses += transaction.amount;
        }
      }
      result.add(
        MonthlyCashflow(
          label: Fmt.monthLabel(start),
          income: income,
          expenses: expenses,
        ),
      );
    }
    return result;
  }
}
