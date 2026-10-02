import 'package:drift/drift.dart';

import '../../core/utils/id.dart';
import '../../domain/errors.dart';
import '../../domain/models/account.dart';
import '../database/app_database.dart';

/// Accounts and assets.
///
/// Balances are never written straight into the account row by a caller. They
/// are derived from the ledger, so the only way to change one is to record a
/// transaction, which keeps the ledger and the balance in agreement by
/// construction. [update] takes a target balance and turns the difference into
/// such a transaction rather than storing the number.
class AccountRepository {
  AccountRepository(this._db);

  final AppDatabase _db;

  static Account _map(AccountRow row) {
    return Account(
      id: row.id,
      name: row.name,
      type: AccountType.values.firstWhere(
        (type) => type.name == row.type,
        orElse: () => AccountType.other,
      ),
      balance: row.balance,
      currency: row.currency,
      notes: row.notes,
      isLiability: row.isLiability,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Stream<List<Account>> watchAll({bool includeArchived = false}) {
    final query = _db.select(_db.accounts)
      ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]);
    if (!includeArchived) {
      query.where((row) => row.isArchived.equals(false));
    }
    return query.watch().map(
      (rows) => rows.map(_map).toList(growable: false),
    );
  }

  Stream<Account?> watchById(String id) {
    final query = _db.select(_db.accounts)..where((row) => row.id.equals(id));
    return query.watchSingleOrNull().map((row) => row == null ? null : _map(row));
  }

  Future<Account?> findById(String id) async {
    final row = await (_db.select(_db.accounts)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<int> nextSortOrder() async {
    final max = _db.accounts.sortOrder.max();
    final query = _db.selectOnly(_db.accounts)..addColumns([max]);
    final row = await query.getSingle();
    return (row.read(max) ?? 0) + 1;
  }

  /// Creates an account. A non zero [initialBalance] is recorded as an opening
  /// entry in the ledger rather than written straight into the balance, so the
  /// starting money is explainable and the net worth history includes it.
  Future<Account> create({
    required String name,
    required AccountType type,
    int initialBalance = 0,
    String currency = 'IDR',
    String? notes,
    bool isLiability = false,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Nama akun wajib diisi', field: 'name');
    }
    final now = DateTime.now();
    final id = IdGen.next('acc');
    final order = await nextSortOrder();

    await _db.transaction(() async {
      await _db.into(_db.accounts).insert(
        AccountsCompanion.insert(
          id: id,
          name: trimmed,
          type: type.name,
          currency: Value(currency),
          notes: Value(_nullIfEmpty(notes)),
          isLiability: Value(isLiability),
          sortOrder: Value(order),
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (initialBalance != 0) {
        final amount = initialBalance.abs();
        final openingIsIncome = isLiability ? initialBalance < 0 : initialBalance > 0;
        await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            id: IdGen.next('tx'),
            accountId: id,
            amount: amount,
            type: (openingIsIncome
                    ? TransactionTypeName.income
                    : TransactionTypeName.expense),
            title: 'Saldo awal $trimmed',
            category: const Value('Saldo awal'),
            date: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await _db.refreshAccountBalances();
    });

    final created = await findById(id);
    if (created == null) throw const StorageException('Akun gagal disimpan');
    return created;
  }

  /// Updates an account's own fields, and optionally its balance.
  ///
  /// When [balance] is given it is the balance the account should end up with,
  /// not a value to store. The difference between it and the balance the
  /// ledger currently implies is recorded as an adjustment transaction, so the
  /// requested figure and the ledger agree without the ledger being rewritten.
  /// A target that matches the current balance records nothing, which is what
  /// keeps a repeated save, a rebuild or a restart from stacking adjustments.
  ///
  /// The fields, the adjustment and the refreshed balance all happen in one
  /// transaction: either the account ends up at the requested balance with an
  /// entry that explains it, or nothing changes.
  Future<void> update(
    String id, {
    required String name,
    required AccountType type,
    String currency = 'IDR',
    String? notes,
    bool? isLiability,
    int? balance,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Nama akun wajib diisi', field: 'name');
    }
    final existing = await findById(id);
    if (existing == null) {
      throw NotFoundException('Akun $id tidak ditemukan');
    }
    final now = DateTime.now();
    // The adjustment has to speak the sign of the account as it will be after
    // this save, not as it is now: flipping the liability switch inverts the
    // way the ledger is read into a balance.
    final liability = isLiability ?? existing.isLiability;

    await _db.transaction(() async {
      final changed = await (_db.update(_db.accounts)
            ..where((r) => r.id.equals(id)))
          .write(
        AccountsCompanion(
          name: Value(trimmed),
          type: Value(type.name),
          currency: Value(currency),
          notes: Value(_nullIfEmpty(notes)),
          isLiability:
              isLiability == null ? const Value.absent() : Value(isLiability),
          updatedAt: Value(now),
        ),
      );
      if (changed == 0) throw NotFoundException('Akun $id tidak ditemukan');

      if (balance != null) {
        // The liability switch may have just changed the sign the balance is
        // read with, so re-derive before comparing against the target.
        await _db.refreshAccountBalances();
        final row = await (_db.select(_db.accounts)
              ..where((r) => r.id.equals(id)))
            .getSingle();
        // A liability reports the negated ledger sum, so moving its balance up
        // by one rupiah means moving the ledger down by one rupiah.
        final change = balance - row.balance;
        final ledgerDelta = liability ? -change : change;
        if (ledgerDelta != 0) {
          await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: IdGen.next('tx'),
              accountId: id,
              amount: ledgerDelta.abs(),
              type: ledgerDelta > 0
                  ? TransactionTypeName.income
                  : TransactionTypeName.expense,
              title: 'Penyesuaian saldo $trimmed',
              category: const Value('Penyesuaian'),
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
      await _db.refreshAccountBalances();
    });
  }

  Future<void> setArchived(String id, bool archived) async {
    final changed = await (_db.update(_db.accounts)..where((r) => r.id.equals(id)))
        .write(
          AccountsCompanion(
            isArchived: Value(archived),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed == 0) throw NotFoundException('Akun $id tidak ditemukan');
  }

  /// Deletes an account. The foreign key on transactions is RESTRICT, so an
  /// account that still has history cannot be removed by accident; the caller
  /// gets a [ConflictException] with something it can act on.
  Future<void> delete(String id) async {
    final used = await _transactionCount(id);
    if (used > 0) {
      throw ConflictException(
        'Akun masih punya $used transaksi. Pindahkan atau hapus '
        'transaksinya dulu.',
      );
    }
    final deleted = await (_db.delete(_db.accounts)..where((r) => r.id.equals(id)))
        .go();
    if (deleted == 0) throw NotFoundException('Akun $id tidak ditemukan');
  }

  Future<int> _transactionCount(String id) async {
    final count = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([count])
      ..where(
        _db.transactions.accountId.equals(id) |
            _db.transactions.targetAccountId.equals(id),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}

/// String constants for the transaction type column, so the data layer does
/// not need to import the presentation-facing enum for a write.
abstract final class TransactionTypeName {
  static const income = 'income';
  static const expense = 'expense';
  static const transfer = 'transfer';
}

String? _nullIfEmpty(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
