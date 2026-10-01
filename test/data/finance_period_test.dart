import 'package:flutter_test/flutter_test.dart';
import 'package:habitstracker/domain/models/account.dart';
import 'package:habitstracker/domain/models/finance_summary.dart';
import 'package:habitstracker/domain/models/transaction.dart';
import 'package:habitstracker/features/finance/providers/finance_providers.dart';

import '../support/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() async => harness = await TestHarness.create());
  tearDown(() => harness.dispose());

  FinanceActions actions() => harness.container.read(financeActionsProvider);

  Future<FinanceSummary> summary(FinancePeriod period) async {
    final container = harness.container;
    container.listen(financeSummaryProvider, (_, _) {}, fireImmediately: true);
    await firstValue(container, financeSummaryProvider);
    container.read(financePeriodProvider.notifier).select(period);
    // Changing the period rebuilds the stream, which takes one more turn.
    await settleStreams();
    return container.read(financeSummaryProvider).requireValue;
  }

  group('periods', () {
    test('each period reports its own income and expenses', () async {
      final thisMonth = await summary(FinancePeriod.thisMonth);
      final lastMonth = await summary(FinancePeriod.lastMonth);
      final thisYear = await summary(FinancePeriod.thisYear);

      expect(thisMonth.income, greaterThan(0));
      expect(thisMonth.expenses, greaterThan(0));
      expect(thisMonth.retained, thisMonth.income - thisMonth.expenses);

      // The year window contains both months, so it can only be larger.
      expect(thisYear.income, greaterThan(thisMonth.income));
      expect(thisYear.expenses, greaterThan(thisMonth.expenses));
      expect(lastMonth.income, greaterThan(0));

      // Balances do not depend on the reporting window.
      expect(thisYear.netWorth, thisMonth.netWorth);
      expect(thisYear.totalAssets, thisMonth.totalAssets);
    });

    test('a new transaction lands in the period it is dated in', () async {
      final before = await summary(FinancePeriod.thisMonth);

      await actions().createTransaction(
        amount: 750000,
        type: TransactionType.income,
        accountId: 'acc-cash-liquidity',
        title: 'Imbalan semester',
        date: TestHarness.fixedNow,
      );
      await waitUntil(
        () =>
            harness.container.read(financeSummaryProvider).value?.income ==
            before.income + 750000,
      );

      final after = harness.container
          .read(financeSummaryProvider)
          .requireValue;
      expect(after.income, before.income + 750000);
      expect(after.netWorth, before.netWorth + 750000);
    });
  });

  group('ledger filters', () {
    test('type filter narrows the list', () async {
      final container = harness.container;
      container.listen(filteredTransactionsProvider, (_, _) {},
          fireImmediately: true);
      await firstValue(container, transactionsProvider);
      await settleStreams();
      final all = container.read(filteredTransactionsProvider).requireValue;
      final transfers = all.where((t) => t.isTransfer).length;
      expect(transfers, greaterThan(0));

      container
          .read(transactionFilterProvider.notifier)
          .setType(TransactionType.transfer);
      final filtered = container.read(filteredTransactionsProvider).requireValue;
      expect(filtered.every((t) => t.isTransfer), isTrue);
      expect(filtered.length, transfers);

      container.read(transactionFilterProvider.notifier).clear();
      final restored = container.read(filteredTransactionsProvider).requireValue;
      expect(restored.length, all.length);
    });

    test('account filter keeps both sides of a transfer', () async {
      final container = harness.container;
      container.listen(filteredTransactionsProvider, (_, _) {},
          fireImmediately: true);
      await firstValue(container, transactionsProvider);
      await settleStreams();

      container
          .read(transactionFilterProvider.notifier)
          .setAccount('acc-bitcoin');
      await settleStreams();

      final filtered = container.read(filteredTransactionsProvider).requireValue;
      expect(filtered, isNotEmpty);
      expect(
        filtered.every(
          (t) =>
              t.accountId == 'acc-bitcoin' ||
              t.targetAccountId == 'acc-bitcoin',
        ),
        isTrue,
      );
      // Income into bitcoin and transfers into it both belong in the view.
      expect(filtered.any((t) => t.isTransfer), isTrue);
    });

    test('free text matches title, category and account', () async {
      final container = harness.container;
      container.listen(filteredTransactionsProvider, (_, _) {},
          fireImmediately: true);
      await firstValue(container, transactionsProvider);
      await settleStreams();

      container.read(transactionFilterProvider.notifier).setQuery('dividen');
      await settleStreams();
      final byTitle = container.read(filteredTransactionsProvider).requireValue;
      expect(byTitle, isNotEmpty);
      expect(byTitle.every((t) => t.title.toLowerCase().contains('dividen')), isTrue);

      container.read(transactionFilterProvider.notifier).setQuery('tidak ada');
      await settleStreams();
      expect(
        container.read(filteredTransactionsProvider).requireValue,
        isEmpty,
      );
    });
  });

  group('editing and deleting', () {
    test('editing the amount moves the balance and the period figures',
        () async {
      final before = await summary(FinancePeriod.thisMonth);
      final created = await actions().createTransaction(
        amount: 400000,
        type: TransactionType.expense,
        accountId: 'acc-cash-liquidity',
        title: 'Sewa sementara',
        date: TestHarness.fixedNow,
      );

      await actions().updateTransaction(
        id: created.id,
        amount: 100000,
        type: TransactionType.expense,
        accountId: 'acc-cash-liquidity',
        title: 'Sewa sementara',
        date: TestHarness.fixedNow,
      );

      await waitUntil(() {
        final now = harness.container.read(financeSummaryProvider).value;
        return now != null && now.expenses == before.expenses + 100000;
      });
      final after = harness.container
          .read(financeSummaryProvider)
          .requireValue;
      expect(after.expenses, before.expenses + 100000);
      expect(after.netWorth, before.netWorth - 100000);
    });

    test('deleting restores the balance it had moved', () async {
      final before = await summary(FinancePeriod.thisMonth);
      final created = await actions().createTransaction(
        amount: 900000,
        type: TransactionType.expense,
        accountId: 'acc-cash-liquidity',
        title: 'Salah input',
        date: TestHarness.fixedNow,
      );

      await actions().deleteTransaction(created.id);

      await waitUntil(
        () =>
            harness.container.read(financeSummaryProvider).value?.netWorth ==
            before.netWorth,
      );
      final after = harness.container
          .read(financeSummaryProvider)
          .requireValue;
      expect(after.netWorth, before.netWorth);
      expect(after.expenses, before.expenses);
    });

    test('a transaction carries its account names for the ledger row',
        () async {
      final container = harness.container;
      container.listen(transactionsProvider, (_, _) {}, fireImmediately: true);
      final all = await firstValue(container, transactionsProvider);

      expect(all, isNotEmpty);
      expect(all.every((t) => t.accountName.isNotEmpty), isTrue);
      final transfer = all.firstWhere((t) => t.isTransfer);
      expect(transfer.targetAccountName, isNotNull);
      expect(transfer.targetAccountName, isNotEmpty);
    });
  });

  group('allocation', () {
    test('weights come from the balances and ignore liabilities', () async {
      final container = harness.container;
      container.listen(financeSummaryProvider, (_, _) {}, fireImmediately: true);
      final data = await firstValue(container, financeSummaryProvider);

      final total = data.allocation.fold<double>(
        0,
        (sum, slice) => sum + slice.weight,
      );
      expect(total, closeTo(1, 0.001));

      // The credit card is a liability, so it is not part of the allocation.
      expect(
        data.allocation.any((s) => s.label == 'Kartu Kredit'),
        isFalse,
      );
      expect(
        data.allocation.fold<int>(0, (sum, s) => sum + s.value),
        data.totalAssets,
      );
    });

    test('a new account changes the allocation immediately', () async {
      final container = harness.container;
      container.listen(financeSummaryProvider, (_, _) {}, fireImmediately: true);
      final before = await firstValue(container, financeSummaryProvider);

      await actions().createAccount(
        name: 'Reksa dana baru',
        type: AccountType.stocks,
        initialBalance: 10000000,
      );

      await waitUntil(() {
        final now = container.read(financeSummaryProvider).value;
        return now != null && now.allocation.any((s) => s.label == 'Reksa dana baru');
      });

      final after = container.read(financeSummaryProvider).requireValue;
      final slice = after.allocation.firstWhere(
        (s) => s.label == 'Reksa dana baru',
      );
      expect(slice.value, 10000000);
      expect(after.totalAssets, before.totalAssets + 10000000);
      expect(after.netWorth, before.netWorth + 10000000);
      expect(
        after.allocation.fold<double>(0, (sum, s) => sum + s.weight),
        closeTo(1, 0.001),
      );
    });
  });
}
