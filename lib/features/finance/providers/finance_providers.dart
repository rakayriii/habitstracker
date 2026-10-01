import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/data_providers.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/finance_summary.dart';
import '../../../domain/models/transaction.dart';

/// Reporting period for the whole Finance screen. Changing it recomputes
/// income, expenses and retained capital; nothing on this screen is hardcoded.
class FinancePeriodNotifier extends Notifier<FinancePeriod> {
  @override
  FinancePeriod build() => FinancePeriod.thisMonth;

  void select(FinancePeriod period) => state = period;
}

final financePeriodProvider =
    NotifierProvider<FinancePeriodNotifier, FinancePeriod>(
      FinancePeriodNotifier.new,
    );

final financeSummaryProvider = StreamProvider<FinanceSummary>((ref) {
  final period = ref.watch(financePeriodProvider);
  return ref.watch(financeRepositoryProvider).watchSummary(period);
});

final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(financeRepositoryProvider).watchAccounts();
});

final accountProvider = StreamProvider.family<Account?, String>((ref, id) {
  return ref.watch(financeRepositoryProvider).watchAccount(id);
});

final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(financeRepositoryProvider).watchTransactions();
});

/// One transaction, watched, so the edit form and the detail screen both stay
/// in step with a change made anywhere else.
final transactionByIdProvider = StreamProvider.family<Transaction?, String>(
  (ref, id) => ref.watch(transactionRepositoryProvider).watchById(id),
);

@immutable
class TransactionFilter {
  const TransactionFilter({this.type, this.accountId, this.query = ''});

  final TransactionType? type;
  final String? accountId;
  final String query;

  bool get isActive => type != null || accountId != null || query.isNotEmpty;

  int get activeCount =>
      (type != null ? 1 : 0) +
      (accountId != null ? 1 : 0) +
      (query.isNotEmpty ? 1 : 0);

  TransactionFilter copyWith({
    TransactionType? type,
    String? accountId,
    String? query,
    bool clearType = false,
    bool clearAccount = false,
  }) {
    return TransactionFilter(
      type: clearType ? null : (type ?? this.type),
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      query: query ?? this.query,
    );
  }
}

class TransactionFilterNotifier extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => const TransactionFilter();

  void setType(TransactionType? type) {
    state = type == null
        ? state.copyWith(clearType: true)
        : state.copyWith(type: type);
  }

  void setAccount(String? accountId) {
    state = accountId == null
        ? state.copyWith(clearAccount: true)
        : state.copyWith(accountId: accountId);
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void clear() => state = const TransactionFilter();
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterNotifier, TransactionFilter>(
      TransactionFilterNotifier.new,
    );

/// The ledger as the list screen shows it: filtered by type, account and free
/// text, always newest first.
final filteredTransactionsProvider =
    Provider<AsyncValue<List<Transaction>>>((ref) {
      final all = ref.watch(transactionsProvider);
      final filter = ref.watch(transactionFilterProvider);
      return all.whenData((transactions) {
        final query = filter.query.trim().toLowerCase();
        return [
          for (final transaction in transactions)
            if (filter.type == null || transaction.type == filter.type)
              if (filter.accountId == null ||
                  transaction.accountId == filter.accountId ||
                  transaction.targetAccountId == filter.accountId)
                if (query.isEmpty ||
                    transaction.title.toLowerCase().contains(query) ||
                    transaction.displayCategory.toLowerCase().contains(query) ||
                    transaction.accountName.toLowerCase().contains(query))
                  transaction,
        ];
      });
    });

/// Counts per type, used by the filter rail badges.
final transactionTypeCountsProvider = Provider<AsyncValue<Map<TransactionType, int>>>(
  (ref) {
    return ref.watch(transactionsProvider).whenData((transactions) {
      final counts = <TransactionType, int>{};
      for (final transaction in transactions) {
        counts[transaction.type] = (counts[transaction.type] ?? 0) + 1;
      }
      return counts;
    });
  },
);

/// Every write the Finance module can perform. Widgets call these; they never
/// touch a repository or the database directly.
class FinanceActions {
  FinanceActions(this._ref);

  final Ref _ref;

  AccountRepository get _accounts => _ref.read(accountRepositoryProvider);
  TransactionRepository get _transactions =>
      _ref.read(transactionRepositoryProvider);

  Future<Account> createAccount({
    required String name,
    required AccountType type,
    int initialBalance = 0,
    String? notes,
    bool isLiability = false,
  }) {
    return _accounts.create(
      name: name,
      type: type,
      initialBalance: initialBalance,
      notes: notes,
      isLiability: isLiability,
      currency: _ref.read(defaultCurrencyProvider),
    );
  }

  Future<void> updateAccount({
    required String id,
    required String name,
    required AccountType type,
    String? notes,
    bool? isLiability,
  }) {
    return _accounts.update(
      id,
      name: name,
      type: type,
      notes: notes,
      isLiability: isLiability,
      currency: _ref.read(defaultCurrencyProvider),
    );
  }

  Future<void> setAccountArchived(String id, bool archived) =>
      _accounts.setArchived(id, archived);

  Future<void> deleteAccount(String id) => _accounts.delete(id);

  Future<Transaction> createTransaction({
    required int amount,
    required TransactionType type,
    required String accountId,
    required String title,
    required DateTime date,
    String category = '',
    String? targetAccountId,
    String? notes,
  }) {
    return _transactions.create(
      amount: amount,
      type: type,
      accountId: accountId,
      targetAccountId: targetAccountId,
      title: title,
      category: category,
      date: date,
      notes: notes,
    );
  }

  Future<Transaction> updateTransaction({
    required String id,
    required int amount,
    required TransactionType type,
    required String accountId,
    required String title,
    required DateTime date,
    String category = '',
    String? targetAccountId,
    String? notes,
  }) {
    return _transactions.update(
      id,
      amount: amount,
      type: type,
      accountId: accountId,
      targetAccountId: targetAccountId,
      title: title,
      category: category,
      date: date,
      notes: notes,
    );
  }

  Future<void> deleteTransaction(String id) => _transactions.delete(id);
}

final financeActionsProvider = Provider<FinanceActions>(FinanceActions.new);

/// Default currency for new accounts, read from settings.
final defaultCurrencyProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider).value;
  return settings?[SettingsRepository.defaultCurrencyKey] ?? 'IDR';
});
