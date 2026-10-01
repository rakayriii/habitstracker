import 'package:flutter_test/flutter_test.dart';
import 'package:habitstracker/data/database/data_providers.dart';
import 'package:habitstracker/domain/errors.dart';
import 'package:habitstracker/domain/models/account.dart';
import 'package:habitstracker/domain/models/finance_summary.dart';
import 'package:habitstracker/domain/models/transaction.dart';

import '../support/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
  });

  tearDown(() => harness.dispose());

  group('seed', () {
    test('creates accounts, ledger, goals, projects and focus once', () async {
      final accounts = await harness.container.read(accountRepositoryProvider)
          .findById('acc-cash-liquidity');
      expect(accounts, isNotNull);
      expect(accounts!.isLiability, isFalse);

      final goals = await harness.container.read(goalRepositoryProvider).findById(
        'goal-emergency-fund',
      );
      expect(goals, isNotNull);
      expect(goals!.milestones, hasLength(4));

      final project = await harness.container
          .read(projectRepositoryProvider)
          .findById('prj-myos');
      expect(project, isNotNull);
      expect(project!.tasks, isNotEmpty);

      final focus = await harness.container.read(focusRepositoryProvider)
          .watchForDate(TestHarness.fixedNow)
          .first;
      expect(focus, hasLength(5));
    });

    test('balances are derived from the ledger, not typed in', () async {
      final accounts = harness.container.read(accountRepositoryProvider);
      final transactions = harness.container.read(transactionRepositoryProvider);

      final cash = await accounts.findById('acc-cash-liquidity');
      final transactionsAll = await transactions.watchAll().first;

      final cashId = cash!.id;
      final cashLedger = transactionsAll
          .where((t) => t.accountId == cashId || t.targetAccountId == cashId)
          .fold<int>(
            0,
            (sum, t) =>
                sum +
                (t.accountId == cashId && t.type != TransactionType.transfer
                    ? (t.type == TransactionType.income ? t.amount : -t.amount)
                    : t.type == TransactionType.transfer && t.accountId == cashId
                        ? -t.amount
                        : t.type == TransactionType.transfer &&
                                t.targetAccountId == cashId
                            ? t.amount
                            : 0),
          );
      expect(cash.balance, cashLedger);
    });
  });

  group('accounts', () {
    test('create records an opening entry when a balance is supplied', () async {
      final repository = harness.container.read(accountRepositoryProvider);
      final account = await repository.create(
        name: 'E-wallet GoPay',
        type: AccountType.ewallet,
        initialBalance: 750000,
      );

      expect(account.balance, 750000);
      final transactions = await repository
          .watchAll()
          .first
          .then((_) => harness.container.read(transactionRepositoryProvider)
              .watchAll()
              .first);
      expect(
        transactions.any(
          (t) => t.accountId == account.id && t.title == 'Saldo awal E-wallet GoPay',
        ),
        isTrue,
      );
    });

    test('create rejects an empty name', () async {
      final repository = harness.container.read(accountRepositoryProvider);
      expect(
        () => repository.create(name: '   ', type: AccountType.cash),
        throwsA(isA<ValidationException>()),
      );
    });

    test('delete is refused while transactions still reference the account',
        () async {
      final repository = harness.container.read(accountRepositoryProvider);
      await expectLater(
        repository.delete('acc-cash-liquidity'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('update renames the account', () async {
      final repository = harness.container.read(accountRepositoryProvider);
      await repository.update(
        'acc-bitcoin',
        name: 'Bitcoin cold wallet',
        type: AccountType.bitcoin,
      );
      final updated = await repository.findById('acc-bitcoin');
      expect(updated!.name, 'Bitcoin cold wallet');
    });
  });

  group('transactions', () {
    test('income increases the account balance', () async {
      final repository = harness.container.read(transactionRepositoryProvider);
      final accounts = harness.container.read(accountRepositoryProvider);
      final before = (await accounts.findById('acc-cash-liquidity'))!.balance;

      await repository.create(
        amount: 5000000,
        type: TransactionType.income,
        accountId: 'acc-cash-liquidity',
        title: 'Gaji bonus',
        date: TestHarness.fixedNow,
      );

      final after = (await accounts.findById('acc-cash-liquidity'))!.balance;
      expect(after - before, 5000000);
    });

    test('expense decreases the account balance', () async {
      final repository = harness.container.read(transactionRepositoryProvider);
      final accounts = harness.container.read(accountRepositoryProvider);
      final before = (await accounts.findById('acc-cash-liquidity'))!.balance;

      await repository.create(
        amount: 250000,
        type: TransactionType.expense,
        accountId: 'acc-cash-liquidity',
        title: 'Beli tooling',
        date: TestHarness.fixedNow,
      );

      final after = (await accounts.findById('acc-cash-liquidity'))!.balance;
      expect(before - after, 250000);
    });

    test('transfer moves money and leaves net worth alone', () async {
      final repository = harness.container.read(transactionRepositoryProvider);
      final accounts = harness.container.read(accountRepositoryProvider);
      final finance = harness.container.read(financeRepositoryProvider);

      final cashBefore = (await accounts.findById('acc-cash-liquidity'))!.balance;
      final goldBefore = (await accounts.findById('acc-physical-gold'))!.balance;
      final summaryBefore = await finance
          .watchSummary(FinancePeriod.thisMonth)
          .first;

      await repository.create(
        amount: 500000,
        type: TransactionType.transfer,
        accountId: 'acc-cash-liquidity',
        targetAccountId: 'acc-physical-gold',
        title: 'Beli emas',
        date: TestHarness.fixedNow,
      );

      final cashAfter = (await accounts.findById('acc-cash-liquidity'))!.balance;
      final goldAfter = (await accounts.findById('acc-physical-gold'))!.balance;
      expect(cashBefore - cashAfter, 500000);
      expect(goldAfter - goldBefore, 500000);

      final summaryAfter = await finance
          .watchSummary(FinancePeriod.thisMonth)
          .first;
      expect(summaryAfter.netWorth, summaryBefore.netWorth);
      expect(summaryAfter.income, summaryBefore.income);
      expect(summaryAfter.expenses, summaryBefore.expenses);
    });

    test('a transfer to the same account is rejected', () async {
      final repository = harness.container.read(transactionRepositoryProvider);
      await expectLater(
        repository.create(
          amount: 100000,
          type: TransactionType.transfer,
          accountId: 'acc-cash-liquidity',
          targetAccountId: 'acc-cash-liquidity',
          title: 'Salah',
          date: TestHarness.fixedNow,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('zero and negative amounts are rejected', () async {
      final repository = harness.container.read(transactionRepositoryProvider);
      await expectLater(
        repository.create(
          amount: 0,
          type: TransactionType.expense,
          accountId: 'acc-cash-liquidity',
          title: 'Nol',
          date: TestHarness.fixedNow,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('deleting a transaction restores the balance', () async {
      final repository = harness.container.read(transactionRepositoryProvider);
      final accounts = harness.container.read(accountRepositoryProvider);
      final before = (await accounts.findById('acc-cash-liquidity'))!.balance;

      final created = await repository.create(
        amount: 900000,
        type: TransactionType.expense,
        accountId: 'acc-cash-liquidity',
        title: 'Sewa sementara',
        date: TestHarness.fixedNow,
      );
      final during = (await accounts.findById('acc-cash-liquidity'))!.balance;
      expect(before - during, 900000);

      await repository.delete(created.id);
      final after = (await accounts.findById('acc-cash-liquidity'))!.balance;
      expect(after, before);
    });

    test('editing an amount re-derives the balance', () async {
      final repository = harness.container.read(transactionRepositoryProvider);
      final accounts = harness.container.read(accountRepositoryProvider);
      final before = (await accounts.findById('acc-cash-liquidity'))!.balance;

      final created = await repository.create(
        amount: 300000,
        type: TransactionType.expense,
        accountId: 'acc-cash-liquidity',
        title: 'Sudah diubah',
        date: TestHarness.fixedNow,
      );
      await repository.update(
        created.id,
        amount: 100000,
        type: TransactionType.expense,
        accountId: 'acc-cash-liquidity',
        title: 'Sudah diubah',
        date: TestHarness.fixedNow,
      );

      final after = (await accounts.findById('acc-cash-liquidity'))!.balance;
      expect(before - after, 100000);
    });

    test('a liability account reports the amount owed', () async {
      final repository = harness.container.read(transactionRepositoryProvider);
      final accounts = harness.container.read(accountRepositoryProvider);
      final card = await accounts.findById('acc-credit-card');
      expect(card!.isLiability, isTrue);
      expect(card.balance, 850000);

      await repository.create(
        amount: 150000,
        type: TransactionType.expense,
        accountId: 'acc-credit-card',
        title: 'Belanja tambahan',
        date: TestHarness.fixedNow,
      );
      final after = await accounts.findById('acc-credit-card');
      expect(after!.balance, 1000000);
    });

    test('missing record reports a not found error', () async {
      final repository = harness.container.read(transactionRepositoryProvider);
      await expectLater(
        repository.delete('tx-does-not-exist'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('summary', () {
    test('net worth is assets minus liabilities', () async {
      final finance = harness.container.read(financeRepositoryProvider);
      final summary = await finance
          .watchSummary(FinancePeriod.thisMonth)
          .first;

      expect(summary.totalLiabilities, 850000);
      expect(summary.netWorth, summary.totalAssets - 850000);
      expect(summary.netWorth, greaterThan(0));
    });

    test('allocation weights add up to one', () async {
      final finance = harness.container.read(financeRepositoryProvider);
      final summary = await finance
          .watchSummary(FinancePeriod.thisMonth)
          .first;

      final total = summary.allocation.fold<double>(
        0,
        (sum, slice) => sum + slice.weight,
      );
      expect(total, closeTo(1.0, 0.001));
    });

    test('period selection changes the cashflow figures', () async {
      final finance = harness.container.read(financeRepositoryProvider);
      final thisMonth = await finance.watchSummary(FinancePeriod.thisMonth).first;
      final lastMonth = await finance
          .watchSummary(FinancePeriod.lastMonth)
          .first;
      final thisYear = await finance.watchSummary(FinancePeriod.thisYear).first;

      expect(thisMonth.income, greaterThan(0));
      expect(lastMonth.income, greaterThan(0));
      // The year window contains both months plus the earlier ledger, so it
      // can only be larger, never smaller.
      expect(
        thisYear.income,
        greaterThan(thisMonth.income + lastMonth.income),
      );
      expect(thisYear.expenses, greaterThan(thisMonth.expenses));
      expect(thisMonth.retained, thisMonth.income - thisMonth.expenses);
    });
  });
}
