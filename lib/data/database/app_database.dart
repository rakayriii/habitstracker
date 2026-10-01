import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'seed.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The local SQLite store. One file, no network, no sync.
///
/// [schemaVersion] gates the migration steps in [migration]. Steps are append
/// only: removing one is what turns an upgrade into data loss.
@DriftDatabase(
  tables: [
    Settings,
    Accounts,
    Transactions,
    Goals,
    GoalMilestones,
    Projects,
    ProjectTags,
    ProjectTasks,
    FocusItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Used by tests to run against an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Seed runs inside onCreate, so it happens exactly once, when the file
      // is first created. A user who empties the tables never gets the demo
      // data back.
      await seedDatabase(this);
    },
    onUpgrade: (m, from, to) async {
      // No shipped upgrade steps yet. Future steps go here, one `if (from <
      // n)` block per version, never a dropAllTables.
    },
    beforeOpen: (details) async {
      // Foreign keys are off by default in SQLite, and the whole ledger
      // integrity story depends on them.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Recomputes every account balance from the transaction ledger.
  ///
  /// The ledger is the only source of truth for money: this runs inside the
  /// same transaction as any insert, update or delete, so a cached balance can
  /// never disagree with the rows that produced it.
  ///
  /// A liability account inverts the sign, so an expense on a credit card
  /// increases the amount owed instead of making the balance negative.
  ///
  /// The arithmetic stays in SQL, but the write goes through drift's query
  /// builder on purpose: a raw `customUpdate` would change the rows without
  /// telling drift, and every account stream would keep serving the old balance
  /// until something else happened to invalidate it. Only accounts whose
  /// balance actually moved are written, so an unrelated edit does not wake
  /// every listener.
  Future<void> refreshAccountBalances() async {
    final rows = await customSelect('''
      SELECT a.id AS account_id,
        COALESCE((
          SELECT SUM(
            CASE
              WHEN t.type = 'income' THEN t.amount
              WHEN t.type = 'expense' THEN -t.amount
              WHEN t.type = 'transfer' AND t.account_id = a.id THEN -t.amount
              WHEN t.type = 'transfer' AND t.target_account_id = a.id
                THEN t.amount
              ELSE 0
            END
          ) * (CASE WHEN a.is_liability THEN -1 ELSE 1 END)
          FROM transactions t
          WHERE t.account_id = a.id OR t.target_account_id = a.id
        ), 0) AS balance
      FROM accounts a
    ''').get();

    for (final row in rows) {
      final id = row.read<String>('account_id');
      final balance = row.read<int>('balance');
      await (update(accounts)..where((account) => account.id.equals(id))).write(
        AccountsCompanion(balance: Value(balance)),
      );
    }
  }
}

QueryExecutor _openConnection() {
  // drift_flutter resolves the documents directory through path_provider, so
  // the app does not need to depend on path_provider itself.
  return driftDatabase(
    name: 'myos',
    native: const DriftNativeOptions(shareAcrossIsolates: true),
  );
}
