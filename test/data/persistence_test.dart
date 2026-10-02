import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitstracker/data/database/app_database.dart';
import 'package:habitstracker/data/database/data_providers.dart';
import 'package:habitstracker/domain/models/account.dart';
import 'package:habitstracker/domain/models/goal.dart';
import 'package:habitstracker/domain/models/transaction.dart';
import 'package:habitstracker/features/finance/providers/finance_providers.dart';
import 'package:habitstracker/features/focus/providers/focus_providers.dart';
import 'package:habitstracker/features/goals/providers/goal_providers.dart';
import 'package:habitstracker/features/projects/providers/project_providers.dart';

import '../support/test_harness.dart';

void main() {
  group('persistence', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('myos_persistence');
      file = File('${dir.path}/myos.sqlite');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    ProviderContainer containerFor(AppDatabase database) {
      return ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(() => TestHarness.fixedNow),
        ],
      );
    }

    test('writes survive closing and reopening the file', () async {
      // First launch: seed, then add a row the seed never knew about.
      final first = AppDatabase.forTesting(NativeDatabase(file));
      final firstContainer = containerFor(first);
      await first.select(first.accounts).get();

      await firstContainer.read(accountRepositoryProvider).create(
        name: 'E-wallet GoPay',
        type: AccountType.ewallet,
        initialBalance: 375000,
      );
      // Same reason as the harness: a summary built from two tables can emit
      // once per table, so the baseline is read after the notifications drain.
      await firstValue(firstContainer, financeSummaryProvider);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final before = firstContainer.read(financeSummaryProvider).requireValue;

      await firstContainer.read(transactionRepositoryProvider).create(
        amount: 125000,
        type: TransactionType.expense,
        accountId: 'acc-cash-liquidity',
        title: 'Makan siang',
        date: TestHarness.fixedNow,
      );
      await firstContainer.read(goalRepositoryProvider).create(
        title: 'Ganti laptop',
        category: GoalCategory.system,
        targetValue: 15000000,
      );
      final accountsBefore = await firstContainer
          .read(accountRepositoryProvider)
          .watchAll()
          .first;

      firstContainer.dispose();
      await first.close();

      // Second launch: the same file, as if the app had been restarted.
      final second = AppDatabase.forTesting(NativeDatabase(file));
      final secondContainer = containerFor(second);
      await second.select(second.accounts).get();

      final accountsAfter = await secondContainer
          .read(accountRepositoryProvider)
          .watchAll()
          .first;
      expect(
        accountsAfter.map((a) => a.name),
        containsAll(accountsBefore.map((a) => a.name)),
        reason: 'accounts survive a restart',
      );

      final transactions = await secondContainer
          .read(transactionRepositoryProvider)
          .watchAll()
          .first;
      expect(
        transactions.any((t) => t.title == 'Makan siang'),
        isTrue,
        reason: 'transactions survive a restart',
      );

      final goals = await firstValue(secondContainer, goalsProvider);
      expect(goals.any((g) => g.title == 'Ganti laptop'), isTrue);

      await firstValue(secondContainer, financeSummaryProvider);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final reopened = secondContainer
          .read(financeSummaryProvider)
          .requireValue;

      // The reopened ledger carries the same rows, so the balance follows the
      // same arithmetic: one more expense of 125.000 and 125.000 less net
      // worth.
      expect(reopened.netWorth, before.netWorth - 125000);
      expect(reopened.expenses, before.expenses + 125000);
      expect(reopened.income, before.income);

      secondContainer.dispose();
      await second.close();
    });

    test('a balance correction is not repeated after a restart', () async {
      final first = AppDatabase.forTesting(NativeDatabase(file));
      final firstContainer = containerFor(first);
      await first.select(first.accounts).get();

      final account =
          await firstContainer.read(accountRepositoryProvider).create(
        name: 'BCA',
        type: AccountType.bank,
        initialBalance: 2000000,
      );
      await firstContainer.read(accountRepositoryProvider).update(
        account.id,
        name: 'BCA',
        type: AccountType.bank,
        balance: 5000000,
      );

      firstContainer.dispose();
      await first.close();

      // Second launch: the same file, as if the app had been restarted.
      final second = AppDatabase.forTesting(NativeDatabase(file));
      final secondContainer = containerFor(second);
      await second.select(second.accounts).get();

      final accounts = secondContainer.read(accountRepositoryProvider);
      expect((await accounts.findById(account.id))!.balance, 5000000);

      final entries = (await secondContainer
              .read(transactionRepositoryProvider)
              .watchAll()
              .first)
          .where((t) => t.accountId == account.id)
          .toList();
      expect(
        entries.where((t) => t.title.startsWith('Penyesuaian saldo')),
        hasLength(1),
        reason: 'the adjustment is a row, not a recomputed figure',
      );
      expect(entries, hasLength(2), reason: 'opening plus one adjustment');

      // Opening the form again and saving without touching it must not add a
      // second adjustment, which is the same code path the app runs on resume.
      await accounts.update(
        account.id,
        name: 'BCA',
        type: AccountType.bank,
        balance: 5000000,
      );
      final afterResave = (await secondContainer
              .read(transactionRepositoryProvider)
              .watchAll()
              .first)
          .where((t) => t.accountId == account.id)
          .toList();
      expect(afterResave, hasLength(2));
      expect((await accounts.findById(account.id))!.balance, 5000000);

      secondContainer.dispose();
      await second.close();
    });

    test('the seed does not come back after the user deletes it', () async {
      final first = AppDatabase.forTesting(NativeDatabase(file));
      final firstContainer = containerFor(first);
      await first.select(first.accounts).get();

      await firstContainer
          .read(goalRepositoryProvider)
          .delete('goal-emergency-fund');
      firstContainer.dispose();
      await first.close();

      final second = AppDatabase.forTesting(NativeDatabase(file));
      final secondContainer = containerFor(second);
      await second.select(second.accounts).get();

      final goals = await firstValue(secondContainer, goalsProvider);
      expect(goals.any((g) => g.id == 'goal-emergency-fund'), isFalse);
      expect(goals, isNotEmpty, reason: 'the rest of the seed is untouched');

      secondContainer.dispose();
      await second.close();
    });

    test('the migration hook is in place for future versions', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      expect(database.schemaVersion, 1);
      final strategy = database.migration;
      expect(strategy.onCreate, isNotNull);
      expect(strategy.beforeOpen, isNotNull);
      // Nothing destructive is registered today.
      expect(strategy.onUpgrade, isNotNull);
      await database.close();
    });
  });

  group('cross module', () {
    late TestHarness harness;

    setUp(() async => harness = await TestHarness.create());
    tearDown(() => harness.dispose());

    test('a transaction in finance moves the number on home', () async {
      final container = harness.container;
      container.listen(financeSummaryProvider, (_, _) {}, fireImmediately: true);
      container.listen(homeGoalsProvider, (_, _) {}, fireImmediately: true);
      container.listen(homeProjectsProvider, (_, _) {}, fireImmediately: true);

      await firstValue(container, financeSummaryProvider);
      final before = container.read(financeSummaryProvider).requireValue;

      await container.read(financeActionsProvider).createTransaction(
        amount: 2500000,
        type: TransactionType.income,
        accountId: 'acc-cash-liquidity',
        title: 'Pemasukan baru',
        date: TestHarness.fixedNow,
      );

      // The summary is assembled from two tables, and drift notifies them one
      // after the other, so the wait is for the whole figure to be consistent
      // rather than for the first field to move.
      await waitUntil(() {
        final now = container.read(financeSummaryProvider).value;
        return now != null && now.income == before.income + 2500000;
      });

      final after = container.read(financeSummaryProvider).requireValue;
      // Home reads the same summary, so there is nothing else to update.
      expect(after.netWorth, before.netWorth + 2500000);
      expect(after.income, before.income + 2500000);
    });

    test('a goal edit moves the progress on home', () async {
      final container = harness.container;
      container.listen(homeGoalsProvider, (_, _) {}, fireImmediately: true);
      await container.read(goalsProvider.future);

      final railBefore = container.read(homeGoalsProvider).requireValue;
      final goal = railBefore.firstWhere((g) => g.id == 'goal-5k-run');
      final progressBefore = goal.progress;

      await container
          .read(goalActionsProvider)
          .setProgress('goal-5k-run', goal.currentValue + 3);

      await waitUntil(() {
        final rail = container.read(homeGoalsProvider).value;
        final updated = rail?.where((g) => g.id == 'goal-5k-run').firstOrNull;
        return updated != null && updated.progress != progressBefore;
      });

      final railAfter = container.read(homeGoalsProvider).requireValue;
      final updated = railAfter.firstWhere((g) => g.id == 'goal-5k-run');
      expect(updated.progress, greaterThan(progressBefore));
      expect(updated.currentValue, goal.currentValue + 3);
    });

    test('completing tasks moves the project progress on home', () async {
      final container = harness.container;
      container.listen(homeProjectsProvider, (_, _) {}, fireImmediately: true);
      await container.read(projectsProvider.future);

      final railBefore = container.read(homeProjectsProvider).requireValue;
      final myos = railBefore.firstWhere((p) => p.id == 'prj-myos');
      final before = myos.progress;

      final open = myos.tasks.where((t) => !t.isCompleted).toList();
      for (final task in open.take(2)) {
        await container
            .read(projectActionsProvider)
            .setTaskCompleted(task.id, true);
      }

      await waitUntil(() {
        final rail = container.read(homeProjectsProvider).value;
        final updated = rail?.where((p) => p.id == 'prj-myos').firstOrNull;
        return updated != null && updated.progress > before;
      });

      final updated = container
          .read(homeProjectsProvider)
          .requireValue
          .firstWhere((p) => p.id == 'prj-myos');
      expect(updated.completedTasks, myos.completedTasks + 2);
      expect(updated.progress, greaterThan(before));
    });

    test('deleting a project removes it from the home rail', () async {
      final container = harness.container;
      container.listen(homeProjectsProvider, (_, _) {}, fireImmediately: true);
      await firstValue(container, projectsProvider);
      expect(
        container.read(homeProjectsProvider).requireValue.length,
        greaterThan(0),
      );

      await container.read(projectActionsProvider).delete('prj-mediavault');
      await container.read(projectActionsProvider).delete('prj-nexus-core');

      await waitUntil(() {
        final rail = container.read(homeProjectsProvider).value;
        return rail != null &&
            !rail.any((p) => p.id == 'prj-mediavault') &&
            !rail.any((p) => p.id == 'prj-nexus-core');
      });

      final rail = container.read(homeProjectsProvider).requireValue;
      expect(rail.any((p) => p.id == 'prj-mediavault'), isFalse);
      expect(rail.any((p) => p.id == 'prj-nexus-core'), isFalse);
    });

    test('a focus toggle reaches the home counter', () async {
      final container = harness.container;
      container.listen(focusCountsProvider, (_, _) {}, fireImmediately: true);
      await firstValue(container, todayFocusProvider);

      final before = container.read(focusCountsProvider);
      final open = (await container
              .read(focusRepositoryProvider)
              .watchForDate(container.read(todayProvider))
              .first)
          .where((item) => !item.isCompleted)
          .first;

      await container.read(focusActionsProvider).setCompleted(open.id, true);
      await waitUntil(
        () => container.read(focusCountsProvider).done == before.done + 1,
      );

      expect(container.read(focusCountsProvider).done, before.done + 1);
    });
  });
}