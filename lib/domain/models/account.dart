import 'package:flutter/foundation.dart';

/// Where money is held. The type drives nothing but the label and the default
/// allocation colour; the asset/liability split is the explicit
/// [Account.isLiability] flag so the user stays in control.
enum AccountType {
  cash('Cash', 'Tunai dan uang tunai equivalents'),
  bank('Bank', 'Rekening tabungan dan giro'),
  ewallet('E-wallet', 'Dompet digital'),
  bitcoin('Bitcoin', 'Aset kripto'),
  gold('Gold', 'Emas fisik'),
  stocks('Stocks', 'Saham dan reksa dana'),
  creditCard('Credit card', 'Kartu kredit, saldo adalah utang'),
  other('Other', 'Lainnya');

  const AccountType(this.label, this.hint);

  final String label;
  final String hint;
}

/// Signed effect of a transaction on an account, in rupiah.
extension AccountTypeX on AccountType {}

@immutable
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.currency,
    required this.isLiability,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  final String id;
  final String name;
  final AccountType type;

  /// Cached running balance. Always recomputed from the transaction ledger, so
  /// it can never drift away from the transactions that produced it.
  final int balance;
  final String currency;
  final String? notes;

  /// When true the balance is money owed rather than money held, and it is
  /// subtracted from net worth instead of added.
  final bool isLiability;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAsset => !isLiability;

  Account copyWith({
    String? name,
    AccountType? type,
    int? balance,
    String? notes,
    bool? isLiability,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency,
      notes: notes ?? this.notes,
      isLiability: isLiability ?? this.isLiability,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
