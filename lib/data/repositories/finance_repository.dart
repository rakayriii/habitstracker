import '../../core/utils/stream_utils.dart';
import '../../domain/models/account.dart';
import '../../domain/models/finance_summary.dart';
import '../../domain/models/transaction.dart';
import '../../domain/services/finance_calculator.dart';
import 'account_repository.dart';
import 'transaction_repository.dart';

/// Read model for the finance dashboard.
///
/// It joins the account list and the ledger and hands the UI one computed
/// [FinanceSummary]. Home reads the same stream, which is why a transaction
/// added on the Finance screen moves the number on Home without either screen
/// knowing about the other.
class FinanceRepository {
  FinanceRepository({
    required AccountRepository accounts,
    required TransactionRepository transactions,
    required DateTime Function() now,
  }) : _accounts = accounts,
       _transactions = transactions,
       _now = now;

  final AccountRepository _accounts;
  final TransactionRepository _transactions;
  final DateTime Function() _now;

  Stream<FinanceSummary> watchSummary(FinancePeriod period) {
    return combineLatest2(
      _accounts.watchAll(includeArchived: true),
      _transactions.watchAll(),
      (accounts, transactions) => FinanceCalculator.summarise(
        accounts: accounts,
        transactions: transactions,
        period: period,
        now: _now(),
      ),
    );
  }

  /// Accounts with a balance, ordered the way the ledger screen lists them.
  Stream<List<Account>> watchAccounts() => _accounts.watchAll();

  Stream<Account?> watchAccount(String id) => _accounts.watchById(id);

  Stream<List<Transaction>> watchTransactions() => _transactions.watchAll();
}
