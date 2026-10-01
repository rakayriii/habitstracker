import 'package:drift/drift.dart';

import '../../core/utils/id.dart';
import '../../domain/errors.dart';
import '../../domain/models/transaction.dart';
import '../database/app_database.dart';

/// The transaction ledger.
///
/// Every write goes through [AppDatabase.refreshAccountBalances] inside the
/// same database transaction as the change, so an insert, an edit and a delete
/// all leave the account balances consistent with the rows behind them.
class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;

  static Transaction _map(TransactionRow row) {
    return Transaction(
      id: row.id,
      amount: row.amount,
      type: TransactionType.values.firstWhere(
        (type) => type.name == row.type,
        orElse: () => TransactionType.expense,
      ),
      category: row.category,
      title: row.title,
      accountId: row.accountId,
      accountName: '',
      targetAccountId: row.targetAccountId,
      targetAccountName: '',
      date: row.date,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Joined against accounts so a row carries the account names a ledger line
  /// needs. The two references to accounts are aliased, otherwise the join
  /// would read the same table twice under one name.
  Stream<List<Transaction>> watchAll() {
    final source = _db.accounts.createAlias('source_account');
    final target = _db.accounts.createAlias('target_account');
    final query = _db.select(_db.transactions).join([
      innerJoin(source, source.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(target, target.id.equalsExp(_db.transactions.targetAccountId)),
    ])
      ..orderBy([
        OrderingTerm.desc(_db.transactions.date),
        OrderingTerm.desc(_db.transactions.createdAt),
      ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          _map(
            row.readTable(_db.transactions),
          ).copyWith(
            accountName: row.readTable(source).name,
            targetAccountName: row.readTableOrNull(target)?.name,
          ),
      ],
    );
  }

  /// Watches one transaction, including its account names, so an edit form
  /// stays live while the row is open.
  Stream<Transaction?> watchById(String id) {
    final source = _db.accounts.createAlias('source_account');
    final target = _db.accounts.createAlias('target_account');
    final query = _db.select(_db.transactions).join([
      innerJoin(source, source.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(target, target.id.equalsExp(_db.transactions.targetAccountId)),
    ])..where(_db.transactions.id.equals(id));
    return query.watchSingleOrNull().map(
      (row) => row == null
          ? null
          : _map(row.readTable(_db.transactions)).copyWith(
              accountName: row.readTable(source).name,
              targetAccountName: row.readTableOrNull(target)?.name,
            ),
    );
  }

  Future<Transaction?> findById(String id) async {
    final row = await (_db.select(_db.transactions)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    final account = await _accountName(row.accountId);
    final target = row.targetAccountId == null
        ? null
        : await _accountName(row.targetAccountId!);
    return _map(row).copyWith(accountName: account, targetAccountName: target);
  }

  Future<String?> _accountName(String id) async {
    final row = await (_db.select(_db.accounts)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
    return row?.name;
  }

  Future<Transaction> create({
    required int amount,
    required TransactionType type,
    required String accountId,
    required String title,
    required DateTime date,
    String category = '',
    String? targetAccountId,
    String? notes,
  }) async {
    final id = await _write(
      amount: amount,
      type: type,
      accountId: accountId,
      targetAccountId: targetAccountId,
      title: title,
      category: category,
      date: date,
      notes: notes,
    );
    final created = await findById(id);
    if (created == null) {
      throw const StorageException('Transaksi gagal disimpan');
    }
    return created;
  }

  Future<Transaction> update(
    String id, {
    required int amount,
    required TransactionType type,
    required String accountId,
    required String title,
    required DateTime date,
    String category = '',
    String? targetAccountId,
    String? notes,
  }) async {
    await _write(
      id: id,
      amount: amount,
      type: type,
      accountId: accountId,
      targetAccountId: targetAccountId,
      title: title,
      category: category,
      date: date,
      notes: notes,
    );
    final updated = await findById(id);
    if (updated == null) {
      throw NotFoundException('Transaksi $id tidak ditemukan');
    }
    return updated;
  }

  Future<void> delete(String id) async {
    await _db.transaction(() async {
      final deleted = await (_db.delete(_db.transactions)
            ..where((row) => row.id.equals(id)))
          .go();
      if (deleted == 0) throw NotFoundException('Transaksi $id tidak ditemukan');
      await _db.refreshAccountBalances();
    });
  }

  Future<String> _write({
    String? id,
    required int amount,
    required TransactionType type,
    required String accountId,
    required String title,
    required DateTime date,
    String category = '',
    String? targetAccountId,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw const ValidationException(
        'Nominal harus lebih besar dari nol',
        field: 'amount',
      );
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const ValidationException(
        'Judul transaksi wajib diisi',
        field: 'title',
      );
    }
    if (accountId.isEmpty) {
      throw const ValidationException(
        'Pilih akun terlebih dahulu',
        field: 'accountId',
      );
    }
    if (type == TransactionType.transfer) {
      if (targetAccountId == null || targetAccountId.isEmpty) {
        throw const ValidationException(
          'Pilih akun tujuan transfer',
          field: 'targetAccountId',
        );
      }
      if (targetAccountId == accountId) {
        throw const ValidationException(
          'Akun tujuan harus berbeda dari akun sumber',
          field: 'targetAccountId',
        );
      }
    }
    final accounts = await (_db.select(_db.accounts)
          ..where((a) => a.id.isIn([accountId, ?targetAccountId])))
        .get();
    if (accounts.length < (type == TransactionType.transfer ? 2 : 1)) {
      throw const ValidationException('Akun tidak ditemukan');
    }

    final rowId = id ?? IdGen.next('tx');
    final now = DateTime.now();
    await _db.transaction(() async {
      if (id == null) {
        await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            id: rowId,
            accountId: accountId,
            amount: amount,
            type: type.name,
            title: trimmedTitle,
            category: Value(category.trim()),
            targetAccountId: Value(
              type == TransactionType.transfer ? targetAccountId : null,
            ),
            date: date,
            notes: Value(_nullIfEmpty(notes)),
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        final changed = await (_db.update(_db.transactions)
              ..where((row) => row.id.equals(id)))
            .write(
          TransactionsCompanion(
            accountId: Value(accountId),
            amount: Value(amount),
            type: Value(type.name),
            title: Value(trimmedTitle),
            category: Value(category.trim()),
            targetAccountId: Value(
              type == TransactionType.transfer ? targetAccountId : null,
            ),
            date: Value(date),
            notes: Value(_nullIfEmpty(notes)),
            updatedAt: Value(now),
          ),
        );
        if (changed == 0) {
          throw NotFoundException('Transaksi $id tidak ditemukan');
        }
      }
      await _db.refreshAccountBalances();
    });
    return rowId;
  }
}

String? _nullIfEmpty(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
