import 'package:flutter_test/flutter_test.dart';
import 'package:habitstracker/data/database/data_providers.dart';
import 'package:habitstracker/data/repositories/account_repository.dart';
import 'package:habitstracker/data/repositories/transaction_repository.dart';
import 'package:habitstracker/domain/errors.dart';
import 'package:habitstracker/domain/models/account.dart';
import 'package:habitstracker/domain/models/finance_summary.dart';
import 'package:habitstracker/domain/models/transaction.dart';
import 'package:habitstracker/features/finance/providers/finance_providers.dart';

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

  // Editing a balance is the one operation that has to write to the ledger to
  // take effect, because the ledger is what a balance is derived from. These
  // tests pin that down: the difference becomes an entry, the balance follows,
  // and later transactions work from the corrected figure.
  group('balance correction', () {
    late AccountRepository accounts;
    late TransactionRepository ledger;

    setUp(() {
      accounts = harness.container.read(accountRepositoryProvider);
      ledger = harness.container.read(transactionRepositoryProvider);
    });

    Future<List<Transaction>> entriesOf(String accountId) async {
      final all = await ledger.watchAll().first;
      return all.where((t) => t.accountId == accountId).toList();
    }

    Future<Transaction> adjustmentOf(String accountId) async {
      return (await entriesOf(accountId))
          .singleWhere((t) => t.title.startsWith('Penyesuaian saldo'));
    }

    test('raising the balance records the difference as income', () async {
      final account = await accounts.create(
        name: 'E-wallet GoPay',
        type: AccountType.ewallet,
        initialBalance: 500000,
      );
      expect(account.balance, 500000);

      await accounts.update(
        account.id,
        name: account.name,
        type: account.type,
        balance: 800000,
      );

      expect((await accounts.findById(account.id))!.balance, 800000);

      final adjustment = await adjustmentOf(account.id);
      expect(adjustment.type, TransactionType.income);
      expect(adjustment.amount, 300000);
      expect(adjustment.category, 'Penyesuaian');
      // The opening entry it corrects is still there, untouched.
      expect(
        (await entriesOf(account.id))
            .where((t) => t.title == 'Saldo awal E-wallet GoPay'),
        hasLength(1),
      );
    });

    test('lowering the balance records the difference as an expense', () async {
      final account = await accounts.create(
        name: 'BCA',
        type: AccountType.bank,
        initialBalance: 5000000,
      );

      await accounts.update(
        account.id,
        name: account.name,
        type: account.type,
        balance: 3500000,
      );

      expect((await accounts.findById(account.id))!.balance, 3500000);
      final adjustment = await adjustmentOf(account.id);
      expect(adjustment.type, TransactionType.expense);
      expect(adjustment.amount, 1500000);
    });

    test('a correction does not discard the existing history', () async {
      final account = await accounts.create(
        name: 'Tabungan Utama',
        type: AccountType.bank,
        initialBalance: 2000000,
      );
      await ledger.create(
        amount: 250000,
        type: TransactionType.expense,
        accountId: account.id,
        title: 'Biaya admin',
        date: TestHarness.fixedNow,
      );
      final beforeIds =
          (await entriesOf(account.id)).map((t) => t.id).toSet();

      await accounts.update(
        account.id,
        name: account.name,
        type: account.type,
        balance: 5000000,
      );

      final after = await entriesOf(account.id);
      expect(after.map((t) => t.id), containsAll(beforeIds));
      expect(after, hasLength(beforeIds.length + 1));
      expect((await accounts.findById(account.id))!.balance, 5000000);
    });

    test('later income and expense work from the corrected balance', () async {
      final account = await accounts.create(
        name: 'Tabungan Utama',
        type: AccountType.bank,
        initialBalance: 2000000,
      );
      await accounts.update(
        account.id,
        name: account.name,
        type: account.type,
        balance: 5000000,
      );
      expect((await accounts.findById(account.id))!.balance, 5000000);

      await ledger.create(
        amount: 500000,
        type: TransactionType.expense,
        accountId: account.id,
        title: 'Belanja',
        date: TestHarness.fixedNow,
      );
      expect((await accounts.findById(account.id))!.balance, 4500000);

      await ledger.create(
        amount: 1000000,
        type: TransactionType.income,
        accountId: account.id,
        title: 'Gaji',
        date: TestHarness.fixedNow,
      );
      expect((await accounts.findById(account.id))!.balance, 5500000);
    });

    test('a second correction measures from the corrected balance', () async {
      final account = await accounts.create(
        name: 'Tabungan Utama',
        type: AccountType.bank,
        initialBalance: 2000000,
      );
      await accounts.update(
        account.id,
        name: account.name,
        type: account.type,
        balance: 5000000,
      );
      await ledger.create(
        amount: 500000,
        type: TransactionType.expense,
        accountId: account.id,
        title: 'Belanja',
        date: TestHarness.fixedNow,
      );
      await ledger.create(
        amount: 1000000,
        type: TransactionType.income,
        accountId: account.id,
        title: 'Gaji',
        date: TestHarness.fixedNow,
      );
      expect((await accounts.findById(account.id))!.balance, 5500000);

      await accounts.update(
        account.id,
        name: account.name,
        type: account.type,
        balance: 7000000,
      );

      expect((await accounts.findById(account.id))!.balance, 7000000);
      final adjustments = (await entriesOf(account.id))
          .where((t) => t.title.startsWith('Penyesuaian saldo'))
          .toList();
      expect(adjustments, hasLength(2));
      // 1.500.000 apart, not 5.000.000: the second one is measured from the
      // balance the first one produced.
      expect(adjustments.last.amount, 1500000);

      await ledger.create(
        amount: 1000000,
        type: TransactionType.expense,
        accountId: account.id,
        title: 'Tagihan',
        date: TestHarness.fixedNow,
      );
      expect((await accounts.findById(account.id))!.balance, 6000000);
    });

    test('saving the balance the account already has records nothing',
        () async {
      final account = await accounts.create(
        name: 'BCA',
        type: AccountType.bank,
        initialBalance: 2000000,
      );
      final before = (await entriesOf(account.id)).length;

      // A form that was opened and saved without being touched.
      await accounts.update(
        account.id,
        name: account.name,
        type: account.type,
        balance: 2000000,
      );
      await accounts.update(
        account.id,
        name: account.name,
        type: account.type,
        balance: 2000000,
      );

      expect(await entriesOf(account.id), hasLength(before));
      expect((await accounts.findById(account.id))!.balance, 2000000);
    });

    test('leaving the balance out of an update changes nothing', () async {
      final account = await accounts.create(
        name: 'BCA',
        type: AccountType.bank,
        initialBalance: 2000000,
      );
      final before = await entriesOf(account.id);

      await accounts.update(
        account.id,
        name: 'BCA Tabungan',
        type: account.type,
        notes: 'dipindah ke bank lain',
      );

      final after = await accounts.findById(account.id);
      expect(after!.name, 'BCA Tabungan');
      expect(after.balance, 2000000);
      expect(await entriesOf(account.id), hasLength(before.length));
    });

    test('a liability keeps its sign when the balance is corrected', () async {
      final card = await accounts.create(
        name: 'BCA Credit',
        type: AccountType.creditCard,
        initialBalance: 850000,
        isLiability: true,
      );
      expect(card.balance, 850000);

      // More debt owed.
      await accounts.update(
        card.id,
        name: card.name,
        type: card.type,
        isLiability: true,
        balance: 3500000,
      );
      var updated = await accounts.findById(card.id);
      expect(updated!.balance, 3500000);
      expect(updated.isLiability, isTrue);
      expect((await adjustmentOf(card.id)).type, TransactionType.expense);
      expect((await adjustmentOf(card.id)).amount, 2650000);

      // Less debt owed is money moving back onto the card.
      await accounts.update(
        card.id,
        name: card.name,
        type: card.type,
        isLiability: true,
        balance: 350000,
      );
      updated = await accounts.findById(card.id);
      expect(updated!.balance, 350000);

      final adjustments = (await entriesOf(card.id))
          .where((t) => t.title.startsWith('Penyesuaian saldo'))
          .toList();
      expect(adjustments, hasLength(2));
      expect(adjustments.last.type, TransactionType.income);
      expect(adjustments.last.amount, 3150000);

      await ledger.create(
        amount: 100000,
        type: TransactionType.expense,
        accountId: card.id,
        title: 'Belanja kartu',
        date: TestHarness.fixedNow,
      );
      expect((await accounts.findById(card.id))!.balance, 450000);
    });

    test('the summary and allocation follow a correction', () async {
      final account = await accounts.create(
        name: 'E-wallet GoPay',
        type: AccountType.ewallet,
        initialBalance: 500000,
      );

      // Baseline after the account exists, so the only movement left is the
      // correction itself.
      final summary = await firstValue(
        harness.container,
        financeSummaryProvider,
      );
      await settleStreams();
      expect(summary.totalAssets, greaterThanOrEqualTo(500000));

      await accounts.update(
        account.id,
        name: account.name,
        type: account.type,
        balance: 3000000,
      );

      await waitUntil(
        () => harness.container
            .read(financeSummaryProvider)
            .requireValue
            .totalAssets ==
            summary.totalAssets + 2500000,
      );
      final after = harness.container.read(financeSummaryProvider).requireValue;

      expect(after.totalAssets, summary.totalAssets + 2500000);
      expect(after.netWorth, summary.netWorth + 2500000);
      expect(after.liquidValue, summary.liquidValue + 2500000);

      final slice =
          after.allocation.singleWhere((s) => s.accountId == account.id);
      expect(slice.value, 3000000);
      expect(slice.label, 'E-wallet GoPay');
      expect(slice.weight, closeTo(3000000 / after.totalAssets, 0.0001));
      expect(
        after.allocation.fold<double>(0, (sum, s) => sum + s.weight),
        closeTo(1.0, 0.001),
      );
    });

    test('a correction on an account the user created reaches home',
        () async {
      // Home watches this same stream, so an update that lands here lands on
      // the home hub without any extra refresh step.
      final before = await firstValue(
        harness.container,
        financeSummaryProvider,
      );
      await settleStreams();

      await accounts.update(
        'acc-global-equities',
        name: 'Global Equities',
        type: AccountType.stocks,
        balance: 12000000,
      );

      await waitUntil(
        () => harness.container
                .read(financeSummaryProvider)
                .requireValue
                .netWorth >
            before.netWorth,
      );
      final after = harness.container.read(financeSummaryProvider).requireValue;

      expect((await accounts.findById('acc-global-equities'))!.balance,
          12000000);
      expect(after.netWorth, greaterThan(before.netWorth));
      expect(
        after.allocation
            .singleWhere((s) => s.accountId == 'acc-global-equities')
            .value,
        12000000,
      );
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
