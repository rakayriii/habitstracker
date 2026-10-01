import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/account_repository.dart';
import '../repositories/finance_repository.dart';
import '../repositories/focus_repository.dart';
import '../repositories/goal_repository.dart';
import '../repositories/project_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/transaction_repository.dart';
import 'app_database.dart';

/// The clock every repository reads, injected rather than called directly so
/// tests can pin "now" and assert on periods, pace and ageing.
typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);

/// Single database instance for the app. Tests override this with
/// `AppDatabase.forTesting(NativeDatabase.memory())`, which is the only place
/// the connection is chosen.
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(databaseProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(databaseProvider)),
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepository(ref.watch(databaseProvider)),
);

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(databaseProvider)),
);

final focusRepositoryProvider = Provider<FocusRepository>(
  (ref) => FocusRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(
    accounts: ref.watch(accountRepositoryProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    now: ref.watch(clockProvider),
  ),
);

/// Application settings, shared by the header and the settings sheet.
final settingsProvider = StreamProvider<Map<String, String>>(
  (ref) => ref.watch(settingsRepositoryProvider).watchAll(),
);
